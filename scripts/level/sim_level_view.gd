class_name SimLevelView
extends Node2D
## Plan B0.1 — draws the sim tile grid and the entity visuals for the sim
## path. Pure view: reads [SimWorld] snapshots, writes nothing.
##
## Uses the sim's own column mapping (tile col c spans x 58+14c .. 71+14c
## units, PARITY §2) so tiles and the prince share one coordinate space.

const _FLOOR := Color(0.42, 0.36, 0.28)
const _WALL := Color(0.30, 0.30, 0.34)
const _SPIKES := Color(0.72, 0.20, 0.20)
const _PLATE := Color(0.35, 0.55, 0.42)
const _PLATE_HELD := Color(0.45, 0.85, 0.55)
const _GATE := Color(0.55, 0.48, 0.60)
const _EXIT_OPEN := Color(0.20, 0.55, 0.75)
const _EXIT_SHUT := Color(0.16, 0.30, 0.40)
const _BG := Color(0.09, 0.08, 0.12)

var world: SimWorld


func _init(p_world: SimWorld) -> void:
	world = p_world


func _process(_delta: float) -> void:
	queue_redraw()


func _tile_rect(col: int, row: int) -> Rect2:
	return Rect2(
		float(58 + PopTables.TILE_W * col) * SimWorld.PX_PER_UNIT,
		float(int(PopTables.Y_LAND[row + 1])) * SimWorld.PX_PER_UNIT,
		float(PopTables.TILE_W) * SimWorld.PX_PER_UNIT,
		float(PopTables.TILE_H) * SimWorld.PX_PER_UNIT)


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -1000.0, 6000.0, 4000.0), _BG)
	var tiles: Array = world.bundle.get("tiles", [])
	for row: int in range(tiles.size()):
		var cells: Array = tiles[row]
		for col: int in range(cells.size()):
			var tile := int(cells[col])
			match tile:
				PopTables.Tile.EMPTY:
					continue
				PopTables.Tile.SPIKES:
					draw_rect(_tile_rect(col, row), _SPIKES)
				PopTables.Tile.BUTTON_RAISE, PopTables.Tile.BUTTON_DROP:
					draw_rect(_tile_rect(col, row), _PLATE)
				PopTables.Tile.GATE:
					draw_rect(_tile_rect(col, row), _GATE)
				PopTables.Tile.EXIT_DOOR_LEFT, PopTables.Tile.EXIT_DOOR_RIGHT:
					draw_rect(_tile_rect(col, row), _EXIT_SHUT)
				_:
					draw_rect(_tile_rect(col, row), _FLOOR)
	_draw_entities()


## Entity overlays driven by the sim state (read-only): plate hold timers,
## gate modifiers (PARITY §9: 0 closed .. 188+ open), the level-exit door.
func _draw_entities() -> void:
	var s := world.state
	if s.is_empty():
		return
	for key: String in (s.get("plates", {}) as Dictionary):
		var parts := key.split(",")
		var held := int((s["plates"] as Dictionary)[key]) > 0
		draw_rect(_tile_rect(int(parts[1]), int(parts[0])).grow(-6.0),
			_PLATE_HELD if held else _PLATE)
	for key: String in (s.get("gates", {}) as Dictionary):
		var gparts := key.split(",")
		var g: Dictionary = (s["gates"] as Dictionary)[key]
		var mod := int(g["mod"])
		var open_frac := clampf(float(mod) / 188.0, 0.0, 1.0)
		# A gate draws as a slab that sinks into the floor as it opens.
		var full := _tile_rect(int(gparts[1]), int(gparts[0]))
		var slab := Rect2(full.position, Vector2(full.size.x, full.size.y * (1.0 - open_frac)))
		draw_rect(slab, _GATE)
	var exit_door: Dictionary = s.get("exit", {})
	if not exit_door.is_empty():
		var lit := int(exit_door.get("mod", 0)) > 0
		draw_rect(_tile_rect(int(exit_door["col"]), int(exit_door["row"])),
			_EXIT_OPEN if lit else _EXIT_SHUT)
