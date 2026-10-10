class_name SimPlayer
extends Node2D
## Plan B0.1 — the player on the sim path: a thin view node (approval
## condition a: reads snapshots and events, never writes sim state).
##
## Renders the interpolated [SimClock] prev/curr position (the same
## lerp pop_lab already uses), carries the camera, and translates the few
## GameManager calls (kill / respawn / set_camera_limits) into SimWorld
## operations. Input never reaches this node: SimWorld latches the action
## state itself each logic tick.

const BODY_W: float = 30.0
const BODY_H: float = 54.0

var world: SimWorld
var camera: Camera2D


func _init(p_world: SimWorld) -> void:
	world = p_world


func _ready() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	EventBus.player_spawned.emit(self)
	EventBus.health_changed.emit(int(world.state["hp"]), PopTables.KID_HP_START)


func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.clock == null:
		return
	global_position = Vector2(
		world.clock.lerp_channel("x") * SimWorld.PX_PER_UNIT,
		world.clock.lerp_channel("y") * SimWorld.PX_PER_UNIT)
	queue_redraw()


## Duck-typed contract shared with the physics Player, consumed by
## GameManager: fall-out kill, checkpoint respawn, camera limits.
func kill() -> void:
	world.force_death()


func respawn(pos: Vector2) -> void:
	world.respawn_at(pos)
	EventBus.health_changed.emit(int(world.state["hp"]), PopTables.KID_HP_START)
	EventBus.player_spawned.emit(self)


func set_camera_limits(limits: Rect2) -> void:
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.end.x)
	camera.limit_bottom = int(limits.end.y)


## Placeholder prince (A3.3 art stays procedural for the slice): a body block
## with a facing cue and a frame-id caption, same read as pop_lab.
func _draw() -> void:
	draw_rect(Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H), Color(0.95, 0.85, 0.55))
	if world == null or world.clock == null or world.clock.curr.is_empty():
		return
	var dir := int(world.clock.curr.get("dir", 1))
	draw_rect(Rect2(float(dir) * BODY_W * 0.25 - 3.0, -BODY_H + 8.0, 6.0, 6.0), Color(0.2, 0.16, 0.12))
	draw_string(ThemeDB.fallback_font, Vector2(-26.0, -BODY_H - 6.0),
		"%s f%d" % [String(world.clock.curr.get("seq", "?")), int(world.clock.curr.get("frame", 0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.8, 0.8, 0.85))
