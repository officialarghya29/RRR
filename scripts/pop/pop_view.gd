class_name PopView
extends Node2D
## Plan A3.2 — placeholder procedural renderer for the pop sim. No sprites yet
## (that is A3.3): the level is drawn as rectangles scaled from internal units,
## and the prince is a rectangle whose position is interpolated between the
## [SimClock]'s prev/curr states. The animation frame is snapped to the sim
## frame — deliberately *not* interpolated.
##
## Run the sandbox with:
## [codeblock]
## ./.tools/godot --path . res://scenes/pop/pop_lab.tscn
## [/codeblock]
## Controls: A/D run, W jump-up, S crouch, Shift grab/climb, P pause,
## `.` frame-step one sim tick while paused.

const PX_PER_UNIT: float = 3.0  ## 14-unit tile → 42 px; 63-unit row → 189 px
const BODY_W: float = 30.0
const BODY_H: float = 54.0
const PAUSE_KEY: int = KEY_P
const STEP_KEY: int = KEY_PERIOD  ## '.' — frame-step while paused

const _DEFAULT_TILE_COLOR := Color(0.55, 0.48, 0.60)
const _PRINCE_COLOR := Color(0.95, 0.85, 0.55)
const _COLORS := {
	PopTables.Tile.FLOOR: Color(0.42, 0.36, 0.28),
	PopTables.Tile.WALL: Color(0.30, 0.30, 0.34),
	PopTables.Tile.SPIKES: Color(0.72, 0.20, 0.20),
	PopTables.Tile.EXIT_DOOR_LEFT: Color(0.20, 0.55, 0.75),
	PopTables.Tile.EXIT_DOOR_RIGHT: Color(0.20, 0.55, 0.75),
}

var clock: SimClock
var state: Dictionary
var level: Array
var latch := PopInputLatch.new()
var paused := false


## The plan A3.2 sandbox: a flat floor with a pit to jump, and a raised ledge
## (row 1, cols 8–11) to hang from and climb. 3 rows × 12 columns of
## `PopTables.Tile` ids.
static func sandbox_level() -> Array:
	const F := PopTables.Tile.FLOOR
	const E := PopTables.Tile.EMPTY
	return [
		[F, F, F, F, E, F, F, F, E, E, E, E],  # pit at col 4; floor ends at col 7
		[E, E, E, E, E, E, E, E, F, F, F, F],  # raised ledge, cols 8–11
		[E, E, E, E, E, E, E, E, E, E, E, E],
	]


func _ready() -> void:
	InputActions.ensure_defaults()
	level = sandbox_level()
	state = PopSim.initial_state(1, level)
	clock = SimClock.new(state)
	set_process(true)


func _process(delta: float) -> void:
	if paused:
		return
	var due := clock.advance(delta)
	for _i: int in range(due):
		_tick()
	if due > 0:
		queue_redraw()


## One sim tick: latch this frame's intent, step, and record the new state.
func _tick() -> void:
	latch.sample_actions()
	clock.push(PopSim.step(clock.curr, latch.take()))


## Advance exactly one tick regardless of the render clock (frame-step).
func frame_step() -> void:
	_tick()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key == PAUSE_KEY:
		paused = not paused
		queue_redraw()
	elif key == STEP_KEY and paused:
		frame_step()


func _draw() -> void:
	for row: int in range(level.size()):
		var cells: Array = level[row]
		for col: int in range(cells.size()):
			var tile := int(cells[col])
			if tile == PopTables.Tile.EMPTY:
				continue
			draw_rect(Rect2(
				float(col * PopTables.TILE_W) * PX_PER_UNIT,
				float(row * PopTables.TILE_H) * PX_PER_UNIT,
				float(PopTables.TILE_W) * PX_PER_UNIT,
				float(PopTables.TILE_H) * PX_PER_UNIT),
				_COLORS.get(tile, _DEFAULT_TILE_COLOR))
	var px := clock.lerp_channel("x") * PX_PER_UNIT
	var py := clock.lerp_channel("y") * PX_PER_UNIT
	draw_rect(Rect2(px - BODY_W * 0.5, py - BODY_H, BODY_W, BODY_H), _PRINCE_COLOR)
	if clock.curr.is_empty():
		return
	var label := "%s f%d%s" % [
		String(clock.curr.get("seq", "?")), int(clock.curr.get("frame", 0)),
		("  [paused]" if paused else "")]
	draw_string(ThemeDB.fallback_font, Vector2(px - 24.0, py - BODY_H - 6.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
