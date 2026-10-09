class_name PopGuard
extends RefCounted
## Plan A4.3 — the guard duel, run as a 10 fps logic simulation (plan §4.7,
## §8 gate 3).
##
## Decision tables come from PARITY §12 (`data.h:835-847`), the sword frame
## chains from PARITY §13 (`seqtbl.c:314-358`, `seg002.c:1004-1036`), the
## generator from PARITY §14 (`seg009.c:251-252`, `PopRng`), and reach,
## decision bands and trap deaths from PARITY §20 (`seg006.c:2117-2131`,
## `seg002.c:737-899`, `seg006.c:950-965`, `seg004.c:439-484`).
##
## The fire rule for every §12 table is `table[skill] > prandom(255)` —
## probability value/256 — and the draws happen in the reference's order and
## only where the reference draws (block, then advance-or-strike:
## `seg002.c:848-861`, `seg002.c:864-899`).
##
## Pure and integer-only: `duel()` is a function of its seed, skill, scripted
## kid inputs and hazards, so the same seed always yields the same transcript.

# --- §12 decision tables (index = skill; `data.h:835-847`) ------------------
const STRIKE_ODDS: Array[int] = [61, 100, 61, 61, 61, 40, 100, 220, 0, 48, 32, 48]
const RESTRIKE_ODDS: Array[int] = [0, 0, 0, 5, 5, 175, 16, 8, 0, 255, 255, 150]
const BLOCK_ODDS: Array[int] = [0, 150, 150, 200, 200, 255, 200, 250, 0, 255, 255, 255]
const IMPBLOCK_ODDS: Array[int] = [0, 61, 61, 100, 100, 145, 100, 250, 0, 145, 255, 175]
const ADVANCE_ODDS: Array[int] = [255, 200, 200, 200, 255, 255, 200, 0, 0, 255, 100, 100]
const REFRACTIMER: Array[int] = [16, 16, 16, 16, 8, 8, 8, 8, 0, 8, 0, 0]
const BONUS_HP: Array[int] = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
const BASE_HP: Array[int] = [4, 3, 3, 3, 3, 4, 5, 4, 4, 5, 5, 5]

# --- §13 sword frame chains -------------------------------------------------
const READY_FRAME: int = 158                     ## ready: f158 loop (`seqtbl.c:287`)
const KID_HIT_FRAMES: Array[int] = [153, 154]    ## frames that process a hit (`seg002.c:1004`)
const STRIKE_DAMAGE_FRAME: int = 154             ## only this frame damages (`seg002.c:1014`)
const PARRY_FRAMES: Array[int] = [150, 161]      ## a parry stops hits (`seg002.c:1010`)
const KID_BLOCK_REACT_FRAMES: Array[int] = [152, 153, 162]  ## block reacts here (`seg002.c:875`)
const STRIKE_SKIP_FRAMES: Array[int] = [169, 151]## strike skipped when the opponent is here (`seg002.c:891`)
const CHAIN_STRIKE: Array[int] = [168, 151, 152, 153, 154, 155, 156, 157]
const CHAIN_BLOCK: Array[int] = [169, 150]
const CHAIN_BLOCKED: Array[int] = [167, 155, 156, 157]
const CHAIN_BLOCK_STRIKE: Array[int] = [162, 152, 153, 154, 155, 156, 157]
const CHAIN_STRIKE_BLOCK: Array[int] = [159, 160, 150]
const CHAIN_ADVANCE: Array[int] = [163, 164, 165]   ## guard forward (`seqtbl.c:314-319`)
const CHAIN_FASTADVANCE: Array[int] = [164, 165]    ## kid forward, seq 86 (`seqtbl.c:321-324`)
const CHAIN_RETREAT: Array[int] = [160, 157]        ## back with sword (`seqtbl.c:326-329`)
## The dx op beside each chain frame, in the mover's own facing (PARITY §20
## advance/fastadvance/retreat dx rows, `seqtbl.c:316-328`).
const CHAIN_DX: Dictionary = {
	"advance": [2, 4, 0],
	"fastadvance": [6, 0],
	"retreat": [-3, -2],
}
## PARITY §13 gives the block as "f169→f150 loop→ready" without an exit count,
## so how long the f150 loop is held is ours (sim characterization).
const BLOCK_HOLD_TICKS: int = 4

# --- §20 reach, distance, trap rules ---------------------------------------
const SWORD_DRAWN: int = 2                ## sword status (`types.h:319-321`)
const FRONT_OFFSET: int = 13              ## +13 when facing each other (`seg006.c:2127-2129`)
const HIT_MAX: int = 29                   ## hit range max (`seg002.c:1021`)
const HIT_MIN_DRAWN: int = 12             ## defender drawn (`seg002.c:1018`)
const HIT_MIN_UNSHEATHED: int = 8         ## defender undrawn (`seg002.c:1016`)
const ENGAGE_RANGE: int = 35              ## engage gate (`seg002.c:758`)
const TOO_CLOSE: int = 12                 ## too-close band (`seg002.c:759`)
const TOO_CLOSE_UNSHEATHED: int = 8       ## too-close with sword undrawn (`seg002.c:759`)
const ARMED_ADVANCE_BELOW: int = 10       ## armed advance band (`seg002.c:849`)
const PARRY_FAR: int = 32                 ## parry becomes retreat at ≥32 (`seg005.c:1063`)
const STRIKE_TIMER_START: int = 15        ## kid_sword_strike on strike (`seg005.c:994`)
const JUSTBLOCKED_START: int = 4          ## justblocked when a guard attack is parried (`seg002.c:1028`)
## Duel geometry: kid at START_X facing right, guard START_DIST - FRONT_OFFSET
## units to his right facing left, i.e. signed distance START_DIST (both are
## sim characterization — reference spawn distances are level data).
const START_X: int = 100
const START_DIST: int = 20


static func guard_skill_max() -> int:
	return BASE_HP.size() - 1


static func guard_hp(skill: int) -> int:
	return BASE_HP[skill] + BONUS_HP[skill]


static func initial(skill: int, dir: int = -1) -> Dictionary:
	return {
		"skill": skill,
		"dir": dir,
		"sword": SWORD_DRAWN,
		"hp": guard_hp(skill),
		"seq": "ready",
		"frame": READY_FRAME,
		"index": 0,
		"refractimer": 0,
		"justblocked": 0,
		"dead": 0,
	}


static func initial_kid() -> Dictionary:
	return {
		"dir": 0,                       # dir_0_right (`types.h:389`)
		"sword": SWORD_DRAWN,
		"sword_strike": 0,
		"hp": PopTables.KID_HP_START,
		"seq": "ready",
		"frame": READY_FRAME,
		"index": 0,
		"dead": 0,
	}


## `char_opp_dist()` (`seg006.c:2117-2131`): Opp.x - Char.x, negated when the
## character faces left (`dir_0_right = 0`, `dir_FF_left = -1`, `types.h:389-391`),
## plus FRONT_OFFSET when the result is ≥ 0 and the two face different
## directions. Positive = opponent in front. The cross-room 999 case is omitted:
## the duel is one room.
static func opp_dist(x_self: int, dir_self: int, x_opp: int, dir_opp: int) -> int:
	var d := x_opp - x_self
	if dir_self < 0:
		d = -d
	if d >= 0 and dir_self != dir_opp:
		d += FRONT_OFFSET
	return d


## min_hurt_range: 8 if the defender's sword is undrawn, 12 if drawn
## (`seg002.c:1016-1018`).
static func _min_hurt(defender_sword: int) -> int:
	return HIT_MIN_UNSHEATHED if defender_sword < SWORD_DRAWN else HIT_MIN_DRAWN


## World x step for dx expressed in p's own facing (dir 0 = right, -1 = left).
static func _world_dx(p: Dictionary, dx_own: int) -> int:
	return dx_own if int(p["dir"]) >= 0 else -dx_own


## Run a scripted duel to a decision. `kid_script` is one command per tick
## ("strike" / "block" / "advance" / "retreat" / anything else = idle).
## `hazards` maps "kid"/"guard" to a list of {"kind": "spike", "harmful": n}
## or {"kind": "chomper", "phase": n} dicts checked on every tick for that
## fighter (PARITY §20 trap rows). Returns the transcript, both HP totals, the
## winner, the tick count and the final signed distance.
static func duel(seed: int, skill: int, kid_script: Array, max_ticks: int,
		hazards: Dictionary = {}) -> Dictionary:
	var rng := PopRng.new()
	rng.state = PopRng.normalize_seed(seed)
	var guard := initial(skill)
	var kid := initial_kid()
	var kid_x := START_X
	var guard_x := START_X + START_DIST - FRONT_OFFSET   # facing: signed = raw + 13
	var transcript: Array = []
	var tick := 0
	while tick < max_ticks and int(guard["hp"]) > 0 and int(kid["hp"]) > 0:
		tick += 1
		var kdx := _kid_command(kid,
			String(kid_script[mini(tick - 1, kid_script.size() - 1)]), transcript)
		kid_x += _world_dx(kid, kdx)
		_resolve(kid, guard, transcript,
			opp_dist(kid_x, int(kid["dir"]), guard_x, int(guard["dir"])))
		kid_x += _world_dx(kid, _advance(kid))
		guard_x += _world_dx(guard, _advance(guard))
		var sdist := opp_dist(kid_x, int(kid["dir"]), guard_x, int(guard["dir"]))
		guard_x += _world_dx(guard, _decide(guard, kid, rng, transcript, sdist))
		# per-frame timer decay (`seg002.c:634-636`)
		if int(guard["refractimer"]) > 0:
			guard["refractimer"] = int(guard["refractimer"]) - 1
		if int(guard["justblocked"]) > 0:
			guard["justblocked"] = int(guard["justblocked"]) - 1
		if int(kid["sword_strike"]) > 0:
			kid["sword_strike"] = int(kid["sword_strike"]) - 1
		# trap checks run at the end of the frame for both parties
		# (`seg000.c:1205-1208` kid, `seg000.c:1230-1235` guard)
		var kid_haz: Array = hazards.get("kid", [])
		for hz: Dictionary in kid_haz:
			trap_step(kid, "kid", hz, tick, transcript)
		var guard_haz: Array = hazards.get("guard", [])
		for hz2: Dictionary in guard_haz:
			trap_step(guard, "guard", hz2, tick, transcript)
	var winner := "kid"
	if int(guard["hp"]) > 0:
		winner = "guard" if int(kid["hp"]) <= 0 else "none"
	transcript.append("end:%s" % winner)
	return {
		"transcript": transcript,
		"guard_hp": int(guard["hp"]),
		"kid_hp": int(kid["hp"]),
		"winner": winner,
		"ticks": tick,
		"dist": opp_dist(kid_x, int(kid["dir"]), guard_x, int(guard["dir"])),
	}


static func _chain_for(seq: String) -> Array:
	match seq:
		"strike":
			return CHAIN_STRIKE
		"blocked":
			return CHAIN_BLOCKED
		"block_strike":
			return CHAIN_BLOCK_STRIKE
		"strike_block":
			return CHAIN_STRIKE_BLOCK
		"advance":
			return CHAIN_ADVANCE
		"fastadvance":
			return CHAIN_FASTADVANCE
		"retreat":
			return CHAIN_RETREAT
	return []


## The dx op executed when the chain enters frame index `idx`: in the reference
## each dx sits beside its frame op (`seqtbl.c:316-328`), so the chain's start
## pays dx[0] and each step pays dx[j].
static func _dx_of(seq: String, idx: int) -> int:
	var dxs: Array = CHAIN_DX.get(seq, [])
	return int(dxs[idx]) if idx < dxs.size() else 0


## Start a chain; returns this tick's dx in the mover's own facing.
static func _start(p: Dictionary, seq: String) -> int:
	p["seq"] = seq
	p["index"] = 0
	var chain := _chain_for(seq)
	if not chain.is_empty():
		p["frame"] = int(chain[0])
	return _dx_of(seq, 0)


static func _to_ready(p: Dictionary) -> void:
	p["seq"] = "ready"
	p["frame"] = READY_FRAME
	p["index"] = 0


## One logic frame of animation: 1 frame per tick (PARITY §13), returning to
## the f158 ready loop when the chain runs out. Returns this tick's dx.
static func _advance(p: Dictionary) -> int:
	var seq := String(p["seq"])
	if seq == "ready":
		return 0
	if seq == "block":
		# f169 then the f150 loop, held for BLOCK_HOLD_TICKS
		var i: int = int(p["index"]) + 1
		if i < BLOCK_HOLD_TICKS:
			p["index"] = i
			p["frame"] = int(CHAIN_BLOCK[mini(i, CHAIN_BLOCK.size() - 1)])
			return 0
		_to_ready(p)
		return 0
	var chain := _chain_for(seq)
	if chain.is_empty():
		_to_ready(p)
		return 0
	var j := int(p["index"]) + 1
	if j >= chain.size():
		_to_ready(p)
		return 0
	p["index"] = j
	p["frame"] = int(chain[j])
	return _dx_of(seq, j)


## Scripted kid input; returns this tick's dx (advance/retreat chains only).
## The kid's forward chain is fastadvance (seq 86), his back chain the shared
## retreat (both rows in PARITY §13/§20).
static func _kid_command(kid: Dictionary, cmd: String, transcript: Array) -> int:
	if String(kid["seq"]) == "block":
		# the f150 loop holds until the block is released
		if cmd != "block":
			_to_ready(kid)
		return 0
	if String(kid["seq"]) != "ready":
		return 0   # mid-chain: the next command waits its turn
	if cmd == "strike":
		kid["sword_strike"] = STRIKE_TIMER_START   # `seg005.c:993-994`
		transcript.append("k:strike")
		return _start(kid, "strike")
	if cmd == "block":
		transcript.append("k:block")
		return _start(kid, "block")
	if cmd == "advance":
		transcript.append("k:advance")
		return _start(kid, "fastadvance")
	if cmd == "retreat":
		transcript.append("k:retreat")
		return _start(kid, "retreat")
	return 0


## Resolve the hit window for one logic frame. The duel abstracts the row gate
## (`seg002.c:1001`) away — both fighters share one row — and `dist` is the
## attacker's `char_opp_dist()` (`seg006.c:2117-2131`). A strike processes only
## in f153/f154 with the attacker's sword drawn (`seg002.c:1000-1004`); only
## f154 damages, inside [min_hurt, 29) where min_hurt is 8 if the defender's
## sword is undrawn and 12 if drawn (`seg002.c:1014-1021`). A defender in
## f150/f161 turns the strike aside instead while 0 <= distance < 29
## (`seg002.c:1009-1013`); a guard attacker also sets justblocked = 4
## (`seg002.c:1028`).
static func _resolve(kid: Dictionary, guard: Dictionary, transcript: Array,
		dist: int = START_DIST) -> void:
	var kid_frame := int(kid["frame"])
	var guard_frame := int(guard["frame"])
	if String(guard["seq"]) == "strike" and guard_frame in KID_HIT_FRAMES \
			and int(guard["sword"]) == SWORD_DRAWN:
		if kid_frame in PARRY_FRAMES and dist >= 0 and dist < HIT_MAX:
			kid["frame"] = PARRY_FRAMES[1]             # defender forced to f161 (`seg002.c:1026`)
			guard["justblocked"] = JUSTBLOCKED_START   # attacker is the guard (`seg002.c:1028`)
			transcript.append("k:parry")
			_start(guard, "blocked")                   # f167-blocked chain (`seg002.c:1030`)
		elif guard_frame == STRIKE_DAMAGE_FRAME \
				and dist >= _min_hurt(int(kid["sword"])) and dist < HIT_MAX:
			_damage(kid, "kid", transcript)
	if String(kid["seq"]) == "strike" and kid_frame in KID_HIT_FRAMES \
			and int(kid["sword"]) == SWORD_DRAWN:
		if guard_frame in PARRY_FRAMES and dist >= 0 and dist < HIT_MAX:
			guard["frame"] = PARRY_FRAMES[1]           # no justblocked: the attacker is the kid
			transcript.append("g:parry")
			_start(kid, "blocked")
		elif kid_frame == STRIKE_DAMAGE_FRAME \
				and dist >= _min_hurt(int(guard["sword"])) and dist < HIT_MAX:
			_damage(guard, "guard", transcript)


static func _damage(p: Dictionary, who: String, transcript: Array) -> void:
	p["hp"] = int(p["hp"]) - 1
	if int(p["hp"]) <= 0:
		p["hp"] = 0
		p["dead"] = 1
		transcript.append("%s:died" % who)
	else:
		transcript.append("%s:hit" % who)
	if who == "guard":
		# a hurt guard waits out his own refractimer (`seg002.c:965-974`)
		p["refractimer"] = REFRACTIMER[int(p["skill"])]


## The guard's decision frame, following autocontrol_guard_active /
## autocontrol_guard_kid_armed (`seg002.c:737-861`): engage gate at 35, the
## too-close band at 12 (8 with the sword undrawn), then the armed bands.
## Draws run in the reference's order — block first, then advance-or-strike —
## and only where the reference draws (`seg002.c:864-899`); far and too-close
## moves draw nothing (`seg002.c:759-766`, `seg002.c:795-801`). Returns the
## guard's own-facing dx this tick (only the walk chains carry dx).
static func _decide(guard: Dictionary, kid: Dictionary, rng: PopRng,
		transcript: Array, dist: int) -> int:
	var seq := String(guard["seq"])
	if seq == "block":
		return _hold_strike(guard, kid, rng, transcript)
	if seq != "ready":
		return 0
	var skill := int(guard["skill"])
	if dist >= ENGAGE_RANGE:
		# autocontrol_guard_kid_far (`seg002.c:795-801`): flat arena = floor
		# ahead, always forward, no RNG draw; gated by refractimer (`seg002.c:773`)
		if int(guard["refractimer"]) != 0:
			return 0
		transcript.append("g:advance")
		return _start(guard, "advance")
	if dist < TOO_CLOSE or (int(guard["sword"]) < SWORD_DRAWN and dist < TOO_CLOSE_UNSHEATHED):
		# too close (`seg002.c:759-766`): in the duel the fighters always face
		# each other, so the guard closes in; same direction would back off
		# (the kid-fleeing case, reachable only if the kid turns).
		if int(guard["dir"]) == int(kid["dir"]):
			transcript.append("g:retreat")
			return _start(guard, "retreat")
		transcript.append("g:advance")
		return _start(guard, "advance")
	if dist < ARMED_ADVANCE_BELOW or dist >= HIT_MAX:
		return _guard_advance(guard, kid, rng, transcript)
	# [12, 29): block first (`seg002.c:852`), then the strike — both draws
	# happen in that order, and simultaneous inputs resolve strike > block,
	# because control_with_sword checks shift2 before up (`seg005.c:993-1015`)
	var kid_frame := int(kid["frame"])
	var block_fired := false
	if kid_frame in KID_BLOCK_REACT_FRAMES:
		var b_odds: Array = IMPBLOCK_ODDS if int(guard["justblocked"]) != 0 else BLOCK_ODDS
		block_fired = int(b_odds[skill]) > rng.rand_below(256)   # `seg002.c:875-881`
	if int(guard["refractimer"]) != 0:
		# strike/advance branch gated by the refractory (`seg002.c:853`)
		if block_fired:
			_start(guard, "block")
			transcript.append("g:block")
		return 0
	if kid_frame in STRIKE_SKIP_FRAMES:
		# guard_strike returns before drawing (`seg002.c:891`)
		if block_fired:
			_start(guard, "block")
			transcript.append("g:block")
		return 0
	var restrike := int(guard["frame"]) in PARRY_FRAMES   # `seg002.c:893-895`
	var s_odds: Array = RESTRIKE_ODDS if restrike else STRIKE_ODDS
	var strike_fired := int(s_odds[skill]) > rng.rand_below(256)
	if block_fired:
		_start(guard, "block")
		transcript.append("g:block")
	if strike_fired:
		# from the ready f158 the normal chain starts; a hold-frame restrike
		# chains from the parry (`seqtbl.c:347-349`)
		_start(guard, "block_strike" if restrike else "strike")
		transcript.append("g:strike")
	return 0


## guard_advance (`seg002.c:864-870`): the advprob draw happens only when the
## guard is skill 0 or the kid's sword-strike timer has run out; a failed or
## skipped draw stands — it never retreats.
static func _guard_advance(guard: Dictionary, kid: Dictionary, rng: PopRng,
		transcript: Array) -> int:
	var skill := int(guard["skill"])
	if skill == 0 or int(kid["sword_strike"]) == 0:
		if ADVANCE_ODDS[skill] > rng.rand_below(256):
			transcript.append("g:advance")
			return _start(guard, "advance")
	return 0


## The strike branch while the f169/f150 block hold is playing: only a
## (re)strike can act from here — parry() and forward_with_sword are frame-gated
## in the reference (`seg005.c:1054-1061`, `seg005.c:918-921`), and
## sword_strike() accepts only f150/f161 (`seg005.c:1044-1047`). Skipped on
## opponent f169/f151 with no draw (`seg002.c:891`); restrikeprob when self is
## in f150/f161, else strikeprob (`seg002.c:893-899`). The draw is consumed even
## when sword_strike() later refuses the frame (`seg005.c:1036-1049`), so from
## f169 the draw is spent but no chain starts.
static func _hold_strike(guard: Dictionary, kid: Dictionary, rng: PopRng,
		transcript: Array) -> int:
	if int(guard["refractimer"]) != 0:
		return 0
	var kid_frame := int(kid["frame"])
	if kid_frame in STRIKE_SKIP_FRAMES:
		return 0
	var skill := int(guard["skill"])
	var restrike := int(guard["frame"]) in PARRY_FRAMES
	var odds: Array = RESTRIKE_ODDS if restrike else STRIKE_ODDS
	if int(odds[skill]) > rng.rand_below(256) and restrike:
		_start(guard, "block_strike")
		transcript.append("g:strike")
	return 0


## One fighter's trap checks for this frame. The reference runs check_spiked
## and check_chomped_* for both parties every frame (`seg000.c:1205-1208` kid,
## `seg000.c:1230-1235` guard, gates omitted). `hazard` is
## {"kind": "spike", "harmful": n} or {"kind": "chomper", "phase": n}; the duel
## places the fighter in the trap's tile instead of modelling tiles and
## collision boxes (sim characterization).
static func trap_step(p: Dictionary, who: String, hazard: Dictionary,
		tick: int, transcript: Array) -> void:
	if int(p["dead"]) != 0:
		return
	var kind := String(hazard.get("kind", ""))
	if kind == "spike":
		var harmful := int(hazard.get("harmful", 0))
		var frame := int(p["frame"])
		# check_spiked windows (`seg006.c:958-960`): run frames need class ≥ 2,
		# landing frames 43/26 trip on any nonzero class. Frames 150-169 are
		# outside both windows, so en garde fighters are safe.
		if (harmful >= 2 and ((frame >= 7 and frame < 15) or (frame >= 34 and frame < 40))) \
				or ((frame == 43 or frame == 26) and harmful != 0):
			_kill(p, who, "spiked", transcript)
	elif kind == "chomper":
		# kill when the stored modifier reads 2 ("closed chomper",
		# `seg004.c:439-450`); the cycle runs 1…15 (`seg007.c:284-289`), and
		# phase = the stored frame at tick 1 (sim characterization of alignment).
		var phase := int(hazard.get("phase", 1))
		var stored := ((phase - 1 + (tick - 1)) % PopTables.CHOMPER_FRAMES) + 1
		if stored == 2:
			# chomped(): take_hp(100) → death (`seg004.c:452-484`)
			_kill(p, who, "chomped", transcript)


static func _kill(p: Dictionary, who: String, cause: String, transcript: Array) -> void:
	p["hp"] = 0
	p["dead"] = 1
	transcript.append("%s:%s" % [who, cause])
