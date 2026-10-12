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

## World pixels per sim unit (14-unit tile -> 42 px; PARITY §2 unit scale).
## Same scale pop_lab's PopView renders at.
const PX_PER_UNIT: float = 3.0

## Emitted after every logic tick with the post-step state (read-only view).
signal sim_tick(state: Dictionary)
## A checkpoint trigger fired this tick: id plus its world-pixel position.
signal checkpoint_hit(id: StringName, pos_px: Vector2)
## The kid reached the (open) level-exit door tile.
signal exit_reached

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
	TemporalManager.step_sim_echoes()
	_apply_echo_presses()
	state = PopSim.step(state, input)
	clock.push(state)
	_publish(prev_view)
	# Plan B0 step 4: while a take is recording, stamp this tick's byte and
	# its event vector into the echo recorder (the PopReplay ring) — one
	# branch per tick, and only the recording path pays for the string diff.
	if TemporalManager.is_sim_recording():
		TemporalManager.record_sim_tick(
			input.to_byte(),
			PopReplay.entity_events(prev_view, state),
			PopReplay.milestones_for(prev_view, state))


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


## World-pixel position of the sim state (post-tick, un-interpolated).
func pos_px() -> Vector2:
	return Vector2(float(state.get("x", 0)) * PX_PER_UNIT, float(state.get("y", 0)) * PX_PER_UNIT)


## Seed this world runs under — stamped into the echo recorder's take so a
## recording carries everything needed to reproduce its run (plan B0 step 4).
func take_seed() -> int:
	return _seed


## Sim units -> world pixels for an arbitrary state: the echo renders its own
## participant state through this (read-only helper, plan B0 step 4).
func sim_to_px(s: Dictionary) -> Vector2:
	return Vector2(float(s.get("x", 0)) * PX_PER_UNIT, float(s.get("y", 0)) * PX_PER_UNIT)


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
## cannot diverge.
func _publish_entity_events(prev_view: Dictionary) -> void:
	for milestone: Dictionary in PopReplay.milestones_for(prev_view, state):
		EventBus.sim_entity_event.emit(StringName(String(milestone["kind"])), String(milestone["key"]))


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
