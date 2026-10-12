class_name SimLevelView
extends Node2D
## Plan B0.1 — draws the sim tile grid and the entity visuals for the sim
## path. Pure view: reads [SimWorld] snapshots, writes nothing.
##
## Session 011 (step 2) — rendering sanity pass. Every pixel goes through ONE
## documented world-to-screen function: [method SimWorld.sim_units_to_px]
## (separate x/y scales — [constant SimWorld.PX_PER_UNIT] horizontal,
## [constant SimWorld.PX_PER_UNIT_Y] vertical; the cited 32 px : 63 px display
## ratio for a 14x63-unit cell, `types.h:1405`/`types.h:1408`, PARITY §2
## "Unit scale"). Causes fixed here, all view-side (no sim logic, no PARITY
## value, no sim test touched):
##   1. cells drew 42x189 px (4.5:1) — an isotropic x3 mapping where the
##      reference uses different x/y scales; now 42x82.7 px (63/32 = 1.97:1,
##      the original's ~2:1 look), through sim_units_to_px everywhere;
##   2. "one row too low": the old view drew gate/plate/exit with the TILE
##      rect (which correctly spans [Y_LAND[r+1], +63] — the ground block a
##      kid on row r stands ON) so the columns hung from the floor line DOWN
##      into the floor. Objects now use [method object_rect] — the walkable
##      cell [Y_LAND[r], Y_LAND[r+1]] — so a column STANDS on row r's floor
##      line and fills the space above it. Verdict for the review: view
##      (object anchor), not level data — the catalog's row/col keys and
##      input-space spawn/bounds are unchanged;
##   3. nothing named the colored bars — every entity now carries a text
##      marker (P/G/E), and F3 toggles the debug overlay: tile grid, row and
##      column numbers, sim x/y + tick readout, and a color legend.
##
## Two rectangle rules, both through the one mapping:
##   [method tile_rect]   — ground BLOCK for the tile at (col,row): spans
##                          [Y_LAND[r+1], Y_LAND[r+1]+63], i.e. directly
##                          BELOW the feet line of a kid on row r
##                          (floor_y(r) = Y_LAND[r+1], PARITY §2);
##   [method object_rect] — the WALKABLE CELL for an object at (col,row):
##                          [Y_LAND[r], Y_LAND[r+1]], i.e. the 63-unit space
##                          above row r's floor line — where a gate, plate or
##                          door stands ON the floor.

const _FLOOR := Color(0.42, 0.36, 0.28)
const _WALL := Color(0.30, 0.30, 0.34)
const _SPIKES := Color(0.72, 0.20, 0.20)
const _PLATE := Color(0.35, 0.55, 0.42)
const _PLATE_HELD := Color(0.45, 0.85, 0.55)
const _GATE := Color(0.55, 0.48, 0.60)
const _EXIT_OPEN := Color(0.20, 0.55, 0.75)
const _EXIT_SHUT := Color(0.16, 0.30, 0.40)
const _BG := Color(0.09, 0.08, 0.12)
const _GRID := Color(1.0, 1.0, 1.0, 0.12)
const _GRID_STRONG := Color(1.0, 1.0, 1.0, 0.30)

## Plate lip height in sim units: a low disc ON the floor, never taller than
## a quarter of the row (presentation placeholder, sized in sim units).
const PLATE_LIP_UNITS: float = 8.0

var world: SimWorld
var _debug: bool = false
var _readout: Label = null
var _readout_panel: ColorRect = null


func _init(p_world: SimWorld) -> void:
	world = p_world


func _ready() -> void:
	# F3 debug overlay readout: screen-space text on its own layer; the grid,
	# numbers and legend draw in world space with the tiles they describe.
	var layer := CanvasLayer.new()
	layer.name = "SimDebugLayer"
	layer.layer = 12
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.55)
	panel.position = Vector2(8.0, 150.0)
	panel.size = Vector2(340.0, 150.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_readout = Label.new()
	_readout.position = Vector2(14.0, 156.0)
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_readout)
	_readout_panel = panel
	panel.visible = false
	_readout.visible = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_overlay"):
		_debug = not _debug
		if _readout != null:
			_readout_panel.visible = _debug
			_readout.visible = _debug
	if _debug and _readout != null and world != null and not world.state.is_empty():
		_update_readout()
	queue_redraw()


# --- The one world-to-screen mapping, in rectangles -------------------------

## Left edge of column [param col] in sim units: the cited tile-x formula
## `x_bump[i] = −12 + 14·i` (`data.h:513`, PARITY §2) anchored at the table's
## on-screen origin — uniform 14-unit columns, valid beyond the 20 entries
## the reference table lists (our levels run to column 25).
static func _cell_x_units(col: int) -> float:
	return float(PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN] + PopTables.TILE_W * col)


## Ground BLOCK under a kid on [param row]: [code]Y_LAND[row+1] .. +63[/code]
## units (the feet line down through the solid floor). Static so the view
## tests can pin it headlessly.
static func tile_rect(col: int, row: int) -> Rect2:
	var top_units := _row_floor_units(row)
	var top := SimWorld.sim_units_to_px(0.0, top_units)
	return Rect2(
		top.x + _cell_x_units(col) * SimWorld.PX_PER_UNIT,
		top.y,
		float(PopTables.TILE_W) * SimWorld.PX_PER_UNIT,
		float(PopTables.TILE_H) * SimWorld.PX_PER_UNIT_Y)


## WALKABLE CELL an object in [param row] stands in:
## [code]Y_LAND[row] .. Y_LAND[row+1][/code] — the 63-unit space above row
## [param row]'s floor line, so the object's bottom edge IS the floor line.
static func object_rect(col: int, row: int) -> Rect2:
	var top_units := _row_top_units(row)
	var bottom_units := _row_floor_units(row)
	var top := SimWorld.sim_units_to_px(0.0, top_units)
	var bottom := SimWorld.sim_units_to_px(0.0, bottom_units)
	return Rect2(
		top.x + _cell_x_units(col) * SimWorld.PX_PER_UNIT,
		top.y,
		float(PopTables.TILE_W) * SimWorld.PX_PER_UNIT,
		bottom.y - top.y)


## The plate: a low lip standing ON row [param row]'s floor line (its bottom
## edge touches the line; it never sinks into the floor).
static func plate_rect(col: int, row: int) -> Rect2:
	var floor_y := SimWorld.sim_units_to_px(0.0, _row_floor_units(row)).y
	var x := _cell_x_units(col) * SimWorld.PX_PER_UNIT
	return Rect2(x, floor_y - PLATE_LIP_UNITS * SimWorld.PX_PER_UNIT_Y,
		float(PopTables.TILE_W) * SimWorld.PX_PER_UNIT,
		PLATE_LIP_UNITS * SimWorld.PX_PER_UNIT_Y)


## The gate slab inside row [param row]'s walkable cell. A portcullis hangs
## from the cell's top edge and lifts as it opens ([param open_frac] 0 = shut
## — full cell, standing on the floor; 1 = open — nothing in the walkway),
## so the bottom edge rises off the floor line as the gate opens (PARITY §9:
## mod 0 closed .. 188+ open).
static func gate_slab_rect(col: int, row: int, open_frac: float) -> Rect2:
	var cell := object_rect(col, row)
	return Rect2(cell.position,
		Vector2(cell.size.x, cell.size.y * (1.0 - clampf(open_frac, 0.0, 1.0))))


## Upper edge of row [param row] in sim units: the floor line above it
## ([code]Y_LAND[row][/code]). Below the modeled floors falls back to one
## row above [constant PopTables.Y_LAND]'s first entry (the F3 legend band).
static func _row_top_units(row: int) -> float:
	if row >= 0 and row + 1 < PopTables.Y_LAND.size():
		return float(PopTables.Y_LAND[row])
	return float(PopTables.Y_LAND[0]) - float(PopTables.TILE_H)


## Floor line of row [param row] in sim units — floor_y(row) in the sim
## ([code]Y_LAND[row+1][/code], PARITY §2), where objects stand.
static func _row_floor_units(row: int) -> float:
	var idx: int = row + 1
	if idx >= 0 and idx < PopTables.Y_LAND.size():
		return float(PopTables.Y_LAND[idx])
	return float(PopTables.Y_LAND[0]) - float(PopTables.TILE_H) + float(PopTables.TILE_H)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	# Bounded backdrop: content ends well before this, so the bottom of the
	# screen is background, never a half-drawn row pushed off the edge.
	draw_rect(Rect2(-2000.0, -2000.0, 8000.0, 6000.0), _BG)
	var tiles: Array = world.bundle.get("tiles", [])
	for row: int in range(tiles.size()):
		var cells: Array = tiles[row]
		for col: int in range(cells.size()):
			var tile := int(cells[col])
			match tile:
				PopTables.Tile.EMPTY:
					continue
				PopTables.Tile.SPIKES:
					draw_rect(tile_rect(col, row), _SPIKES)
				PopTables.Tile.WALL:
					draw_rect(tile_rect(col, row), _WALL)
				_:
					# Walkable ground — including button/gate/exit tiles: the
					# block under the feet line. Identity (P/G/E) comes from
					# the entity overlay below, not from the floor block.
					draw_rect(tile_rect(col, row), _FLOOR)
	_draw_entities()
	_draw_markers()
	if _debug:
		_draw_debug_world()


## Entity overlays driven by the sim state (read-only), each standing in the
## walkable cell: plate lip on the floor line, gate slab in the cell, exit
## door frame in the cell (PARITY §9 gate mod, §7/§8 traps unchanged).
func _draw_entities() -> void:
	var s := world.state
	if s.is_empty():
		return
	for key: String in (s.get("plates", {}) as Dictionary):
		var parts := key.split(",")
		var held := int((s.get("plates", {}) as Dictionary)[key]) > 0
		draw_rect(plate_rect(int(parts[1]), int(parts[0])),
			_PLATE_HELD if held else _PLATE)
	for key: String in (s.get("gates", {}) as Dictionary):
		var gparts := key.split(",")
		var g: Dictionary = (s.get("gates", {}) as Dictionary)[key]
		var open_frac := clampf(float(int(g["mod"])) / 188.0, 0.0, 1.0)
		draw_rect(gate_slab_rect(int(gparts[1]), int(gparts[0]), open_frac), _GATE)
	var exit_door: Dictionary = s.get("exit", {})
	if not exit_door.is_empty():
		var lit := int(exit_door.get("mod", 0)) > 0
		draw_rect(object_rect(int(exit_door["col"]), int(exit_door["row"])),
			_EXIT_OPEN if lit else _EXIT_SHUT)


## Session 011 step 2: every entity carries a text marker so a colored bar is
## never ambiguous (P = plate, G = gate, E = exit door).
func _draw_markers() -> void:
	var font := ThemeDB.fallback_font
	var s := world.state
	for key: String in (s.get("plates", {}) as Dictionary):
		var parts := key.split(",")
		_mark(font, plate_rect(int(parts[1]), int(parts[0])), "P")
	for key: String in (s.get("gates", {}) as Dictionary):
		var gparts := key.split(",")
		_mark(font, object_rect(int(gparts[1]), int(gparts[0])), "G")
	var exit_door: Dictionary = s.get("exit", {})
	if not exit_door.is_empty():
		_mark(font, object_rect(int(exit_door["col"]), int(exit_door["row"])), "E")


func _mark(font: Font, rect: Rect2, text: String) -> void:
	draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y - 4.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 1.0, 1.0, 0.85))


## F3 overlay drawn in world space: the tile grid, row/column numbers and the
## color legend. The live readout (sim x/y, tick, entities) is the screen-
## space label built in [method _ready].
func _draw_debug_world() -> void:
	var tiles: Array = world.bundle.get("tiles", [])
	var cols: int = 0
	for row: Array in tiles:
		cols = maxi(cols, row.size())
	var x_left := tile_rect(0, 0).position.x
	var x_right := tile_rect(cols + 1, 0).end.x
	# Horizontal lines at every floor line (strong) and every cell top (weak):
	# the row bands the sim's floor_y(row) addressing uses.
	for row: int in range(-1, tiles.size()):
		var y := object_rect(0, row).position.y
		draw_line(Vector2(x_left - 40.0, y), Vector2(x_right, y),
			_GRID_STRONG if row >= 0 else _GRID, 1.0)
	for row: int in range(tiles.size()):
		var floor_y := tile_rect(0, row).position.y
		draw_line(Vector2(x_left - 40.0, floor_y), Vector2(x_right, floor_y), _GRID_STRONG, 1.0)
	# Vertical lines at every tile boundary.
	for col: int in range(cols + 2):
		var x := tile_rect(col, 0).position.x
		draw_line(Vector2(x, object_rect(0, -1).position.y),
			Vector2(x, tile_rect(0, tiles.size() - 1).end.y), _GRID, 1.0)
	# Row and column numbers inside the walkable cells.
	var font := ThemeDB.fallback_font
	for row: int in range(tiles.size()):
		for col: int in range((tiles[row] as Array).size()):
			draw_string(font, object_rect(col, row).position + Vector2(2.0, 12.0),
				"%d,%d" % [row, col], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9,
				Color(1.0, 1.0, 1.0, 0.45))
	# Legend naming each color, parked in the band above the first row.
	var legend := [
		["floor", _FLOOR], ["spikes", _SPIKES], ["plate (P)", _PLATE],
		["plate held", _PLATE_HELD], ["gate slab (G)", _GATE],
		["exit open (E)", _EXIT_OPEN], ["exit shut", _EXIT_SHUT],
	]
	var ly := object_rect(0, -1).position.y + 16.0
	var lx := float(58) * SimWorld.PX_PER_UNIT
	draw_string(font, Vector2(lx, ly), "LEGEND (F3)",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 1.0, 1.0, 0.9))
	for i: int in legend.size():
		var entry: Array = legend[i]
		var y := ly + 16.0 + 16.0 * float(i)
		draw_rect(Rect2(lx, y - 11.0, 14.0, 12.0), entry[1])
		draw_string(font, Vector2(lx + 20.0, y),
			String(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11,
			Color(1.0, 1.0, 1.0, 0.85))


func _update_readout() -> void:
	var s: Dictionary = world.state
	var parts := ""
	for key: String in (s.get("plates", {}) as Dictionary):
		parts += " %s=%d" % [key, int((s.get("plates", {}) as Dictionary)[key])]
	var gates := ""
	for key: String in (s.get("gates", {}) as Dictionary):
		var g: Dictionary = (s.get("gates", {}) as Dictionary)[key]
		gates += " %s mod=%d" % [key, int(g["mod"])]
	_readout.text = "SIM DEBUG (F3)\nsim x=%d y=%d  row=%d col=%d  dir=%d\nseq=%s f%d  tick=%d  hp=%d dead=%d\nplates:%s\ngates:%s\nexit mod=%d  echoes=%d" % [
		int(s.get("x", 0)), int(s.get("y", 0)), int(s.get("row", 0)),
		PopSim._col_of(PopSim._foot_x(s)), int(s.get("dir", 1)),
		String(s.get("seq", "?")), int(s.get("frame", 0)), int(s.get("tick", 0)),
		int(s.get("hp", 0)), int(s.get("dead", 0)),
		parts.strip_edges(), gates.strip_edges(),
		int((s.get("exit", {}) as Dictionary).get("mod", -1)),
		TemporalManager.echo_count()]
