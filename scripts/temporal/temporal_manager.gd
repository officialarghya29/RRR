extends Node
## Autoload [code]TemporalManager[/code] — the single authority on time.
##
## Flow it implements (matching the directive):
## [codeblock]
## start_recording -> capture snapshots -> stop -> create echo -> replay
##                 -> echo interacts with world -> echo expires
## [/codeblock]
##
## It is the only thing that ticks the recorder, so a recording can never be
## advanced by two systems at once. Levels never touch the recorder directly;
## they call the small public API here.

## The active rule set. Levels may swap in a tuned or advanced variant.
var config: TemporalConfig
## Current temporal energy, in [code]0..config.energy_max[/code].
var energy: float = 0.0
## The stock rule set. Never mutated, so a level that requests no overrides gets
## exactly the default rules back rather than whatever the last level changed.
var _base_config: TemporalConfig
## The recorder for the take in progress (never null; check [member TemporalRecorder.is_recording]).
var recorder: TemporalRecorder

## The node whose transforms are recorded. Must implement
## [code]capture_temporal_state() -> Dictionary[/code].
var _source: Node = null
## Plan B0 step 4 — sim-path take (the bytes variant of the recorder):
## the SimWorld a take records against (reads only — it is the sole writer
## of *its* state; we snapshot from it, never into it), the PopReplay ring
## holding the take's bytes + event vectors + milestones, and the state
## snapshot taken when recording began (the echo's replay start point).
## [member _sim_take] non-null is what marks a take as sim-path.
var _sim_world: Node = null
var _sim_take: PopReplay = null
var _sim_start_state: Dictionary = {}
## Events stamped via [method record_event] since the last recorded tick —
## folded into the next tick's milestone list (interact presses, plan B1.1's
## "event attachment").
var _sim_pending_events: Array[String] = []
var _sim_ticks: int = 0
## Where spawned echoes are parented (the current level root).
var _echo_container: Node = null
var _active_echoes: Array[TemporalEcho] = []
var _last_energy_signal: float = -1.0


func _ready() -> void:
	_base_config = TemporalConfig.new()
	config = _base_config.duplicate(true) as TemporalConfig
	recorder = TemporalRecorder.new(config)
	energy = config.energy_max
	EventBus.temporal_energy_changed.emit(energy, config.energy_max)
	_last_energy_signal = energy


## Applies per-level rule overrides on top of the stock configuration.
##
## This is how a level opts into the directive's "later upgrade" tier — a longer
## recording window and two simultaneous echoes — without any other level being
## affected. Unknown keys are reported rather than silently ignored, because a
## typo here would look exactly like a gameplay bug.
func configure_for_level(overrides: Dictionary) -> void:
	cancel_recording("reconfigured")
	config = _base_config.duplicate(true) as TemporalConfig

	if not overrides.is_empty():
		var valid: Dictionary = {}
		for property: Dictionary in config.get_property_list():
			valid[String(property["name"])] = true
		for key: String in overrides:
			if not valid.has(key):
				push_error("TemporalManager: unknown temporal rule override '%s'." % key)
				continue
			config.set(key, overrides[key])

	recorder = TemporalRecorder.new(config)
	energy = config.energy_max
	_last_energy_signal = -1.0
	_emit_energy(true)


func _physics_process(delta: float) -> void:
	_tick_recording(delta)
	_tick_energy(delta)


# --- Wiring -----------------------------------------------------------------

## Binds the recording target. Called by the player when it enters the tree.
func register_source(node: Node) -> void:
	if node != null and not node.has_method("capture_temporal_state"):
		push_error("TemporalManager.register_source: node '%s' lacks capture_temporal_state()." % node)
		return
	_source = node


## Binds where echoes live. Called by the level when it is built.
func set_echo_container(node: Node) -> void:
	_echo_container = node


func clear_source() -> void:
	_source = null


# --- Sim-path wiring (plan B0 step 4) ---------------------------------------

## Binds the sim world a take records against. The world calls this from its
## setup(); passing null (test teardown / path switch) drops the binding.
## A take never survives a world swap.
func register_sim_world(world: Node) -> void:
	if world != _sim_world and recorder.is_recording and _sim_take != null:
		cancel_recording("world_swapped")
	_sim_world = world


## True while a sim-path take is recording (a branch-free probe for
## SimWorld.step_with, so idle ticks cost one call).
func is_sim_recording() -> bool:
	return recorder.is_recording and _sim_take != null


## Bytes recorded so far in the active take (−1 when none) — tests read the
## ring cap from here.
func sim_take_size() -> int:
	return _sim_take.size() if _sim_take != null else -1


## Recording mode: a bound sim world wins — the same window in which the
## physics Player would be the snapshot source on the legacy path.
func _is_sim_mode() -> bool:
	return is_instance_valid(_sim_world)


# --- Energy -----------------------------------------------------------------

func energy_ratio() -> float:
	if config.energy_max <= 0.0:
		return 0.0
	return clampf(energy / config.energy_max, 0.0, 1.0)


func reset_energy() -> void:
	energy = config.energy_max
	_emit_energy(true)


func _tick_energy(delta: float) -> void:
	if config.energy_regen_per_second <= 0.0:
		return
	var before := energy
	energy = minf(config.energy_max, energy + config.energy_regen_per_second * delta)
	if not is_equal_approx(before, energy):
		_emit_energy(is_equal_approx(energy, config.energy_max))


func _emit_energy(force: bool) -> void:
	if force or absf(energy - _last_energy_signal) >= 0.02:
		_last_energy_signal = energy
		EventBus.temporal_energy_changed.emit(energy, config.energy_max)


# --- Recording --------------------------------------------------------------

## True when a new take may begin. Checks both the state and the energy cost.
func can_start_recording() -> bool:
	if recorder.is_recording:
		return false
	if not _is_sim_mode() and not is_instance_valid(_source):
		return false
	return energy + 0.0001 >= config.energy_cost_per_echo


## Begins a take. Returns [code]false[/code] (with a signal) if it is not allowed.
func start_recording() -> bool:
	if not can_start_recording():
		return false
	recorder.start()
	if _is_sim_mode():
		_begin_sim_take()
	EventBus.recording_started.emit(config.max_recording_duration)
	EventBus.recording_progress.emit(0.0, config.max_recording_duration)
	return true


## Plan B0 step 4: stamp the world's current state as the take's replay
## start — the echo replays bytes from *here*, not from the level spawn, so
## a take started mid-level reproduces the path actually recorded.
func _begin_sim_take() -> void:
	_sim_take = PopReplay.new()
	_sim_take.seed = _sim_world.take_seed()          # dynamic (typed Node)
	_sim_start_state = PopSim.dup_state(_sim_world.state)
	_sim_pending_events.clear()
	_sim_ticks = 0


## Player-initiated end of a take. Produces an echo if the take is usable.
func stop_recording() -> void:
	if not recorder.is_recording:
		return
	recorder.stop()
	_finalize_recording()


## Abandons a take without producing an echo.
func cancel_recording(reason: String = "cancelled") -> void:
	_sim_take = null
	_sim_start_state = {}
	_sim_pending_events.clear()
	if not recorder.is_recording:
		return
	recorder.cancel()
	EventBus.recording_cancelled.emit(reason)


## Records a gameplay event on the current frame so the echo can reproduce it.
## Silently ignored when not recording, which keeps call sites branch-free.
## On the sim path the id rides the next recorded tick's milestone list —
## same stamped-event semantics, different container.
func record_event(event_id: StringName) -> void:
	if recorder.is_recording and _sim_take != null:
		_sim_pending_events.append(String(event_id))
		return
	if recorder.is_recording:
		recorder.add_event(event_id)


func _tick_recording(delta: float) -> void:
	if not recorder.is_recording:
		return
	if _sim_take != null:
		# Sim takes are driven by SimWorld's logic ticks (record_sim_tick),
		# never by the render loop — but a freed world must not leave the
		# recorder stuck on.
		if not is_instance_valid(_sim_world):
			cancel_recording("source_lost")
		return
	if not is_instance_valid(_source):
		cancel_recording("source_lost")
		return

	var payload: Dictionary = _source.capture_temporal_state()
	var still_recording: bool = recorder.record(
		delta,
		payload.get("position", Vector2.ZERO),
		payload.get("rotation", 0.0),
		payload.get("velocity", Vector2.ZERO),
		payload.get("state", &"idle"),
		payload.get("facing", 1)
	)
	EventBus.recording_progress.emit(recorder.duration(), config.max_recording_duration)

	if not still_recording:
		# Either the player stopped us or the duration cap fired.
		_finalize_recording()


func _finalize_recording() -> void:
	if _sim_take != null:
		_finalize_sim_take()
		return
	if not recorder.has_usable_data():
		recorder.cancel()
		EventBus.recording_cancelled.emit("too_short")
		return

	var produced: TemporalEcho = spawn_echo(recorder.get_snapshots())
	if produced == null:
		recorder.cancel()
		EventBus.recording_cancelled.emit("echo_failed")
		return

	energy = maxf(0.0, energy - config.energy_cost_per_echo)
	_emit_energy(true)
	recorder.cancel()


## Plan B0 step 4: end a sim-path take — same usability rules as the legacy
## recorder (min duration + at least 2 ticks), same energy charge, same
## cancellation signals; the payload is a PopReplay ring instead of snapshots.
func _finalize_sim_take() -> void:
	var take := _sim_take
	var start_state := _sim_start_state
	_sim_take = null
	_sim_start_state = {}
	_sim_pending_events.clear()
	var seconds := float(take.size()) / float(PopTables.TICK_HZ_TRAVERSE)
	if take.size() < 2 or seconds < config.min_recording_duration:
		recorder.cancel()
		EventBus.recording_cancelled.emit("too_short")
		return
	var produced: TemporalEcho = spawn_sim_echo(take, start_state)
	if produced == null:
		recorder.cancel()
		EventBus.recording_cancelled.emit("echo_failed")
		return
	energy = maxf(0.0, energy - config.energy_cost_per_echo)
	_emit_energy(true)
	recorder.cancel()


## Called by SimWorld.step_with once per logic tick while a take records:
## stamp the tick's byte + event vector + structured milestones into the
## bounded ring, then enforce the caps — duration budget and ring capacity
## both hard-stop the take exactly like the legacy recorder's duration cap.
func record_sim_tick(byte_val: int, event_vec: String, milestones: Array) -> void:
	if not is_sim_recording():
		return
	var stamped: Array = milestones.duplicate()
	for ev: String in _sim_pending_events:
		stamped.append({"kind": "event", "key": ev})
	_sim_pending_events.clear()
	_sim_take.push_tick(byte_val, event_vec, stamped)
	_sim_ticks += 1
	EventBus.recording_progress.emit(
		float(_sim_ticks) / float(PopTables.TICK_HZ_TRAVERSE),
		config.max_recording_duration)
	var cap_ticks := int(config.max_recording_duration * float(PopTables.TICK_HZ_TRAVERSE))
	if _sim_take.at_capacity() or _sim_ticks >= cap_ticks:
		stop_recording()


# --- Echoes -----------------------------------------------------------------

## Instantiates an echo from a snapshot array and registers it for lifecycle
## management. Charges no energy — [method _finalize_recording] owns that.
func spawn_echo(snapshots: Array[TemporalSnapshot]) -> TemporalEcho:
	if snapshots.size() < 2:
		push_warning("TemporalManager.spawn_echo: need at least 2 snapshots.")
		return null
	if _echo_container == null or not is_instance_valid(_echo_container):
		push_error("TemporalManager.spawn_echo: no echo container set. Call set_echo_container() when building the level.")
		return null

	while _active_echoes.size() >= config.max_active_echoes and not _active_echoes.is_empty():
		_retire_echo(_active_echoes[0], "replaced")

	var echo := TemporalEcho.new()
	echo.setup(snapshots, config)
	echo.playback_finished.connect(_on_echo_finished)
	echo.event_replayed.connect(_on_echo_event)
	_echo_container.add_child(echo)
	_active_echoes.append(echo)

	EventBus.echo_created.emit(echo, snapshots[-1].time)
	return echo


## Plan B0 step 4 — the bytes variant of spawn_echo: a second sim participant
## that replays [param take] through PopSim.step from [param start_state],
## spawned from the *release* moment (the take's start state is where
## recording began). Same energy/capacity rules, same signal surface — the
## legacy snapshot path above is untouched for --legacy-physics.
func spawn_sim_echo(take: PopReplay, start_state: Dictionary) -> TemporalEcho:
	if take == null or take.size() < 2:
		push_warning("TemporalManager.spawn_sim_echo: need at least 2 recorded ticks.")
		return null
	if _echo_container == null or not is_instance_valid(_echo_container):
		push_error("TemporalManager.spawn_sim_echo: no echo container set. Call set_echo_container() when building the level.")
		return null

	while _active_echoes.size() >= config.max_active_echoes and not _active_echoes.is_empty():
		_retire_echo(_active_echoes[0], "replaced")

	var echo := SimEcho.new()
	echo.setup_sim(take, start_state, config, _sim_world)
	echo.playback_finished.connect(_on_echo_finished)
	echo.event_replayed.connect(_on_echo_event)
	_echo_container.add_child(echo)
	_active_echoes.append(echo)

	EventBus.echo_created.emit(echo, float(take.size()) / float(PopTables.TICK_HZ_TRAVERSE))
	return echo


## SimWorld.step_with drives every sim participant one logic tick per world
## tick (lockstep), so an echo advances exactly when the world does — no
## second clock, no drift. Legacy snapshot echoes are not in this loop: they
## tick themselves off physics frames, as before.
func step_sim_echoes() -> void:
	if _active_echoes.is_empty():
		return
	for echo: TemporalEcho in _active_echoes:
		if echo is SimEcho and is_instance_valid(echo):
			(echo as SimEcho).step_tick()


func _retire_echo(echo: TemporalEcho, _reason: String) -> void:
	if not is_instance_valid(echo):
		_active_echoes.erase(echo)
		return
	_active_echoes.erase(echo)
	EventBus.echo_expired.emit(echo)
	if is_instance_valid(echo):
		echo.queue_free()


func _on_echo_finished(echo: TemporalEcho) -> void:
	_active_echoes.erase(echo)
	EventBus.echo_expired.emit(echo)


func _on_echo_event(echo: TemporalEcho, event_id: StringName) -> void:
	EventBus.echo_event_replayed.emit(echo, event_id)


## Removes every echo. Called on level restart so a replay cannot leak across
## a reset and desynchronise the puzzle state.
func clear_echoes() -> void:
	for echo: TemporalEcho in _active_echoes.duplicate():
		if is_instance_valid(echo):
			echo.queue_free()
	_active_echoes.clear()


func echo_count() -> int:
	return _active_echoes.size()


## Session 010 (plan B1.3): the sim-path echoes currently alive, so SimWorld
## can read their stances (read-only — the world stays the only writer of its
## state) and let an echo standing on a plate press it. Legacy snapshot
## echoes are not sim participants and are not returned.
func active_sim_echoes() -> Array:
	var out: Array = []
	for echo: TemporalEcho in _active_echoes:
		if echo is SimEcho and is_instance_valid(echo):
			out.append(echo)
	return out


func has_active_echo() -> bool:
	return not _active_echoes.is_empty()
