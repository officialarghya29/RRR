class_name SimWorld
extends Node2D
## Plan B0.1 (design note approved Session 009, conditions a-d) — the sim
## path's world root: the single writer of sim state.
##
## Owns the [SimClock], the [PopSim] state dict and the level entity bundle
## (tiles / mods / gates / plates / links / exit). Per logic tick: latch this
## frame's intent ([PopInputLatch]) -> packed input byte -> [PopSim.step] ->
## diff -> sim events on [EventBus] plus this node's own signals.
##
## Approval condition (a): Godot nodes only *read* sim snapshots and events.
## The only writer is [method _tick]/[method step_with]; views hold a
## reference to this node and interpolate [member clock] prev/curr, or read
## [member state] after a tick. Nothing outside this file mutates the state
## dict — the same determinism contract the tests enforce headlessly.

## --- World-to-screen (session 011 step 2; THE one mapping) -----------------
## The reference draws a 14-unit-wide tile as 32 screen px and a 63-unit-tall
## row as 63 px (`types.h:1405`, `types.h:1408`; PARITY §2 "Unit scale") —
## x and y carry DIFFERENT scales by design, which is why the old isotropic
## ×3 mapping rendered 42×189 px cells (4.5:1) instead of the original's
## ~2:1. Rendering keeps the x look (14 u → 42 px) and derives y from the
## cited 1:1 unit ratio at the same zoom: 1 u → 3·14/32 = 1.3125 px, so a
## cell draws 42 × 82.69 px (1.97:1 — measured ≈2:1 by the user from the
## original). VIEW PRESENTATION ONLY: no sim quantity changes.
##
## Level-data px (spawn, checkpoint pos_px) remain in the legacy isotropic
## 3 px/u input space, converted in [method _fresh_state] — that is an input
## convention, not this render mapping.
## World pixels per sim unit, horizontally (14-unit tile -> 42 px).
const PX_PER_UNIT: float = 3.0
## World pixels per sim unit, vertically (cited 32:63 display ratio).
const PX_PER_UNIT_Y: float = PX_PER_UNIT * 14.0 / 32.0   # = 1.3125

## Sim units -> world pixels (the render mapping; every call site uses it).
static func sim_units_to_px(x: float, y: float) -> Vector2:
	return Vector2(x * PX_PER_UNIT, y * PX_PER_UNIT_Y)

## Emitted after every logic tick with the post-step state (read-only view).
signal sim_tick(state: Dictionary)
## Session 010 (plan §4.7): per-logic-tick feed for Godot-side duel
## participants on the sim path — the post-step state (read-only snapshot)
## plus this tick's packed input byte (the player's intent). The first
## consumer is [SimGuard]; what crosses the boundary is documented there.
signal logic_tick(state: Dictionary, input_byte: int)
## A checkpoint trigger fired this tick: id plus its world-pixel position.
signal checkpoint_hit(id: StringName, pos_px: Vector2)
## The kid reached the (open) level-exit door tile.
signal exit_reached
## Session 012 step 3: the world came back at a checkpoint/spawn — every
## Godot-side participant that MIRRORS the kid's life re-arms its mirror
## (SimGuard's duel-side kid abstraction; the guard's own state persists).
signal respawned(pos_px: Vector2)

var clock: SimClock
var state: Dictionary = {}
## The level bundle this world runs: {tiles, mods, entities} (PopSim shape).
var bundle: Dictionary = {}
var spawn_px: Vector2 = Vector2.ZERO
## [{ "id": StringName, "pos_px": Vector2 }] — position triggers that read the
## sim x/y each tick (design note: checkpoints stay Godot-side triggers).
var checkpoints: Array = []
var running: bool = false

var _latch := PopInputLatch.new()
var _seed: int = 0
var _fired: Dictionary = {}
var _was_dead: int = 0
var _last_hp: int = -1


## Build the world from a catalog level: fresh state at the spawn, a fresh
## clock, checkpoint bookkeeping cleared.
func setup(p_bundle: Dictionary, seed_n: int, p_spawn_px: Vector2, p_checkpoints: Array = []) -> void:
	bundle = p_bundle
	spawn_px = p_spawn_px
	checkpoints = p_checkpoints
	_seed = seed_n
	_fired = {}
	_was_dead = 0
	_last_hp = -1
	state = _fresh_state()
	clock = SimClock.new(state)
	running = true
	# Plan B0 step 4: register with the echo authority so a take can snapshot
	# this world's state (it only ever *reads* — condition (a) holds).
	TemporalManager.register_sim_world(self)


func _fresh_state() -> Dictionary:
	var s: Dictionary = PopSim.initial_state(
		_seed, bundle.get("tiles", []), bundle.get("mods", {}), bundle.get("entities", {}))
	s["x"] = int(round(spawn_px.x / PX_PER_UNIT))
	s["y"] = int(round(spawn_px.y / PX_PER_UNIT))
	return s


func _process(delta: float) -> void:
	if not running:
		return
	# Plan B0 step 4: the record toggle lives with the input latch on the sim
	# path (the physics Player's _toggle_recording has no node here).
	if Input.is_action_just_pressed(&"temporal_record"):
		if TemporalManager.recorder.is_recording:
			TemporalManager.stop_recording()
		else:
			TemporalManager.start_recording()
	var due := clock.advance(delta)
	for _i: int in range(due):
		_tick()
	if due > 0:
		sim_tick.emit(clock.curr)


## One logic tick from live input: sample the render-rate action state into
## the latch, consume it as the tick's byte, step, publish.
func _tick() -> void:
	_latch.sample_actions()
	step_with(_latch.take())


## Step one tick with an explicit input (live path passes the latch's byte;
## tests and the completability smoke pass scripted bytes — same function).
func step_with(input: PopInput) -> void:
	# Echoes step first in lockstep, then their stances press this world's
	# plates BEFORE the entity stage runs — so an echo press goes through the
	# same trigger-then-animate flow as the kid's own press (plan B1.3,
	# session 010) and lands in the same tick's diff for the puzzle stream
	# and the echo recorder. The prev snapshot must predate the echo press.
	var prev_view: Dictionary = PopReplay._entity_view(state)
	var prev_seq := String(state.get("seq", ""))
	TemporalManager.step_sim_echoes()
	_apply_echo_presses()
	state = PopSim.step(state, input)
	clock.push(state)
	_publish(prev_view)
	_publish_sounds(prev_seq)
	# Plan B0 step 4: while a take is recording, stamp this tick's byte and
	# its event vector into the echo recorder (the PopReplay ring) — one
	# branch per tick, and only the recording path pays for the string diff.
	if TemporalManager.is_sim_recording():
		TemporalManager.record_sim_tick(
			input.to_byte(),
			PopReplay.entity_events(prev_view, state),
			PopReplay.milestones_for(prev_view, state))
	# Session 010: the per-tick feed for Godot-side duel participants (the
	# guard steps AFTER publication, so a damage request applied here joins
	# the NEXT tick's diff — one tick of latency, documented in SimGuard).
	logic_tick.emit(state, input.to_byte())


## Plan B1.3 (session 010): an echo's stance presses this world's plates —
## the first mechanism the shared world gains from a sim participant. The
## echo contributes POSITION ONLY (its own state dict, read here read-only);
## the press itself runs through PopLevel's own trigger path, and this node
## remains the single writer of the state dict (approval condition a).
## Reference basis: a body standing on a raise plate re-triggers its gate
## every held tick (`seg007.c:764`), so a memory left standing on a plate
## holds the linked gate open — the level-2 "cooperate with your past self"
## thesis rides on this.
func _apply_echo_presses() -> void:
	for echo: TemporalEcho in TemporalManager.active_sim_echoes():
		var es: Dictionary = (echo as SimEcho).state
		if es.is_empty() or int(es.get("dead", 0)) != 0:
			continue
		var erow := int(es.get("row", -1))
		if erow < 0:
			continue
		var ecol := PopSim._col_of(PopSim._foot_x(es))
		# The tile is read from the WORLD's grid (the echo's own copy of the
		# level belongs to its private run), and the press mutates the world.
		PopLevel.press_plates_for(state, erow, ecol, PopSim._tile(state, erow, ecol))


## Synchronous helper for headless tests and the scripted smoke run: step
## [param n] ticks from a fixed byte script (holds the script's last byte once
## it runs out, so "hold right" is one byte repeated; empty = neutral).
func step_ticks(n: int, script: Array = []) -> void:
	for i: int in range(n):
		var packed: int = PopInput.neutral().to_byte()
		if not script.is_empty():
			packed = int(script[mini(i, script.size() - 1)])
		step_with(PopInput.from_byte(packed))


## Respawn at a world-pixel position (checkpoint or level spawn): fresh state,
## fresh clock — same hard-reset semantics GameManager expects from
## [method Player.respawn].
func respawn_at(pos_px: Vector2) -> void:
	spawn_px = pos_px
	state = _fresh_state()
	clock = SimClock.new(state)
	_fired = {}
	_was_dead = 0
	_last_hp = int(state["hp"])
	sim_tick.emit(clock.curr)
	respawned.emit(pos_px)


## Interface parity with the physics [Player]: GameManager's fall-out-of-bounds
## guard calls kill(). The sim kills itself on a fall-out (PopSim._fell_out);
## this exists so the duck-typed contract holds on both paths.
func force_death() -> void:
	if int(state.get("dead", 0)) != 0:
		return
	state["dead"] = 1
	state["hp"] = 0
	EventBus.player_died.emit()
	sim_tick.emit(state)


## Session 010: a Godot-side duel participant REQUESTS damage; this node
## applies it to the sim state — the only writer stays here (approval
## condition a). The request lands after this tick's publication, so the
## health/death events surface on the next tick's diff (documented in
## SimGuard). The death presentation reuses the crushed marker (hard_land,
## f185) — the sim kid has no sword frames (model split, characterization).
func apply_duel_hit(amount: int) -> void:
	if amount <= 0 or int(state.get("dead", 0)) != 0:
		return
	var hp := int(state.get("hp", 0)) - amount
	if hp <= 0:
		state["hp"] = 0
		state["dead"] = 1
		state["seq"] = "hard_land"
		state["op"] = 0
		state["frame"] = 185
	else:
		state["hp"] = hp
	sim_tick.emit(state)


## World-pixel position of the sim state (post-tick, un-interpolated).
func pos_px() -> Vector2:
	return sim_units_to_px(float(state.get("x", 0)), float(state.get("y", 0)))


## Seed this world runs under — stamped into the echo recorder's take so a
## recording carries everything needed to reproduce its run (plan B0 step 4).
func take_seed() -> int:
	return _seed


## Sim units -> world pixels for an arbitrary state: the echo renders its own
## participant state through this (read-only helper, plan B0 step 4).
func sim_to_px(s: Dictionary) -> Vector2:
	return sim_units_to_px(float(s.get("x", 0)), float(s.get("y", 0)))


# --- Event publication (diffs, never guesses) -------------------------------

func _publish(prev_view: Dictionary) -> void:
	# Death first, then health on change only — the same event discipline the
	# physics Player's Health component follows, so the HUD sees neither a
	# per-tick stream nor a zeroed hp before the death event.
	var dead := int(state["dead"])
	if dead != 0 and _was_dead == 0:
		EventBus.player_died.emit()
	_was_dead = dead
	var hp := int(state["hp"])
	if hp != _last_hp:
		_last_hp = hp
		EventBus.health_changed.emit(hp, PopTables.KID_HP_START)
	EventBus.player_moved.emit(
		float(state["x"]), float(state["y"]), int(state["row"]), int(state["dir"]))
	_publish_entity_events(prev_view)
	_check_triggers()


## Plan B0.1 step 3: plate presses and gate transitions leave the sim as
## events for the puzzle framework's consumers. The milestones come from
## PopReplay.milestones_for — the same rules the echo recorder stamps into
## its event vectors — so a level's puzzle timeline and its recorded vectors
## cannot diverge. Session 010 step 4: the same milestones also emit named
## SoundEvents (plate / gate open / gate close / death) — the audio hook
## points sit on the diffs the sim already publishes, never inside the sim.
func _publish_entity_events(prev_view: Dictionary) -> void:
	for milestone: Dictionary in PopReplay.milestones_for(prev_view, state):
		var kind := StringName(String(milestone["kind"]))
		var key := String(milestone["key"])
		EventBus.sim_entity_event.emit(kind, key)
		match kind:
			&"press":
				SoundEvents.emit_sfx(&"plate", _key_px(key))
			&"open":
				SoundEvents.emit_sfx(&"gate_open", _key_px(key))
			&"closed", &"fastclose":
				SoundEvents.emit_sfx(&"gate_close", _key_px(key))
			&"dead":
				SoundEvents.emit_sfx(&"death")


## World-pixel position of an entity key ("row,col") for sound placement.
func _key_px(key: String) -> Vector2:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(
		float(58 + PopTables.TILE_W * int(parts[1]) + 7) * PX_PER_UNIT,
		float(int(PopTables.Y_LAND[int(parts[0]) + 1])) * PX_PER_UNIT_Y)


## Session 010 step 4: landing and trap sounds from the sequence transition
## the sim already performs — soft / medium / hard land windows and the
## spike impale (PARITY §7/§8; seq names are PopSim's own). Death itself
## rides the "dead" milestone above.
func _publish_sounds(prev_seq: String) -> void:
	var seq := String(state.get("seq", ""))
	if seq == prev_seq:
		return
	match seq:
		"soft_land":
			SoundEvents.emit_sfx(&"land_soft", pos_px())
		"med_land":
			SoundEvents.emit_sfx(&"land_medium", pos_px())
		"hard_land":
			SoundEvents.emit_sfx(&"land_hard", pos_px())
		"impale":
			SoundEvents.emit_sfx(&"spike", pos_px())


## Position triggers read the sim x/y (design note: checkpoints stay
## Godot-side, fed by sim coordinates). Fires once per trigger per life;
## respawn re-arms them.
func _check_triggers() -> void:
	if int(state["dead"]) != 0:
		return
	var kid_x := int(state["x"])
	for cp: Dictionary in checkpoints:
		var id := StringName(String(cp["id"]))
		if _fired.has(id):
			continue
		if absi(kid_x - int(cp["x_sim"])) <= int(cp.get("radius", 8)):
			_fired[id] = true
			checkpoint_hit.emit(id, cp["pos_px"] as Vector2)
	# Level-exit door: the reference level ends when the kid walks into the
	# open door tile (door modifier > 0 = not shut).
	var exit_door: Dictionary = state.get("exit", {})
	if not exit_door.is_empty() and not _fired.has(&"__exit"):
		if int(exit_door.get("mod", 0)) > 0 \
				and int(state["row"]) == int(exit_door["row"]) \
				and PopSim._col_of(PopSim._foot_x(state)) == int(exit_door["col"]):
			_fired[&"__exit"] = true
			exit_reached.emit()
