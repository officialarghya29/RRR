class_name PopGuard
extends RefCounted
## Plan A4.3 — the guard duel, run as a 10 fps logic simulation (plan §4.7,
## §8 gate 3).
##
## Decision tables come from PARITY §12 (`data.h:835-847`), the sword frame
## chains from PARITY §13 (`seqtbl.c:314-358`, `seg002.c:1004-1036`), and the
## generator from PARITY §14 (`seg009.c:251-252`, `PopRng`). The fire rule is
## `table[skill] > prandom(255)` — probability value/256 — and the three
## decisions are drawn in the reference's consumption order (advance
## `seg002.c:864-870`, block `872-885`, strike `887-899`).
##
## Pure and integer-only: `duel()` is a function of its seed, skill and the
## scripted kid inputs, so the same seed always yields the same transcript.

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
const KID_HIT_FRAMES: Array[int] = [153, 154]    ## the only hit window (`seg002.c:1004/1014/1036`)
const PARRY_FRAMES: Array[int] = [150, 161]      ## a parry stops hits (`seg002.c:1010`)
const KID_BLOCK_REACT_FRAMES: Array[int] = [152, 153, 162]  ## block reacts here (`seg002.c:875`)
const STRIKE_SKIP_FRAMES: Array[int] = [169, 151]## strike skipped when the opponent is here (`seg002.c:891-899`)
const CHAIN_STRIKE: Array[int] = [168, 151, 152, 153, 154, 155, 156, 157]
const CHAIN_BLOCK: Array[int] = [169, 150]
const CHAIN_BLOCKED: Array[int] = [167, 155, 156, 157]
const CHAIN_BLOCK_STRIKE: Array[int] = [162, 152, 153, 154, 155, 156, 157]
const CHAIN_STRIKE_BLOCK: Array[int] = [159, 160, 150]
const CHAIN_ADVANCE: Array[int] = [163, 164]
const CHAIN_RETREAT: Array[int] = [160, 157]
## PARITY §13 gives the block as "f169→f150 loop→ready" without an exit count,
## so how long the f150 loop is held is ours (sim characterization).
const BLOCK_HOLD_TICKS: int = 4


static func guard_skill_max() -> int:
	return BASE_HP.size() - 1


static func guard_hp(skill: int) -> int:
	return BASE_HP[skill] + BONUS_HP[skill]


static func initial(skill: int, dir: int = -1) -> Dictionary:
	return {
		"skill": skill,
		"dir": dir,
		"hp": guard_hp(skill),
		"seq": "ready",
		"frame": READY_FRAME,
		"index": 0,
		"refractimer": 0,
		"dead": 0,
	}


static func initial_kid() -> Dictionary:
	return {
		"hp": PopTables.KID_HP_START,
		"seq": "ready",
		"frame": READY_FRAME,
		"index": 0,
		"dead": 0,
	}


## Run a scripted duel to a decision. `kid_script` is one command per tick
## ("strike" / "block" / anything else = idle). Returns the transcript, both
## HP totals and the winner.
static func duel(seed: int, skill: int, kid_script: Array, max_ticks: int) -> Dictionary:
	var rng := PopRng.new()
	rng.state = PopRng.normalize_seed(seed)
	var guard := initial(skill)
	var kid := initial_kid()
	var transcript: Array = []
	var tick := 0
	while tick < max_ticks and int(guard["hp"]) > 0 and int(kid["hp"]) > 0:
		tick += 1
		_kid_command(kid, String(kid_script[mini(tick - 1, kid_script.size() - 1)]), transcript)
		_resolve(kid, guard, transcript)     # hits on the frames as they stand
		_advance(kid)
		_advance(guard)
		_decide(guard, kid, rng, transcript)
		if int(guard["refractimer"]) > 0:
			guard["refractimer"] = int(guard["refractimer"]) - 1
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
		"retreat":
			return CHAIN_RETREAT
	return []


static func _start(p: Dictionary, seq: String) -> void:
	p["seq"] = seq
	p["index"] = 0
	var chain := _chain_for(seq)
	if not chain.is_empty():
		p["frame"] = int(chain[0])


static func _to_ready(p: Dictionary) -> void:
	p["seq"] = "ready"
	p["frame"] = READY_FRAME
	p["index"] = 0


## One logic frame of animation: 1 frame per tick (PARITY §13), returning to
## the f158 ready loop when the chain runs out.
static func _advance(p: Dictionary) -> void:
	var seq := String(p["seq"])
	if seq == "ready":
		return
	if seq == "block":
		# f169 then the f150 loop, held for BLOCK_HOLD_TICKS
		var i: int = int(p["index"]) + 1
		if i < BLOCK_HOLD_TICKS:
			p["index"] = i
			p["frame"] = int(CHAIN_BLOCK[mini(i, CHAIN_BLOCK.size() - 1)])
			return
		_to_ready(p)
		return
	var chain := _chain_for(seq)
	if chain.is_empty():
		_to_ready(p)
		return
	var j: int = int(p["index"]) + 1
	if j >= chain.size():
		_to_ready(p)
		return
	p["index"] = j
	p["frame"] = int(chain[j])


static func _kid_command(kid: Dictionary, cmd: String, transcript: Array) -> void:
	if String(kid["seq"]) == "block":
		# the f150 loop holds until the block is released
		if cmd != "block":
			_to_ready(kid)
		return
	if String(kid["seq"]) != "ready":
		return   # mid-chain: the next command waits its turn
	if cmd == "strike":
		_start(kid, "strike")
		transcript.append("k:strike")
	elif cmd == "block":
		_start(kid, "block")
		transcript.append("k:block")


## Resolve a hit window: a strike in f153/f154 lands unless the defender is
## parrying (f150/f161), in which case the attacker's strike is turned aside.
static func _resolve(kid: Dictionary, guard: Dictionary, transcript: Array) -> void:
	var kid_frame := int(kid["frame"])
	var guard_frame := int(guard["frame"])
	if String(guard["seq"]) == "strike" and guard_frame in KID_HIT_FRAMES:
		if kid_frame in PARRY_FRAMES:
			transcript.append("k:parry")
			_start(guard, "blocked")
		else:
			_damage(kid, "kid", transcript)
	if String(kid["seq"]) == "strike" and kid_frame in KID_HIT_FRAMES:
		if guard_frame in PARRY_FRAMES:
			transcript.append("g:parry")
			_start(kid, "blocked")
		else:
			_damage(guard, "guard", transcript)


static func _damage(p: Dictionary, who: String, transcript: Array) -> void:
	p["hp"] = int(p["hp"]) - 1
	if int(p["hp"]) <= 0:
		p["hp"] = 0
		p["dead"] = 1
		transcript.append("%s:died" % who)
	else:
		transcript.append("%s:hit" % who)


## The guard's decision frame, drawn only when it is in the f158 ready loop
## (an animating guard cannot re-decide). Draws run in the reference's order:
## advance, then block, then strike.
static func _decide(guard: Dictionary, kid: Dictionary, rng: PopRng, transcript: Array) -> void:
	if String(guard["seq"]) != "ready":
		return
	var d_adv := rng.rand_below(256)
	var d_blk := rng.rand_below(256)
	var d_str := rng.rand_below(256)
	var skill := int(guard["skill"])
	var kid_frame := int(kid["frame"])
	# block reacts to the opponent's frames 152/153/162 (`seg002.c:875`)
	if kid_frame in KID_BLOCK_REACT_FRAMES and BLOCK_ODDS[skill] > d_blk:
		_start(guard, "block")
		transcript.append("g:block")
		return
	# strike is skipped when the opponent is in 169/151 (`seg002.c:891-899`)
	if kid_frame not in STRIKE_SKIP_FRAMES \
			and int(guard["refractimer"]) == 0 \
			and STRIKE_ODDS[skill] > d_str:
		_start(guard, "strike")
		guard["refractimer"] = REFRACTIMER[skill]
		transcript.append("g:strike")
		return
	if ADVANCE_ODDS[skill] > d_adv:
		_start(guard, "advance")
		transcript.append("g:advance")
	else:
		_start(guard, "retreat")
		transcript.append("g:retreat")
