class_name SimEcho
extends TemporalEcho
## Plan B0 step 4 — the Temporal Echo on the sim path: a second sim
## participant (design note approved Session 009).
##
## Where the legacy echo replays transform snapshots, a SimEcho replays the
## recorded **input bytes** through [PopSim.step] — literally the kid's step
## function, started from a snapshot of the state at the moment recording
## began. The events it re-emits are the ones stamped into the take at
## record time (risk-3 fallback: stamped, not recomputed against the shared
## world), so the signal surface ([signal TemporalEcho.event_replayed] →
## [signal EventBus.echo_event_replayed]) is exactly what [code]lever.gd[/code],
## the HUD and the tests already consume.
##
## Approval condition (a): the echo writes only its OWN state dict — it is a
## sim participant, not a Godot node poking the world. Effects on the level's
## shared world are B1.3 and go through SimWorld.
##
## Ticking: [SimWorld] drives [method step_tick] once per world logic tick
## (lockstep via TemporalManager.step_sim_echoes), so the echo advances
## exactly when the world does. Rendering interpolates between the echo's
## prev/curr poses on the world clock's alpha. Final-pose hold: once the take
## runs out and [member TemporalEcho.loop] is false (the default), the echo
## sits on its last state until its lifetime expires.

## The take being replayed (PopReplay ring; immutable once recorded).
var take: PopReplay = null
## The state snapshot the take started from — the replay's start and loop point.
var start_state: Dictionary = {}
## The SimWorld whose clock drives this echo's interpolation. Typed as Node
## on purpose: this file must never class-reference SimWorld (TemporalManager
## sits between them), so access is dynamic and read-only.
var world: Node = null

## This participant's own sim state — a full second run, not the world's.
var state: Dictionary = {}

## _cursor is inherited from TemporalEcho: here it indexes the take (a tick
## number), where the legacy echo used it as a snapshot index.
var _prev_px := Vector2.ZERO
var _curr_px := Vector2.ZERO
## Pixels per sim unit, read from the world once at setup so the fallback
## path (world already gone) never has to class-reference SimWorld.
var _px_scale: float = 1.0


## Must be called before the node enters the tree (same contract as
## [method TemporalEcho.setup]).
func setup_sim(p_take: PopReplay, p_start_state: Dictionary, p_config: TemporalConfig, p_world: Node) -> void:
	take = p_take
	start_state = p_start_state
	world = p_world
	state = PopSim.dup_state(p_start_state)
	loop = p_config.loop_echo
	lifetime = p_config.echo_lifetime
	_duration = maxf(0.016, float(p_take.size()) / float(PopTables.TICK_HZ_TRAVERSE))
	_life_left = lifetime
	_time = 0.0
	_cursor = 0  # TemporalEcho's member — first tick of the take
	var probe: Vector2 = p_world.sim_to_px({"x": 100, "y": 100})
	_px_scale = probe.x / 100.0
	_prev_px = _px(state)
	_curr_px = _prev_px


func _ready() -> void:
	# Same Area2D contract as the legacy echo: invisible to level geometry,
	# visible to mechanisms and enemy detection (GameLayers.ECHO_BODY).
	collision_layer = GameLayers.ECHO_BODY
	collision_mask = 0
	monitoring = false   # The echo never asks what is around it...
	monitorable = true   # ...but the world is always allowed to notice it.
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = BODY_HALF_WIDTH
	capsule.height = BODY_HEIGHT + HEAD_RADIUS * 2.0
	shape.shape = capsule
	shape.position = Vector2(0, -BODY_HEIGHT * 0.5)
	add_child(shape)
	z_index = 5

	# Now that the echo is parented, global_position is meaningful.
	global_position = _curr_px
	queue_redraw()


## One logic tick — called by SimWorld.step_with() through
## TemporalManager.step_sim_echoes(), in lockstep with the world.
func step_tick() -> void:
	if _finished or take == null or take.size() == 0:
		return
	if _cursor >= take.size():
		if not loop:
			return  # final-pose hold (non-loop default, plan B1.2)
		_cursor = 0
		state = PopSim.dup_state(start_state)
		_prev_px = _px(state)
	state = PopSim.step(state, PopInput.from_byte(int(take.bytes[_cursor])))
	if _cursor < take.milestones.size():
		for m: Dictionary in take.milestones[_cursor]:
			var kind := String(m.get("kind", ""))
			var key := String(m.get("key", ""))
			# Custom stamped events (record_event) keep their raw id so lever
			# ids match; milestones carry "kind:key" as the surface always has.
			event_replayed.emit(self, StringName(key) if kind == "event" else "%s:%s" % [kind, key])
	_cursor += 1
	_prev_px = _curr_px
	_curr_px = _px(state)
	_facing = int(state.get("dir", 1))
	_state = StringName(state.get("seq", "stand"))
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_squared_to(_curr_px) > 4.0:
		_trail.append(_curr_px)
		while _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)
	queue_redraw()


## Ticks consumed so far (the echo's cursor through the take).
func cursor() -> int:
	return _cursor


func _process(_delta: float) -> void:
	# Interpolate with the world clock: the echo ticks lockstep with the
	# world, so its alpha is exactly the right fraction between prev/curr.
	if world != null and is_instance_valid(world):
		var clock := world.clock as SimClock
		if clock != null:
			global_position = _prev_px.lerp(_curr_px, clock.alpha)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	if lifetime > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			_expire()
			return
		# Dying echoes fade out over their final two seconds.
		_fade = clampf(_life_left / 2.0, 0.0, 1.0)


## Sim units -> world pixels, through the world while it is alive (the
## helper exists on SimWorld precisely so this file never class-references
## it); the cached scale covers a teardown race.
func _px(s: Dictionary) -> Vector2:
	if world != null and is_instance_valid(world):
		return world.sim_to_px(s)
	return Vector2(float(s.get("x", 0)) * _px_scale, float(s.get("y", 0)) * _px_scale)
