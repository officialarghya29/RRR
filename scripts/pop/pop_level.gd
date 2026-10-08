class_name PopLevel
extends RefCounted
## Plan A4.1 — room-grid model (10×3 tile rooms, links, modifiers) plus the
## deterministic gate / plate / level-exit-door machines.
##
## Rooms are 10×3 tiles and a level is a grid of them (up to 24 rooms,
## `types.h` level_type; PARITY §2/§16). [method flatten] lays a grid of rooms
## out the way the reference addresses them: `row = room_row*3 + local row`,
## `col = room_col*10 + local col`. Reference behaviour is mirrored from the
## cited `seg007.c` branches (PARITY §9/§10) — no reference code is copied.
##
## Pure and integer-only: [method step_entities] mutates the sim state
## dictionary in place and reads nothing but its arguments, so a run's gate /
## plate / door state stays reproducible and hashable.


const ROOM_W: int = 10
const ROOM_H: int = 3
const MAX_ROOMS: int = 24  ## a level is at most 24 linked rooms (`types.h`)


## Flatten a grid of rooms — an Array of room-rows, each an Array of 10×3
## tile arrays — into the flat `tiles` array PopSim consumes.
static func flatten(room_rows: Array) -> Array:
	var rows: Array = []
	for local_r: int in ROOM_H:
		var cells: Array = []
		for room_row: Array in room_rows:
			for room: Array in room_row:
				for c: int in ROOM_W:
					cells.append(int(room[local_r][c]))
		rows.append(cells)
	return rows


## Two side-by-side rooms with a raise plate wired to a gate in the first room
## and a level-exit door in the second. Returns the bundle PopSim consumes:
## `tiles`, `mods`, and the `entities` dictionary (`gates` / `plates` /
## `links` / `exit`).
static func small_test_level() -> Dictionary:
	var room_a: Array = _square_room()
	var room_b: Array = _square_room()
	room_a[0][3] = PopTables.Tile.BUTTON_RAISE
	room_a[0][7] = PopTables.Tile.GATE
	room_b[0][5] = PopTables.Tile.EXIT_DOOR_LEFT   # local col 5 → global col 15
	return {
		"tiles": flatten([[room_a, room_b]]),
		"mods": {},
		"entities": {
			"gates": {"0,7": {"mod": PopTables.GATE_CLOSED, "type": -1}},
			"plates": {"0,3": 0},
			"links": [{"plate": "0,3", "gate": "0,7"}],
			"exit": {"row": 0, "col": 15, "mod": PopTables.LEVELDOOR_START, "type": 3},
		},
	}


static func _square_room() -> Array:
	var room: Array = []
	for _r: int in ROOM_H:
		var cells: Array = []
		for _c: int in ROOM_W:
			cells.append(PopTables.Tile.FLOOR)
		room.append(cells)
	return room


# --- Gate / plate / level-door machines (seg007.c, PARITY §9/§10) ----------


## Advance one tick of every gate, plate and the level-exit door. `kid_row` /
## `kid_col` / `kid_tile` describe where the kid is this tick — the reference
## `check_press` reads the tile the char stands on (`seg006.c:1676-1698`).
static func step_entities(s: Dictionary, kid_row: int, kid_col: int, kid_tile: int) -> void:
	var gates: Dictionary = s.get("gates", {})
	var plates: Dictionary = s.get("plates", {})
	var exit_door: Dictionary = s.get("exit", {})
	if gates.is_empty() and plates.is_empty() and exit_door.is_empty():
		return

	# 1. press: check_press → trigger_button (`seg007.c:742-768`). A held plate
	#    resets its timer to 5 every tick, so it only fires when the timer was
	#    below 2 at the start of the tick.
	var plate_key: String = "%d,%d" % [kid_row, kid_col]
	var pressing: bool = kid_tile == PopTables.Tile.BUTTON_RAISE \
			or kid_tile == PopTables.Tile.BUTTON_DROP
	for key: String in plates.keys():
		if pressing and key == plate_key:
			_trigger_plate(s, key, kid_tile)

	# 2. animate buttons (`seg007.c:783-791`): the timer decrements per logic
	#    frame and stops below 2.
	for key: String in plates.keys():
		var timer: int = int(plates[key])
		if timer >= PopTables.PLATE_REPRESS_BELOW:
			plates[key] = timer - 1

	# 3. animate gates (`seg007.c:336-403`).
	for key: String in gates.keys():
		_animate_gate(gates[key])

	# 4. animate the level-exit door (`seg007.c:411-449`).
	if not exit_door.is_empty():
		_animate_leveldoor(exit_door)


## `trigger_button` + `trigger_gate` (`seg007.c:742-768`, `seg007.c:600-637`):
## a press fires the linked gate only when the plate's timer was < 2.
static func _trigger_plate(s: Dictionary, key: String, kid_tile: int) -> void:
	var plates: Dictionary = s["plates"]
	var timer: int = int(plates[key])
	if timer == PopTables.PLATE_JAMMED:
		return  # jammed: ignore the press entirely
	plates[key] = PopTables.PLATE_HOLD_TIMER
	if timer >= PopTables.PLATE_REPRESS_BELOW:
		return  # still animating: reset the timer but do not re-fire
	for link: Dictionary in (s.get("links", []) as Array):
		if String(link["plate"]) != key:
			continue
		var gate: Dictionary = (s["gates"] as Dictionary).get(String(link["gate"]), {})
		if not gate.is_empty():
			_trigger_gate(gate, kid_tile)


## `trigger_gate` (`seg007.c:600-637`), keyed by the pressed tile. Opener
## (raise plate) rounds the modifier up to a multiple of 4 and starts opening;
## a gate already ≥188 is re-parked at 238; a permanent gate is left alone.
## Closer (drop plate) starts a fast close when the gate is not already closed.
static func _trigger_gate(gate: Dictionary, button_tile: int) -> void:
	var modifier: int = int(gate["mod"])
	if button_tile == PopTables.Tile.BUTTON_RAISE:
		if modifier == PopTables.GATE_PERMANENT:
			return
		if modifier >= PopTables.GATE_OPEN_THRESHOLD:
			gate["mod"] = PopTables.GATE_PARKED   # keep it open for a while
			return
		gate["mod"] = (modifier + 3) & 0xFC
		gate["type"] = 1                            # regular open
	elif button_tile == PopTables.Tile.BUTTON_DROP:
		if modifier != 0:
			gate["type"] = 3                        # close fast


## `animate_door` (`seg007.c:336-403`).
static func _animate_gate(gate: Dictionary) -> void:
	var anim_type: int = int(gate["type"])
	if anim_type < 0:
		return
	if anim_type >= 3:
		# closing fast: the type auto-increments up to 8, then chooses the speed
		if anim_type < 8:
			anim_type += 1
			gate["type"] = anim_type
		var new_mod: int = int(gate["mod"]) - PopTables.GATE_CLOSE_SPEEDS[anim_type]
		gate["mod"] = new_mod
		if new_mod < 0:
			gate["mod"] = 0
			gate["type"] = -1
		return
	if int(gate["mod"]) == PopTables.GATE_PERMANENT:
		gate["type"] = -1
		return
	gate["mod"] = int(gate["mod"]) + PopTables.DOOR_DELTA[anim_type]
	if anim_type == 0:
		if int(gate["mod"]) == 0:
			gate["type"] = -1          # close reached → stop
	else:
		if int(gate["mod"]) >= PopTables.GATE_OPEN_THRESHOLD:
			if anim_type < 2:
				gate["mod"] = PopTables.GATE_PARKED   # after regular open
				gate["type"] = 0                      # then switch to closing
			else:
				gate["mod"] = PopTables.GATE_PERMANENT
				gate["type"] = -1


## `animate_leveldoor` (`seg007.c:411-449`): a door starts fully open
## (modifier 43) and fast-closes through the {0,5,17,99} speed ramp.
static func _animate_leveldoor(exit_door: Dictionary) -> void:
	var anim_type: int = int(exit_door["type"])
	if anim_type < 0:
		return
	if anim_type >= 3:
		if anim_type < 8:
			anim_type += 1
			exit_door["type"] = anim_type
		var idx: int = anim_type - 3
		if idx >= PopTables.LEVELDOOR_CLOSE_SPEEDS.size():
			idx = PopTables.LEVELDOOR_CLOSE_SPEEDS.size() - 1
		var new_mod: int = int(exit_door["mod"]) - PopTables.LEVELDOOR_CLOSE_SPEEDS[idx]
		exit_door["mod"] = new_mod
		if new_mod < 0:
			exit_door["mod"] = 0
			exit_door["type"] = -1
		return
	exit_door["mod"] = int(exit_door["mod"]) + 1
	if int(exit_door["mod"]) >= PopTables.LEVELDOOR_OPEN_AT:
		exit_door["type"] = -1
