class_name PopSim
extends RefCounted
## Plan A2.2 — pure integer step function for the pop sim core.
##
## The skeleton's flat stepping is gone: motion now comes from re-authored
## sequence tables in `pop_tables.gd` executed by a mini play_seq interpreter.
## Reference behaviour mirrored (original code, cited): tick order is input →
## sequence ops → fall physics → floor/landing resolution → spike contact
## (`seg000.c:1179-1213` play_kid_frame); one tick consumes ops up to and
## including the next FRAME op (`seg006.c:569-684`); fall speed starts at the
## SET_FALL value, accelerates +3/frame to 33 only in free fall, and moves y
## every tick (`seg006.c:870-894`); landing resolves against y_land[row+1]
## with the soft/medium/death windows (`seg005.c:114-217`).
##
## No engine API, no floats, no wall clock: step(state, input) is a function
## of its arguments alone — plan §8 gate 1 checks that with a double-run hash.
## The level lives in state["tiles"]/state["mods"] (static data; not hashed).
##
## Known simplifications vs the reference (reported, not tuned away): no
## wall bump/collision (A2.3), no hang/grab (A2.3), no chompers/plates/gates
## (A4.x), feather-fall branch omitted (A4.5), crouch does not stand up on
## input (reference control does; not in A2.2 scope), pressing back while
## running plays our standing `turn` instead of the reference `runturn`
## (`seqtbl.c:454`), and check_spike_below / check_knock side effects are not
## modeled.

const STATE_KEYS: Array[String] = [
	"tick", "x", "y", "row", "dir", "seq", "op", "frame",
	"action", "hp", "dead", "fall_y", "fall_x", "rng",
]

## Measured: 8 ticks (flip + frames 45–52 → stand), docs/PARITY.md §18,
## `seqtbl.c:440-449`.
const TURN_TICKS: int = PopTables.TURN_TICKS
## Measured floor y for row 0 = `y_land[row+1]`, docs/PARITY.md §2 (`data.h:506`).
const STAND_Y: int = 55
## Start x: mid-tile so the foot (x − weight 3 for frame 15) sits inside
## column 0 (left edge 58, PARITY §2). The reference level-load start is
## `x_bump[col+5] + 14` (`seg003.c:158`); tests place the kid explicitly.
const _START_X: int = 65

const _FNV_OFFSET: int = 0x811C9DC5  ## FNV-1a 32-bit offset basis
const _FNV_PRIME: int = 0x01000193   ## FNV-1a 32-bit prime
const _FNV_MASK: int = 0xFFFFFFFF


static func initial_state(seed: int, tiles: Array = [], mods: Dictionary = {}) -> Dictionary:
	return {
		"tick": 0,
		"x": _START_X,
		"y": STAND_Y,
		"row": 0,
		"dir": 1,
		"seq": "stand",
		"op": 0,
		"frame": 15,
		"action": PopTables.Action.STAND,
		"hp": PopTables.KID_HP_START,
		"dead": 0,
		"fall_y": 0,
		"fall_x": 0,
		"rng": PopRng.normalize_seed(seed),
		# Level data (static): tiles[row][col] = PopTables.Tile id, rows 0..3,
		# cols 0..9; out of range reads as EMPTY. mods is copied so one run's
		# spike disabling can never leak into another run's state.
		"tiles": tiles,
		"mods": mods.duplicate(),
	}


## Advance exactly one tick. Pure: returns a new dictionary (level mods are
## deep-copied at initial_state, mutated only through the returned chain),
## never reads globals or clocks. input.y == -1 is jump (up), per pop_input.
static func step(state: Dictionary, input: PopInput) -> Dictionary:
	var s: Dictionary = state.duplicate()
	s["tick"] = int(s["tick"]) + 1
	# The generator advances every tick so the gate can observe seed
	# sensitivity; consumption becomes demand-driven with guard AI (A4.x).
	s["rng"] = PopRng.step_state(int(s["rng"]))

	_control(s, input)   # reference: play_kid / control_kid (seg000.c:1183)
	_advance(s)          # reference: play_seq (seg006.c:569-684)
	_fall_physics(s)     # reference: fall_accel + fall_speed (seg006.c:870-894)
	if int(s["dead"]) == 0:
		_floor_checks(s)  # reference: check_action → do_fall/check_on_floor/start_fall/land
		_spike_check(s)   # reference: check_spiked (seg006.c:950-964)
	return s


## Run a whole input script (array of packed bytes) from an initial seed.
static func run(seed: int, script: Array, tiles: Array = [], mods: Dictionary = {}) -> Dictionary:
	var state: Dictionary = initial_state(seed, tiles, mods)
	for packed: Variant in script:
		state = step(state, PopInput.from_byte(int(packed)))
	return state


# --- Input → sequence selection (our control model) ------------------------
# Sequences the reference makes input-active are stand and the run cycle;
# jumps, turns, stops, falls and lands play out locked (reference control_kid
# keys off frames the same way; our mapping is original code, plan §4.6).
static func _control(s: Dictionary, input: PopInput) -> void:
	if int(s["dead"]) != 0:
		return
	var dir: int = int(s["dir"])
	match String(s["seq"]):
		"stand":
			if input.y == -1:
				_start_seq(s, "stand_jump")
			elif input.x == dir:
				_start_seq(s, "startrun")
			elif input.x == -dir and input.x != 0:
				_start_seq(s, "turn")
		"startrun", "run_cycle":
			if input.y == -1:
				_start_seq(s, "run_jump")
			elif input.x == 0:
				_start_seq(s, "run_stop")
			elif input.x == -dir:
				_start_seq(s, "turn")
		_:
			pass  # locked sequence (jump/turn/stop/fall/land/crouch)


static func _start_seq(s: Dictionary, seq_name: String) -> void:
	s["seq"] = seq_name
	s["op"] = 0


# --- Sequence interpreter (reference play_seq semantics) -------------------
# Executes ops until a FRAME op ends the tick; JUMP switches sequence without
# consuming a tick (`seg006.c:569-684`). DX moves in the facing direction,
# DY adds to y, FLIP negates direction.
static func _advance(s: Dictionary) -> void:
	var guard := 0
	while guard < 64:
		guard += 1
		var ops: Array = PopTables.SEQUENCES.get(String(s["seq"]), [])
		if int(s["op"]) >= ops.size():
			return  # exhausted without FRAME/JUMP (defensive; our data doesn't)
		var op: Array = ops[int(s["op"])]
		s["op"] = int(s["op"]) + 1
		match int(op[0]):
			PopTables.Op.ACTION:
				s["action"] = int(op[1])
			PopTables.Op.FRAME:
				s["frame"] = int(op[1])
				return
			PopTables.Op.DX:
				s["x"] = int(s["x"]) + int(op[1]) * int(s["dir"])
			PopTables.Op.DY:
				s["y"] = int(s["y"]) + int(op[1])
			PopTables.Op.SET_FALL:
				s["fall_x"] = int(op[1])
				s["fall_y"] = int(op[2])
			PopTables.Op.JUMP:
				s["seq"] = String(op[1])
				s["op"] = 0
			PopTables.Op.FLIP:
				s["dir"] = -int(s["dir"])
			PopTables.Op.SOUND:
				pass  # presentation (A3); ids live in PopTables.Sound
			PopTables.Op.KNOCK_DOWN:
				pass  # tile-knock side effect (`seg003.c:478`) — no tiles modeled yet
			PopTables.Op.DIE:
				pass  # marker; death is applied by land()/spiked() (reference SEQ_DIE is a nop, `seg006.c:675`)
			_:
				pass  # ROW_UP/ROW_DOWN: climb only (A2.3)


# --- Falling physics (reference fall_accel + fall_speed) -------------------
static func _fall_physics(s: Dictionary) -> void:
	# Acceleration applies only in free fall (`seg006.c:870-880`).
	if int(s["action"]) == PopTables.Action.IN_FREEFALL:
		var fy: int = int(s["fall_y"]) + PopTables.FALL_ACCEL
		s["fall_y"] = mini(fy, PopTables.FALL_SPEED_MAX)
	# y moves every tick at the current speed; in free fall x drifts by
	# fall_x in the facing direction (`seg006.c:883-894`).
	s["y"] = int(s["y"]) + int(s["fall_y"])
	if int(s["action"]) == PopTables.Action.IN_FREEFALL:
		s["x"] = int(s["x"]) + int(s["fall_x"]) * int(s["dir"])


# --- Floor, landing and edge resolution ------------------------------------
static func _floor_checks(s: Dictionary) -> void:
	var action: int = int(s["action"])
	if action == PopTables.Action.IN_FREEFALL:
		_do_fall(s)                      # reference check_action → do_fall (`seg006.c:920-921`)
	elif action == PopTables.Action.IN_MIDAIR:
		pass                             # grab check is A2.3 (`seg006.c:922-926`)
	elif action == PopTables.Action.HANG_CLIMB:
		pass                             # A2.3
	elif action == PopTables.Action.BUMPED or action == PopTables.Action.HANG_STRAIGHT:
		if int(s["frame"]) == 109:
			_check_on_floor(s)           # reference checks the crouch frame only (`seg006.c:907-919`)
	else:
		_check_on_floor(s)               # STAND / RUN_JUMP / TURN (`seg006.c:927-928`)


## Falling: above this row's floor level → keep falling (grab = A2.3);
## at floor level → land if the tile is floor, else descend one row
## (`seg005.c:42-109`).
static func _do_fall(s: Dictionary) -> void:
	if int(s["row"]) > 3:
		_fell_out(s)
		return
	if _floor_y(int(s["row"])) > int(s["y"]):
		return  # still airborne; reference check_grab lives here (`seg005.c:42-44`)
	var col := _col_of(_foot_x(s))
	if _is_floor(_tile(s, int(s["row"]), col)):
		_land(s)
	else:
		s["row"] = int(s["row"]) + 1


## Walking frame needs floor and the foot tile is not floor → fall
## (`seg006.c:1028-1077`); the entry sequence is chosen by the current frame
## and its first tick plays immediately (`seg006.c:1081-1133`).
static func _check_on_floor(s: Dictionary) -> void:
	var frame: int = int(s["frame"])
	var row: Dictionary = PopTables.KID_FRAME.get(frame, {})
	if int(row.get("needs_floor", 0)) == 0:
		return
	var col := _col_of(_foot_x(s))
	if _is_floor(_tile(s, int(s["row"]), col)):
		return
	_start_fall(s, _fall_entry_for(frame))


static func _fall_entry_for(frame: int) -> String:
	if frame == 13:
		return "step_fall_2"   # reference seq_19 (`seg006.c:1091-1093`)
	if frame == 26:
		return "jump_fall"     # reference seq_18 (`seg006.c:1094-1096`)
	if frame == 44:
		return "run_jump_fall" # reference seq_21 (`seg006.c:1097-1099`)
	return "step_fall"         # reference seq_7 default (`seg006.c:1129`)


static func _start_fall(s: Dictionary, seq_name: String) -> void:
	s["row"] = int(s["row"]) + 1
	if int(s["row"]) > 3:
		_fell_out(s)
		return
	_start_seq(s, seq_name)
	_advance(s)  # first fall frame plays this same tick (reference: play_seq() inside start_fall)


## Impact resolution (`seg005.c:114-217`): snap y to the row floor, nudge
## back from a floorless edge, spike check, then the soft/medium/death
## windows on impact speed.
static func _land(s: Dictionary) -> void:
	var row: int = int(s["row"])
	s["y"] = _floor_y(row)
	var col := _col_of(_foot_x(s))
	var tile := _tile(s, row, col)

	if tile == PopTables.Tile.SPIKES:
		if _spike_harm_class(_mod(s, row, col)) != 0:
			_spiked(s, col)
			return
	else:
		# No floor ahead and under 3 units from the edge → back up 3
		# (`seg005.c:128-132`): the floor-edge snap A2.2 asks for.
		var ahead := _tile(s, row, col + int(s["dir"]))
		if not _is_floor(ahead) and _dist_to_edge(s, _foot_x(s)) < 3:
			s["x"] = int(s["x"]) + int(s["dir"]) * -3

	if int(s["dead"]) == 0:
		var impact: int = int(s["fall_y"])
		if impact < PopTables.SOFT_LAND_MAX:
			_start_seq(s, "soft_land")            # `seg005.c:174-186`
			_advance(s)
		elif impact < PopTables.MEDIUM_LAND_MAX:
			s["hp"] = int(s["hp"]) - 1            # `seg005.c:187-196`
			if int(s["hp"]) <= 0:
				s["hp"] = 0
				s["dead"] = 1
				_start_seq(s, "hard_land")        # last HP → crushed (`seg005.c:197-212`)
				_advance(s)
			else:
				_start_seq(s, "med_land")
				_advance(s)
		else:
			s["hp"] = 0
			s["dead"] = 1
			_start_seq(s, "hard_land")
			_advance(s)
	s["fall_y"] = 0                               # `seg005.c:216`
	s["fall_x"] = 0


## Standing on/next to spikes by frame rule (`seg006.c:950-964`): running
## frames and run-jump start frames need class ≥ 2; the two landing frames
## (26, 43) trip on any nonzero class.
static func _spike_check(s: Dictionary) -> void:
	if int(s["dead"]) != 0:
		return
	var col := _col_of(_foot_x(s))
	if _tile(s, int(s["row"]), col) != PopTables.Tile.SPIKES:
		return
	var harmful := _spike_harm_class(_mod(s, int(s["row"]), col))
	var frame: int = int(s["frame"])
	if harmful >= 2 and ((frame >= 7 and frame < 15) or (frame >= 34 and frame < 40)):
		_spiked(s, col)
	elif (frame == 43 or frame == 26) and harmful != 0:
		_spiked(s, col)


## Impale (`seg005.c:220-249`): disable the spikes, snap x to
## x_bump[col+5]+10 (then 8 units forward), zero fall speed, kill, and play
## the first impale frame this tick.
static func _spiked(s: Dictionary, col: int) -> void:
	var mods: Dictionary = s["mods"]
	mods["%d,%d" % [int(s["row"]), col]] = 0xFF
	s["y"] = _floor_y(int(s["row"]))
	s["x"] = PopTables.X_BUMP[col + PopTables.FIRST_ONSCREEN_COLUMN] + 10
	s["x"] = int(s["x"]) + int(s["dir"]) * 8
	s["fall_y"] = 0
	s["fall_x"] = 0
	s["hp"] = 0
	s["dead"] = 1
	_start_seq(s, "impale")
	_advance(s)


## Left the bottom of the screen while falling (`seg006.c:1321-1326`):
## reference kills the kid and pins frame 185.
static func _fell_out(s: Dictionary) -> void:
	s["hp"] = 0
	s["dead"] = 1
	s["frame"] = 185
	s["seq"] = "hard_land"
	s["op"] = 0


# --- Reference-derived helpers ---------------------------------------------
# Standing floor y: y_land[row + 1] (`seg005.c:124`, PARITY §2).
static func _floor_y(row: int) -> int:
	if row + 1 >= PopTables.Y_LAND.size():
		return 0x7FFFFFFF  # no floor below the modeled rows (fell_out handles it)
	return int(PopTables.Y_LAND[row + 1])


static func _tile(s: Dictionary, row: int, col: int) -> int:
	var tiles: Array = s["tiles"]
	if row < 0 or row >= tiles.size():
		return PopTables.Tile.EMPTY
	var r: Array = tiles[row]
	if col < 0 or col >= r.size():
		return PopTables.Tile.EMPTY
	return int(r[col])


static func _mod(s: Dictionary, row: int, col: int) -> int:
	return int((s["mods"] as Dictionary).get("%d,%d" % [row, col], 0))


## Foot x = x + dir * (frame dx − weight) — reference dx_weight()
## (`seg006.c:547-550`); frame offsets come from the kid frame table.
static func _foot_x(s: Dictionary) -> int:
	var row: Dictionary = PopTables.KID_FRAME.get(int(s["frame"]), {})
	var offset: int = int(row.get("dx", 0)) - int(row.get("weight", 0))
	return int(s["x"]) + int(s["dir"]) * offset


## Column from x: x_bump says column c spans [58+14c, 72+14c) (PARITY §2),
## so col = floor((x − 58) / 14) — GDScript int division truncates, so fix
## up negatives (reference get_tile_div_mod, `seg006.c:743-746`).
static func _col_of(x: int) -> int:
	var a: int = x - 58
	var c: int = a / 14
	if a < 0 and a % 14 != 0:
		c -= 1
	return c


## Distance from foot to the edge being walked toward: facing right →
## distance to the right edge (13 − xl), else to the left edge (xl)
## (`seg006.c:1310-1317`).
static func _dist_to_edge(s: Dictionary, foot_x: int) -> int:
	var left: int = 58 + 14 * _col_of(foot_x)
	var xl: int = foot_x - left
	return (13 - xl) if int(s["dir"]) == 1 else xl


## Which tiles count as standable floor (`seg006.c:933-947`, PARITY §2).
static func _is_floor(tile: int) -> bool:
	return not (tile in PopTables.NON_FLOOR_TILES)


## Spike harm class (`seg007.c:1171-1176`, sbyte semantics, PARITY §8):
## 0 retracted/disabled, 1 held extended (0x80–0xFE), 2 extending 1–4.
static func _spike_harm_class(modifier: int) -> int:
	var sm: int = modifier & 0xFF
	if sm >= 128:
		sm -= 256
	if modifier == 0 or sm == -1:
		return 0
	if sm < 0:
		return 1
	if sm <= PopTables.SPIKE_EXTEND_MAX:
		return 2
	return 0


# --- Determinism hash -------------------------------------------------------
# FNV-1a (32-bit) over STATE_KEYS order; ints hashed little-endian byte-wise,
# the sequence name hashed as UTF-8. Integer-only and order-stable, so two
# runs of the same seed and script are comparable byte-for-byte.
static func hash_state(state: Dictionary) -> int:
	var h: int = _FNV_OFFSET
	for key: String in STATE_KEYS:
		var v: Variant = state[key]
		if v is String:
			for b: int in (v as String).to_utf8_buffer():
				h = _fold_byte(h, b)
		else:
			var iv: int = int(v)
			for i: int in 8:
				h = _fold_byte(h, (iv >> (i * 8)) & 0xFF)
	return h


static func _fold_byte(h: int, b: int) -> int:
	return ((h ^ b) * _FNV_PRIME) & _FNV_MASK
