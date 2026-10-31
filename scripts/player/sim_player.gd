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

## Session 011 (step 2): the placeholder prince is sized in SIM UNITS, not
## pixels, so the one world-to-screen mapping ([method SimWorld.sim_units_to_px],
## separate x/y scales — PARITY §2) decides what you see. The height is a
## documented fraction of the row: 50 of the 63 units in a row (0.79 — the
## reference prince fills most of a row; the exact sprite proportions arrive
## with A3.3 art, so this is placeholder presentation, NOT parity evidence).
## Width 10 units matches the sim's own kid x-footprint constants (the grab
## probe is −8 units, spike/edge nudges 8–10 — `seg006.c`), keeping the 1:2.2
## body proportion of the old 30x54 px placeholder at the corrected scales.
const PRINCE_W_UNITS: float = 10.0
const PRINCE_H_UNITS: float = 50.0

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
	# Foot position through the one mapping — x and y carry different scales
	# (the old code used the x scale for y, dropping the prince 2.3x too low).
	global_position = SimWorld.sim_units_to_px(
		world.clock.lerp_channel("x"), world.clock.lerp_channel("y"))
	queue_redraw()


## The prince's drawn rectangle in local pixels (origin = the sim's foot
## point, body upward) — exposed so the headless view tests can pin the
## size-as-a-fraction-of-a-row contract without entering the tree.
static func prince_rect_local() -> Rect2:
	return Rect2(
		-PRINCE_W_UNITS * SimWorld.PX_PER_UNIT * 0.5,
		-PRINCE_H_UNITS * SimWorld.PX_PER_UNIT_Y,
		PRINCE_W_UNITS * SimWorld.PX_PER_UNIT,
		PRINCE_H_UNITS * SimWorld.PX_PER_UNIT_Y)


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
## sized from sim extents (see the constants), with a facing cue and a
## frame-id caption, same read as pop_lab. Rect origin is the sim foot point.
func _draw() -> void:
	var body := prince_rect_local()
	draw_rect(body, Color(0.95, 0.85, 0.55))
	if world == null or world.clock == null or world.clock.curr.is_empty():
		return
	var dir := int(world.clock.curr.get("dir", 1))
	draw_rect(Rect2(float(dir) * body.size.x * 0.25 - 3.0, body.position.y + 8.0, 6.0, 6.0), Color(0.2, 0.16, 0.12))
	draw_string(ThemeDB.fallback_font, Vector2(-26.0, body.position.y - 6.0),
		"%s f%d" % [String(world.clock.curr.get("seq", "?")), int(world.clock.curr.get("frame", 0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.8, 0.8, 0.85))
