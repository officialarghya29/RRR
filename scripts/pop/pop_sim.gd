class_name PopSim
extends RefCounted
## Plan A2.2/A2.3 — pure integer step function for the pop sim core.
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
## A2.3 added the Shift branch of control_standing (grab/safe-step/down),
## jump-up-from-stand, down-pressed crouch/climb-down, the hang family
## (grab-hang, hang sway, hang-straight, climb up/down/failed) with the
## reference's tile-column pin (`seg006.c:1187-1190`), and mid-air grab.
##
## No engine API, no floats, no wall clock: step(state, input) is a function
## of its arguments alone — plan §8 gate 1 checks that with a double-run hash.
## The level lives in state["tiles"]/state["mods"] (static data; not hashed).
## `input_shift` is a same-tick helper (set in step(), erased at return),
## never hashed.
##
## Known simplifications vs the reference (reported, not tuned away): no
## wall bump/collision when walking or jumping forward; no chompers/plates/
## gates (A4.x); feather-fall branch omitted (A4.5); crouch-hop and crouch
## picks (Shift+item) not modeled (A4.x); plain-Up jump-up hits no ceiling
## and carries no hang-degrade timer; pressing back while running plays our
## standing `turn` instead of the reference `runturn` (`seqtbl.c:454`);
## the m7 (−7) column probe of `determine_col` (`seg006.c:014D`) is applied
## to the hang/climb frames only — the calibrated A2.2 probes keep the plain
## left-edge column (`get_tile_div_mod`, `seg006.c:743-746`) until the m7
## migration is measured (plan gate 2); safe-step-on-edge-at-distance-0
## (`seg005.c:595-605` seq_44 path) is A2.3-optional and absent; check_knock,
## check_spike_below side effects are not modeled.
const STATE_KEYS: Array[String] = ["tick", "x", "y", "row", "dir", "seq", "op", "frame", "action", "hp", "dead", "fall_y", "fall_x", "rng", "grab_timer", "grab_col", "gates", "plates", "exit", "mods", "anims", "blocks"]

## Measured: 8 ticks (flip + frames 45–52 → stand), docs/PARITY.md §18,
## `seqtbl.c:440-449`.
const TURN_TICKS: int = PopTables.TURN_TICKS
## Measured floor y for row 0 = `y_land[row+1]`, docs/PARITY.md §2 (`data.h:506`).
const STAND_Y: int = 55
## Start x: mid-tile so the foot (x − weight 3 for frame 15) sits inside
## column 0 (left edge 58, PARITY §2). The reference level-load start is
## `x_bump[col+5] + 14` (`seg003.c:158`); tests place the kid explicitly.
const _START_X: int = 65

## `edge_type` id for EDGE (`types.h:1399-1403`: CLOSER 0, EDGE 1, FLOOR 2) —
## the get_edge_distance class that selects grab_up_with_floor_behind's
## straight branch (`seg005.c:868-869`).
const _EDGE_TYPE_EDGE: int = 1

const _FNV_OFFSET: int = 0x811C9DC5  ## FNV-1a 32-bit offset basis
const _FNV_PRIME: int = 0x01000193   ## FNV-1a 32-bit prime
const _FNV_MASK: int = 0xFFFFFFFF


static func initial_state(seed: int, tiles: Array = [], mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
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
		"grab_timer": 0,
		"grab_col": 0,
		"rng": PopRng.normalize_seed(seed),
		# Level data (static at load, mutable during a run): tiles[row][col] =
		# PopTables.Tile id, rows 0..3, cols 0..9; out of range reads as EMPTY.
		# tiles is duplicated per run because trap detach mutates it, and mods is
		# copied so one run's spike disabling can never leak into another run's
		# state.
		"tiles": _dup_tiles(tiles),
		"mods": mods.duplicate(),
		# A4.1 level entities (hashed): gate modifiers/animation, plate hold
		# timers and the level-exit door. links is static level data (not
		# hashed), like tiles.
		"gates": _dup_entities(entities.get("gates", {})),
		"plates": _dup_entities(entities.get("plates", {})),
		"exit": (entities.get("exit", {}) as Dictionary).duplicate(),
		"links": (entities.get("links", []) as Array).duplicate(),
		# A4.2: which tiles currently run a trap animation, and the loose-floor
		# blocks currently falling (both hashed).
		"anims": {},
		"blocks": [],
	}


## Per-run copy of the tile grid: a detaching loose floor empties its cell,
## and two runs sharing one array would corrupt each other.
static func _dup_tiles(src: Array) -> Array:
	var out: Array = []
	for r: Variant in src:
		out.append((r as Array).duplicate())
	return out


## Full independent copy of a live state (plan B0 step 4): what the echo
## recorder snapshots when a take starts, so the replay participant steps
## from the exact mid-level pose the recording began at — not from the level
## spawn. Mirrors initial_state's copy discipline (step() mutates nested
## dicts in place), so the echo and the world can never share one object.
static func dup_state(s: Dictionary) -> Dictionary:
	var out: Dictionary = s.duplicate()
	out["tiles"] = _dup_tiles(s.get("tiles", []))
	out["mods"] = (s.get("mods", {}) as Dictionary).duplicate()
	out["gates"] = _dup_entities(s.get("gates", {}))
	out["plates"] = _dup_entities(s.get("plates", {}))
	out["exit"] = (s.get("exit", {}) as Dictionary).duplicate()
	out["links"] = (s.get("links", []) as Array).duplicate()
	out["anims"] = (s.get("anims", {}) as Dictionary).duplicate()
	var blocks: Array = []
	for b: Variant in (s.get("blocks", []) as Array):
		blocks.append((b as Dictionary).duplicate() if b is Dictionary else b)
	out["blocks"] = blocks
	out.erase("input_shift")
	return out


## One-level deep copy of an entity dictionary (gates hold a nested dict; a
## plate is a bare int timer), so two states never share entity objects.
static func _dup_entities(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src.keys():
		var v: Variant = src[k]
		out[k] = (v as Dictionary).duplicate() if v is Dictionary else v
	return out


## Advance exactly one tick. Pure: returns a new dictionary (level mods are
## deep-copied at initial_state, mutated only through the returned chain),
## never reads globals or clocks. input.y == -1 is jump (up), per pop_input.
static func step(state: Dictionary, input: PopInput) -> Dictionary:
	var s: Dictionary = state.duplicate()
	s["tick"] = int(s["tick"]) + 1
	# The generator advances every tick so the gate can observe seed
	# sensitivity; consumption becomes demand-driven with guard AI (A4.x).
	s["rng"] = PopRng.step_state(int(s["rng"]))
	# The tick's input is visible to helpers that need it (grab rule);
	# not part of the hashed state (input is an argument, not state).
	s["input_shift"] = int(input.shift)

	_control(s, input)   # reference: play_kid / control_kid (seg000.c:1183)
	_advance(s)          # reference: play_seq (seg006.c:569-684)
	_fall_physics(s)     # reference: fall_accel + fall_speed (seg006.c:870-894)
	if int(s["dead"]) == 0:
		_floor_checks(s)  # reference: check_action → do_fall/check_on_floor/start_fall/land
		_clamp_walls(s)   # reduced in_wall/check_bumped: walls + closed gates stop the kid
		_spike_check(s)   # reference: check_spiked (seg006.c:950-964)
		# reference: check_press (seg006.c:1676-1698) + process_trobs (seg007.c:21-40)
		PopLevel.step_entities(s, int(s["row"]), _col_of(_foot_x(s)),
			_tile(s, int(s["row"]), _col_of(_foot_x(s))))
		PopLevel.step_traps(s, int(s["row"]), _col_of(_foot_x(s)), int(s["dead"]))
	s.erase("input_shift")  # helpers consumed it; never leaks into the returned state
	return s


## Reduced wall rule (plan B0.1, cited): walls and *closed* gates stop the kid
## at the tile edge. The reference does this through in_wall()/check_bumped(),
## which test the char's *body* tile (curr_col), not the foot probe; we model
## only the stop — no turn-around, no wall-ejection, no bump animation — and
## report it as a simplification. An open gate (modifier ≥ 188, PARITY §9
## `seg007.c:378-386`) is passable; a gate stays floor from above
## (`_is_floor`), which is how the kid stands on one.
static func _clamp_walls(s: Dictionary) -> void:
	var action := int(s["action"])
	if action == PopTables.Action.IN_MIDAIR or action == PopTables.Action.IN_FREEFALL \
			or action == PopTables.Action.HANG_CLIMB:
		return
	var col := _col_of(int(s["x"]))
	var tile := _tile(s, int(s["row"]), col)
	var blocks := tile == PopTables.Tile.WALL
	if tile == PopTables.Tile.GATE:
		var g: Variant = (s.get("gates", {}) as Dictionary).get("%d,%d" % [int(s["row"]), col])
		blocks = (g is Dictionary) and int((g as Dictionary).get("mod", PopTables.GATE_CLOSED)) \
			< PopTables.GATE_OPEN_THRESHOLD
	if not blocks:
		return
	var left := 58 + PopTables.TILE_W * col
	if int(s["dir"]) == 1:
		s["x"] = left - 2                     # foot stays in the previous column
	else:
		s["x"] = left + PopTables.TILE_W + 2


## Run a whole input script (array of packed bytes) from an initial seed.
static func run(seed: int, script: Array, tiles: Array = [], mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	var state: Dictionary = initial_state(seed, tiles, mods, entities)
	for packed: Variant in script:
		state = step(state, PopInput.from_byte(int(packed)))
	return state


# --- Input → sequence selection (our control model, re-derived from the
# reference control functions as cited per branch; plan §4.6). The A2.2
# up-from-stand standing jump is deliberately gone: the reference binds
# standing jump to up+forward (seg005.c:385-395, seg005.c:453-458; PARITY
# §4 "Standing-jump trigger") and routes plain Up to the jump-up/hang family.
static func _control(s: Dictionary, input: PopInput) -> void:
	if int(s["dead"]) != 0:
		return
	# grab_timer counts down on every live tick (seg006.c:1387-1388).
	if int(s["grab_timer"]) > 0:
		s["grab_timer"] = int(s["grab_timer"]) - 1
	var dir: int = int(s["dir"])
	match String(s["seq"]):
		"stand":
			# control_standing (seg005.c:338-433): Shift branch first, then
			# the plain-movement chain. Keyboard standing jump = up+forward
			# (seg005.c:385-395); plain up = jump-up family (up_pressed,
			# seg005.c:482-524); down = crouch/climb-down (down_pressed,
			# seg005.c:461-495); shift+forward = safe step (`seg005.c:592-605`).
			if input.shift == 1:
				if input.x == -dir and input.x != 0:
					_start_seq(s, "turn")             # shift+back: turn (seg005.c:376-380)
				elif input.y == -1:
					_jump_up_from_stand(s)            # shift+up: up_pressed (seg005.c:379-382)
				elif input.y == 1:
					_down_pressed(s)                  # shift+down: down_pressed (seg005.c:383-385)
				elif input.x == dir and input.x != 0:
					_safe_step(s)                     # shift+forward: safe step (`seg005.c:592-605`)
				# shift alone: get-item pickup — A4.x, unmodeled
			else:
				if input.x == dir and input.x != 0:
					if input.y == -1:
						_start_seq(s, "stand_jump")   # fwd+up: standing jump (seg005.c:385-395)
					else:
						_start_seq(s, "startrun")     # forward: start run (seg005.c:421-424)
				elif input.x == -dir and input.x != 0:
					_start_seq(s, "turn")             # backward: turn (seg005.c:425-427)
				elif input.y == -1:
					_jump_up_from_stand(s)            # plain up: jump-up family (seg005.c:428-431)
				elif input.y == 1:
					_down_pressed(s)                  # plain down: crouch (seg005.c:432-433)
		"startrun", "run_cycle":
			# control_running (`seg005.c:569-584`) in branch order; Shift+
			# forward steps safely even mid-run (`seg005.c:592-605`).
			if input.y == -1:
				_start_seq(s, "run_jump")
			elif input.shift == 1 and input.x == dir and input.x != 0:
				_safe_step(s)
			elif input.x == 0:
				_start_seq(s, "run_stop")
			elif input.x == -dir:
				_start_seq(s, "turn")
		"crouch":
			pass  # stoop head is locked; the stand-up control fires at f109 only
			      # (seg005.c:285-287 dispatches control_crouched on the frame)
		"crouch_cycle":
			if input.y != 1:
				_start_seq(s, "stand_up")         # control_crouched: down released → seq_49 (seg005.c:313-332)
		"soft_land_crouch":
			# control_crouched is dispatched on FRAME f109 whatever sequence
			# reached it (`seg005.c:285-287`): soft_land_crouch loops on f109
			# waiting for this dispatch. Down keeps the stoop; released →
			# stand-up (seq_49, `seg005.c:331-332`). Down+forward crouch-hop
			# (seq_79, `seg005.c:334-337`) is not modeled, matching the
			# crouch_cycle arm above.
			if input.y != 1:
				_start_seq(s, "stand_up")
		"grab_hang", "hang", "hang_cycle", "hang_straight":
			_hang_control(s, input)
		_:
			pass  # locked sequence (jump/turn/stop/fall/land/climb/step)


static func _start_seq(s: Dictionary, seq_name: String) -> void:
	s["seq"] = seq_name
	s["op"] = 0


## The hang-family control, extracted from the `_control` match so the
## probe precomputation stays out of the pattern block. Mirrors
## control_hanging (`seg005.c:768-820`) in its branch order: Up with
## grab_timer 0 → can_climb_up (`seg005.c:786-830`: open air above the hands
## → the climb; floor/wall above the lip → the climbfail jump). Shift with
## the char tile a wall → hang straight (776-796); Shift with open air
## above the hands, or Shift released → hang_fall (798-808, 810-854).
## Tile probes read the pin state so entry-derived columns hold
## (`seg006.c:1187-1190`).
static func _hang_control(s: Dictionary, input: PopInput) -> void:
	# `grab_col` carries the entry pin as col+1; 0 = not pinned (climb-down
	# hangs re-derive the column per tick, the m7 climbing column).
	var probe_col: int = 0
	if int(s["grab_col"]) > 0:
		probe_col = int(s["grab_col"]) - 1
	else:
		probe_col = _col_of(_m7_x(_foot_x(s), int(s["dir"])))
	var at: int = _tile(s, int(s["row"]), probe_col)
	var above: int = _tile(s, int(s["row"]) - 1, probe_col)
	if int(s["grab_timer"]) == 0 and input.y == -1:
		s["grab_col"] = 0              # the pin ends with the hang
		_start_seq(s, "climb_up")      # control_hanging: Up with timer 0 → can_climb_up
		                               # (seg005.c:774-780); can_climb_up (seg005.c:812-830)
		                               # always climbs — the reference climbfail label is
		                               # unreachable (nothing jumps to it; check_bumped
		                               # excludes the climb frames 135–148, seg004.c:151-157)
	elif input.y == 1 and input.shift == 1:
		# Down+Shift at a cliff edge: step forward 5 and climb down
		# (seg005.c:461-495 down_pressed → climb_down when floorless ahead
		# within 3 units; seg005.c:470 char_dx_forward(5)).
		var foot_x := _foot_x(s)
		var ahead_col: int = _col_of(foot_x) + int(s["dir"])
		if not _is_floor(_tile(s, int(s["row"]), ahead_col)):
			s["x"] = int(s["x"]) + int(s["dir"]) * 5
			_start_seq(s, "climb_down")
		else:
			_hang_release(s)
	elif input.shift == 1:
		if String(s["seq"]) != "hang_straight" and at == PopTables.Tile.WALL:
			_start_seq(s, "hang_straight")  # hang against a wall (seg005.c:776-796)
		elif not _is_floor(above):
			_hang_release(s)            # open air above the hands (seg005.c:798-808)
	else:
		_hang_release(s)                # Shift released → drop (seg005.c:810-820)


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
			PopTables.Op.ROW_UP:
				s["row"] = int(s["row"]) - 1       # climb up carries the kid onto the ledge (SEQ_UP, `seg006.c:675-677`)
				s["grab_col"] = 0                  # the hang pin ends with the climb
			PopTables.Op.ROW_DOWN:
				s["row"] = int(s["row"]) + 1       # climb down descends a row (SEQ_DOWN, `seg006.c:675-677`)


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
		if int(s["frame"]) >= 102 and int(s["frame"]) < 106:
			_check_grab(s)               # reference check_action → check_grab on fall frames 102–105 (`seg006.c:922-926`)
	elif action == PopTables.Action.HANG_CLIMB:
		pass                             # hanging: no floor checks (control drives climb/release)
	elif action == PopTables.Action.BUMPED or action == PopTables.Action.HANG_STRAIGHT:
		if int(s["frame"]) == 109:
			_check_on_floor(s)           # reference checks the crouch frame only (`seg006.c:907-919`)
	else:
		_check_on_floor(s)               # STAND / RUN_JUMP / TURN (`seg006.c:927-928`)


## Falling: release-react above this row's floor level; at floor level →
## land if the tile is floor, else descend one row (`seg005.c:42-109`).
static func _do_fall(s: Dictionary) -> void:
	if int(s["row"]) > 3:
		_fell_out(s)
		return
	if _floor_y(int(s["row"])) > int(s["y"]):
		_check_grab(s)  # still airborne — Shift+falling+grabbable tile ahead-above grabs (`seg005.c:42-44`, `seg006.c:1175-1201`)
		return
	var col := _col_of(_foot_x(s))
	if _is_floor(_tile(s, int(s["row"]), col)):
		_land(s)
	else:
		s["row"] = int(s["row"]) + 1


## Walking/upright floor checks: the hang/climb frames probe with the
## reference determine_col m7 variant (`seg006.c:014D` + `get_tile_div_mod_m7`,
## subtracts 7): the hanging feet would otherwise falsify a fall over the
## ledge lip. The plain left-edge probe stays for the calibrated A2.2
## frames; the m7 migration is noted in the simplification list.
static func _check_on_floor(s: Dictionary) -> void:
	var frame: int = int(s["frame"])
	var row: Dictionary = PopTables.KID_FRAME.get(frame, {})
	if int(row.get("needs_floor", 0)) == 0:
		return
	var foot_x: int = _foot_x(s)
	if (frame >= 87 and frame < 100) or (frame >= 135 and frame < 149):
		foot_x = _m7_x(foot_x, int(s["dir"]))   # determine_col m7 variant (`seg006.c:014D`)
	var col := _col_of(foot_x)
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


# --- A2.3: grab, hang, climb, crouch, safe-step ----------------------------
# All values and rules re-derived from the reference with the file:line
# citations given per rule; no code is copied.


## Mid-air grab (`seg006.c:1175-1200`): Shift held, fall speed < 32, alive,
## and the depth gate `(word)y_land[row + 1] <= (word)(y + 25)` — i.e.
## `floor_y(row) > y + 25` must be false: only when the kid is at or below
## a quarter-row distance from the floor line can he catch the ledge lip.
static func _check_grab(s: Dictionary) -> void:
	if not (int(s["input_shift"]) == 1 and int(s["fall_y"]) < 32 and int(s["fall_y"]) >= 0):
		return
	if _floor_y(int(s["row"])) > int(s["y"]) + 25:
		return
	var tile := _grab_target(s)
	if tile < 0:
		return
	_snap_to_grab(s)


## The tile ahead-above if grabbable, else −1 (`seg006.c:1267-1271` +
## `seg006.c:1588-1608`): the probes are get_tile_above_char (the char's
## column, one row up) for the through tile and get_tile_front_above_char
## (column in front, one row up) for the target; the through tile must not
## be a wall or floor, the target must be floor.
static func _grab_target(s: Dictionary) -> int:
	var row: int = int(s["row"])
	var col := _col_of(_foot_x(s))
	var through := _tile(s, row - 1, col)
	if through == PopTables.Tile.WALL or _is_floor(through):
		return -1
	var target := _tile(s, row - 1, col + int(s["dir"]))
	if not _is_floor(target):
		return -1
	return target


## Commit to the grabbed ledge (`seg006.c:1188-1199`): the initial probe
## (x forward −8) is discarded; the character is carried the rest of the
## way to the lip edge (`distance_to_edge_weight`), y snaps to the falling
## row's floor, fall speed resets. `load_fram_det_col()` ran at the probe
## x, so the hang's tile column is fixed there and stays pinned through the
## sway — carried as `grab_col` (col+1; 0 = unpinned).
static func _snap_to_grab(s: Dictionary) -> void:
	var row: int = int(s["row"])
	var probe_x: int = _foot_x(s) - 8 * int(s["dir"])   # the check_grab probe
	s["grab_col"] = _col_of(_m7_x(probe_x, int(s["dir"]))) + 1
	s["x"] = int(s["x"]) + int(s["dir"]) * _dist_to_edge(s, _foot_x(s))
	s["y"] = _floor_y(row)
	s["fall_y"] = 0
	s["fall_x"] = 0
	s["grab_timer"] = PopTables.GRAB_TIMER
	_start_seq(s, "grab_hang")
	# Reference check_grab calls play_seq() right after seqtbl_offset_char
	# (`seg006.c:1196-1197`) — grab_hang's opening f80 shows on the grab
	# tick itself; step()'s own later advance would consume the sway head.
	_advance(s)


## Release from a hang (`seg005.c:836-854` hang_fall): a floor behind or at
## the char's column → drop to the feet (`seqtbl.c:601-607`), else release
## into a fall (`seqtbl.c:608-612`).
static func _hang_release(s: Dictionary) -> void:
	s["grab_col"] = 0                 # the pin ends with the hang
	var row: int = int(s["row"])
	var col := _col_of(_foot_x(s))
	var behind := _tile(s, row, col - int(s["dir"]))
	var at := _tile(s, row, col)
	if not _is_floor(behind) and not _is_floor(at):
		_start_seq(s, "release_fall")
	else:
		_start_seq(s, "hang_drop")


## Up from stand (`seg005.c:407-424` up_pressed → `check_jump_up`,
## `seg005.c:679-693`): the reference probes with curr_col from
## determine_col — the m7 column (`seg006.c:0122-0124`, `seg006.c:0690-0692`)
## — tries the front-above grab lane, then the above-tile lane, and falls
## back to a straight jump up. The grab is NOT Shift-gated: both the Shift
## and the plain-Up chains end in `up_pressed` (`seg005.c:379-382`,
## `seg005.c:428-431`); Shift only decides whether the hang holds afterwards
## (`seg005.c:798-820`).
static func _jump_up_from_stand(s: Dictionary) -> void:
	var dir: int = int(s["dir"])
	var row: int = int(s["row"])
	var col := _det_col(s)
	# Lane 1 (`seg005.c:682-685`): through = above the char, target = the
	# tile front-above → grab_up_with_floor_behind.
	if _can_grab(_tile(s, row - 1, col), _tile(s, row - 1, col + dir)):
		_grab_up_with_floor_behind(s)
		return
	# Lane 2 (`seg005.c:686-690`): through = behind-above, target = the tile
	# directly above → jump_up_or_grab.
	if _can_grab(_tile(s, row - 1, col - dir), _tile(s, row - 1, col)):
		_jump_up_or_grab(s, col)
		return
	# Nothing grabbable → the straight jump up (`seg005.c:691-692`).
	if not _jump_up_route(s):
		return
	_start_seq(s, "jump_up")


## can_grab (`seg006.c:1588-1608`): the through tile must be neither a wall
## nor floor, and the target tile must be floor. The doortop / shaking-loose
## modifiers are unmodeled (no doortop grab in our rooms).
static func _can_grab(through: int, target: int) -> bool:
	if through == PopTables.Tile.WALL or _is_floor(through):
		return false
	return _is_floor(target)


## determine_col's column (`seg006.c:0122-0124`): m7 of dx_weight — the
## source subtracts 7 unconditionally (`seg006.c:0690-0692`), it is not
## direction-relative (unlike `_m7_x`, see the A5.1 GAP list).
static func _det_col(s: Dictionary) -> int:
	return _col_of(_foot_x(s) - 7)


## distance_to_edge_weight (`seg006.c:1305-1317`): distance from the m7
## column to the edge the char faces — facing right → 13 − xl (TILE_RIGHTX),
## facing left → xl (`types.h:1407`).
static func _dist_to_edge_weight(s: Dictionary) -> int:
	var m: int = _foot_x(s) - 7
	var xl: int = m - (58 + 14 * _col_of(m))
	return (13 - xl) if int(s["dir"]) == 1 else xl


## get_edge_distance (`seg004.c:067C-0433`), reduced to the tile kinds we
## model: floor ahead in the char's row → (EDGE_TYPE_FLOOR, 11); no floor
## ahead → (EDGE_TYPE_CLOSER, distance_to_edge_weight()) (`seg004.c:417-427`).
## The wall-typed branch (gate/doortop/mirror/chomper `dist_from_wall_forward`)
## is unmodeled — the sim has no wall bump (reported simplification).
static func _edge_distance(s: Dictionary, col: int) -> Array:
	if _is_floor(_tile(s, int(s["row"]), col + int(s["dir"]))):
		return [2, 11] # EDGE_TYPE_FLOOR
	return [0, _dist_to_edge_weight(s)]   # EDGE_TYPE_CLOSER


## grab_up_with_floor_behind (`seg005.c:858-881`): commit Char.x by the edge
## distance, then either the straight grab (seq_8 = jumphangMed, no dx — the
## commit already carried the kid) or the forward grab (seq_24 =
## jumphangLong, whose dx +1/+2/+1 across f78–f80 makes up the "distance − 4"
## shortfall). JUMP_STRAIGHT_CONDITION is the uncorrected source form
## (`seg005.c:868-869`): distance < 4 && edge_distance < 4 && edge_type != EDGE.
static func _grab_up_with_floor_behind(s: Dictionary) -> void:
	var dir: int = int(s["dir"])
	var distance := _dist_to_edge_weight(s)
	var edge := _edge_distance(s, _det_col(s))
	if distance < 4 and int(edge[1]) < 4 and int(edge[0]) != _EDGE_TYPE_EDGE:
		s["x"] = int(s["x"]) + dir * distance
		_start_seq(s, "jump_grab_straight")
	else:
		s["x"] = int(s["x"]) + dir * (distance - 4)
		_start_seq(s, "jump_grab_forward")


## jump_up_or_grab (`seg005.c:713-738`): the grabbable tile sits directly
## above the char. Under 6 units from the edge → a plain jump up; no floor
## behind → grab_up_no_floor_behind (x += distance − 10, seq_16 =
## jumpbackhang, whose own dx −5 across f77–f80 completes it); floor behind →
## step back `distance − TILE_SIZEX`, re-probe, then the shared commit
## (`seg005.c:728-735`).
static func _jump_up_or_grab(s: Dictionary, col: int) -> void:
	var dir: int = int(s["dir"])
	var distance := _dist_to_edge_weight(s)
	if distance < 6:
		if not _jump_up_route(s):
			return
		_start_seq(s, "jump_up")
		return
	if not _is_floor(_tile(s, int(s["row"]), col - dir)):
		s["x"] = int(s["x"]) + dir * (distance - 10)
		_start_seq(s, "jump_grab_up")
		return
	s["x"] = int(s["x"]) + dir * (distance - PopTables.TILE_W)
	_grab_up_with_floor_behind(s)


## Straight-up route guard: nothing above blocks the jump (through tile
## open) and the lip column's ledge is climbable (`seg005.c:786-794`).
static func _jump_up_route(s: Dictionary) -> bool:
	if _above_is_climbable(s):
		return true
	return false


## Climb-up guard (`seg005.c:786-794` can_climb_up ≙ check_jump_up lane):
## the tile above the lip column must be open air (not floor, not wall)
## and the row-2 ahead tile must be standable — a floor or wall overhead
## blocks the climb out.
static func _above_is_climbable(s: Dictionary) -> bool:
	var row: int = int(s["row"])
	var foot_x := _foot_x(s)
	var upper_col: int = _col_of(_m7_x(foot_x, int(s["dir"])))
	var upper: int = _tile(s, row - 2, upper_col)
	if _is_floor(upper) or upper == PopTables.Tile.WALL:
		return false
	return true


## Down from stand (`seg005.c:461-495` down_pressed): at a floorless edge
## within 3 units → step forward 5 and climb down (`seg005.c:470`,
## `char_dx_forward(5)`); otherwise a bare crouch (`seg005.c:476/494`,
## seq_50_crouch with **no** dx; the sequence's own stoop head carries dx).
static func _down_pressed(s: Dictionary) -> void:
	var row: int = int(s["row"])
	var foot_x := _foot_x(s)
	var ahead_col: int = _col_of(foot_x) + int(s["dir"])
	if not _is_floor(_tile(s, row, ahead_col)) and _dist_to_edge(s, foot_x) < 3:
		s["x"] = int(s["x"]) + int(s["dir"]) * 5
		_start_seq(s, "climb_down")
		return
	_start_seq(s, "crouch")


## Shift+forward from stand (`seg005.c:592-605` safe_step): distance d =
## get_edge_distance (`seg004.c:378-433`) — floor ahead → the plain 11-unit
## step (seq_39); no floor ahead at d>0 → the d-unit step seq_{28+d}; at
## d=0 (on the very lip) the hold / unsafe-step pair is A2.3-optional and
## stays unmodeled.
static func _safe_step(s: Dictionary) -> void:
	var foot_x := _foot_x(s)
	var col := _col_of(foot_x)
	if _is_floor(_tile(s, int(s["row"]), col + int(s["dir"]))):
		_start_seq(s, "safe_step_11")
		return
	var distance: int = _dist_to_edge(s, foot_x)
	if distance > 0:
		_start_seq(s, "safe_step_%d" % mini(distance, 14))
	## distance == 0: seq_44 step-on-edge / seq_39 hold — A2.3-optional


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


## The m7 determine_col probe (`seg006.c:014D` + `get_tile_div_mod_m7`,
## `seg006.c:690-692`): the plain get_tile_div_mod column formula shifted
## 7 internal units back against the facing direction.
static func _m7_x(foot_x: int, dir: int) -> int:
	return foot_x - 7 * dir


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
		h = _fold(h, state[key])
	return h


## Fold one value into the running hash: strings by UTF-8 byte, dictionaries
## by sorted key (so gate/plate/exit maps hash order-stably), arrays in order,
## everything else as a little-endian int.
static func _fold(h: int, v: Variant) -> int:
	if v is String:
		for b: int in (v as String).to_utf8_buffer():
			h = _fold_byte(h, b)
	elif v is Dictionary:
		var d: Dictionary = v
		var keys: Array = d.keys()
		keys.sort()
		for k: Variant in keys:
			h = _fold(h, str(k))
			h = _fold(h, d[k])
	elif v is Array:
		for item: Variant in (v as Array):
			h = _fold(h, item)
	elif v is bool:
		h = _fold_byte(h, 1 if (v as bool) else 0)
	else:
		var iv: int = int(v)
		for i: int in 8:
			h = _fold_byte(h, (iv >> (i * 8)) & 0xFF)
	return h


static func _fold_byte(h: int, b: int) -> int:
	return ((h ^ b) * _FNV_PRIME) & _FNV_MASK
