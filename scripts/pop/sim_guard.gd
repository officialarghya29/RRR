class_name SimGuard
extends Node2D
## Session 010 (plan §4.7 duel on the sim path, trim package L2) — the first
## Godot-side enemy that consumes sim events on the NEW path.
##
## What crosses the boundary (read-only snapshots/events only):
##   - reads [SimWorld.state] each logic tick (x / dir — position only) via
##     the world's per-tick [signal SimWorld.logic_tick] signal, plus the
##     tick's packed input byte (the player's intent, published read-only);
##   - REQUESTS damage through [method SimWorld.apply_duel_hit] and death
##     through [method SimWorld.force_death] — SimWorld stays the single
##     writer of sim state (approval condition a). The guard never mutates
##     the state dict itself and never reads an echo's state (echo-vs-guard
##     is B2/3 scope).
##
## The duel logic itself is [PopGuard]'s 10 fps fight simulation re-used
## wholesale: the per-fight-tick driver below mirrors [method PopGuard.duel]'s
## loop body over the SAME static helpers (_kid_command / _resolve / _advance
## / _decide), so no decision, reach or sword-frame rule is re-authored here.
## Fight ticks accumulate at TICK_HZ_SWORD (10) against the world's 12 fps
## logic tick — one fight tick per 1.2 logic ticks.
##
## Two model splits from the reference duel, both sim characterization:
##   - the KID in the duel dict is an abstraction (sword frames run in the
##     duel's own f158-space) while the real kid keeps his traversal frames
##     in PopSim; his duel commands come from the input byte's reserved
##     special bits (1 = strike, 2 = block) and his duel position IS his sim
##     x (the sim drives movement; the duel's kid dx is discarded);
##   - the duel wakes within ACTIVATE_RANGE of the kid and sleeps outside it
##     (the reference guard notices the kid per room/row rules we do not
##     model yet).

## Wake range in sim units (sim characterization, not a PARITY value): the
## duel starts once the kid is this close and sleeps when he leaves again.
const ACTIVATE_RANGE: int = 90
## Placeholder procedural art (trim decision 2026-10-12: guard art stays
## procedural until Arghya delivers sprites).
const BODY_W: float = 26.0
const BODY_H: float = 50.0

## One duel event for the SoundEvent layer (step 4) and tests:
## "clash" (parry either way), "hit_guard", "hit_kid", "defeated".
signal duel_event(kind: StringName)

var world: SimWorld
var guard: Dictionary = {}
var kid: Dictionary = {}
var guard_x: int = 0
var skill: int = 0
var transcript: Array = []
var active: bool = false

var _rng := PopRng.new()
var _acc: int = 0
var _fights: int = 0
var _last_byte: int = 0
## "" while the duel runs, then "kid" / "guard" — whose victory closed it
## (mirrors PopGuard.duel()'s end: transcript marker).
var _ended: String = ""


## Must be called before the node enters the tree. [param seed_n] feeds the
## duel RNG (PopRng, PARITY §14): the same world seed + input script always
## yields the same duel (plan §8 gate 3 on the sim path).
func setup(p_world: SimWorld, x_sim: int, p_skill: int, seed_n: int) -> void:
	world = p_world
	skill = p_skill
	guard_x = x_sim
	guard = PopGuard.initial(skill, -1)   # faces left, toward the kid's approach
	kid = PopGuard.initial_kid()
	_rng.state = PopRng.normalize_seed(seed_n)
	_connect_world()


func _ready() -> void:
	_connect_world()
	queue_redraw()


## Idempotent: setup() may run before or after the node enters the tree
## (GameManager adds first, tests set up first — both orders must bind).
func _connect_world() -> void:
	if world != null and is_instance_valid(world) \
			and not world.logic_tick.is_connected(_on_logic_tick):
		world.logic_tick.connect(_on_logic_tick)


## Per logic tick from the world (read-only snapshot + this tick's input
## byte). The fight tick runs every 1.2 logic ticks (10 fps vs 12 fps).
func _on_logic_tick(state: Dictionary, input_byte: int) -> void:
	if not is_instance_valid(world):
		return
	_last_byte = input_byte
	_acc += PopTables.TICK_HZ_SWORD
	while _acc >= PopTables.TICK_HZ_TRAVERSE:
		_acc -= PopTables.TICK_HZ_TRAVERSE
		_fights += 1
		_fight_tick(state)
	queue_redraw()


func _fight_tick(state: Dictionary) -> void:
	if int(guard.get("dead", 0)) != 0:
		if _ended == "":
			_ended = "kid"
			transcript.append("end:kid")
		return
	var kid_x := int(state.get("x", 0))
	# Wake/sleep on the kid's proximity (sim characterization above): the
	# duel steps only while he is close, so an approaching kid meets the
	# guard at the same seeded state regardless of how far away he started.
	active = absi(kid_x - guard_x) <= ACTIVATE_RANGE
	if not active:
		return
	if int(state.get("dead", 0)) != 0:
		return   # the sim kid is dead: the duel ends without further draws

	# The duel-side kid abstraction mirrors the sim kid's facing: sim dir
	# +1 -> duel dir 0 (right), -1 -> duel dir -1 (left, `types.h:389-391`).
	kid["dir"] = 0 if int(state.get("dir", 1)) >= 0 else -1
	kid_x = int(state.get("x", 0))   # the sim drives the kid's movement

	var before := transcript.size()
	var kid_hp0 := int(kid["hp"])
	var guard_hp0 := int(guard["hp"])

	# Kid command from the tick's input byte: special bit 1 = strike,
	# bit 2 = block; otherwise the movement intent (forward = advance).
	var cmd := "ready"
	if (_last_byte >> 5) & 0x1 != 0:
		cmd = "strike"
	elif (_last_byte >> 6) & 0x1 != 0:
		cmd = "block"
	elif (_last_byte & 0x3) == 1:
		cmd = "advance"
	elif (_last_byte & 0x3) == 3:   # x = -1 packed in 2-bit two's complement
		cmd = "retreat"
	# The duel-side kid dx is discarded: the sim drives the kid's movement
	# (model split in the class header). Only his commands/frames are used —
	# but his chain must still advance, or his sword never reaches f154.
	PopGuard._kid_command(kid, cmd, transcript)

	var dist := PopGuard.opp_dist(kid_x, int(kid["dir"]), guard_x, int(guard["dir"]))
	PopGuard._resolve(kid, guard, transcript, dist)
	PopGuard._advance(kid)   # kid dx discarded: the sim moves the kid
	guard_x += PopGuard._world_dx(guard, PopGuard._advance(guard))
	dist = PopGuard.opp_dist(kid_x, int(kid["dir"]), guard_x, int(guard["dir"]))
	guard_x += PopGuard._world_dx(guard, PopGuard._decide(guard, kid, _rng, transcript, dist))

	# Per-frame timer decay (`seg002.c:634-636`), as in PopGuard.duel().
	if int(guard["refractimer"]) > 0:
		guard["refractimer"] = int(guard["refractimer"]) - 1
	if int(guard["reblock"]) > 0:
		guard["reblock"] = int(guard["reblock"]) - 1
	if int(kid["sword_strike"]) > 0:
		kid["sword_strike"] = int(kid["sword_strike"]) - 1

	# Side-effects of this fight tick's resolutions — the only place the
	# guard touches the world, and only as damage REQUESTS (see header).
	if int(kid["hp"]) < kid_hp0:
		var drop := kid_hp0 - int(kid["hp"])
		duel_event.emit(&"hit_kid")
		SoundEvents.emit_sfx(&"sword_hurt", _px())   # session 010 step 4 hook
		if int(state.get("dead", 0)) == 0:
			world.apply_duel_hit(drop)
		if int(kid["hp"]) <= 0:
			world.force_death()   # no-op if apply_duel_hit already killed
			if _ended == "":
				_ended = "guard"
				transcript.append("end:guard")
	if int(guard["hp"]) < guard_hp0:
		# Session 011 (B2.3): subclass hook FIRST — the boss's shield may
		# restore the local hp here, in which case no damage publishes.
		_guard_hp_absorbed(guard_hp0)
		if int(guard["hp"]) < guard_hp0:
			duel_event.emit(&"hit_guard")
			SoundEvents.emit_sfx(&"sword_strike", _px())   # session 010 step 4 hook
	if int(guard["dead"]) != 0:
		duel_event.emit(&"defeated")
		SoundEvents.emit_sfx(&"guard_death", _px())   # session 010 step 4 hook
	for i: int in range(before, transcript.size()):
		if String(transcript[i]) == "k:parry" or String(transcript[i]) == "g:parry":
			duel_event.emit(&"clash")
			SoundEvents.emit_sfx(&"sword_clash", _px())   # session 010 step 4 hook


## Subclass hook (session 011): called when the local duel reports the
## guard hurt this fight tick, BEFORE the damage events publish. Default is
## a no-op — plain guards behave exactly as before. [SimBoss] overrides it
## to absorb hits while its echo-plate shield is up.
func _guard_hp_absorbed(_hp_before: int) -> void:
	pass


## World-pixel position of the guard's body, for sound placement. The guard
## stands on row 0's floor line — through the one world-to-screen mapping
## (session 011 step 2; the old code used the x scale for y, drawing him
## ~93 px below the floor line).
func _px() -> Vector2:
	return SimWorld.sim_units_to_px(
		float(guard_x), float(int(PopTables.Y_LAND[1])))


## Fight ticks stepped so far (0 while the duel sleeps) — tests read this to
## prove the duel ran on the 10 fps fight tick off the sim's events.
func fight_count() -> int:
	return _fights


# --- Rendering (placeholder procedural art, trim decision) -----------------

func _draw() -> void:
	if world == null:
		return
	# Foot point on row 0's floor line, via the one mapping (see _px).
	var at := _px()
	var x := at.x
	var y := at.y
	if int(guard.get("dead", 0)) != 0:
		draw_rect(Rect2(x - BODY_H * 0.5, y - BODY_W, BODY_H, BODY_W),
			Color(0.35, 0.12, 0.12))
		return
	draw_rect(Rect2(x - BODY_W * 0.5, y - BODY_H, BODY_W, BODY_H),
		Color(0.62, 0.18, 0.18))
	# facing cue: a short blade line on the side he faces (dir -1 = left)
	draw_line(Vector2(x, y - BODY_H * 0.55), Vector2(x - 18.0, y - BODY_H * 0.75),
		Color(0.85, 0.85, 0.9), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(x - 22.0, y - BODY_H - 6.0),
		"S%d hp%d" % [skill, int(guard.get("hp", 0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.9, 0.75, 0.75))
