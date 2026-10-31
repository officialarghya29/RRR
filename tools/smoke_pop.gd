extends SceneTree

## Live scenario tracer (untracked scratch tool). CLI after `--`:
##   trace-b1 | trace-crouch | trace-hang | trace-hang-release | trace-grab
##   trace-grab-climb | trace-autodrop | trace-ss-floor | trace-ss-edge
##   trace-relfall | trace-shiftup
## Prints seq/frame/x/y per tick with the raw input triple.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "trace-b1"
	match mode:
		"trace-b1":
			_trace(_flat_level(), func(_t: int) -> PopInput: return PopInput.make(1, -1), 45, "up+forward from stand", Callable())
		"trace-crouch":
			_trace(_flat_level(), _scripted([
				[0, 1, 0], [0, 1, 0], [0, 1, 0],
			], [0, 0, 0]), 46, "down 3 ticks, release, stand-up", Callable())
		"trace-hang":
			_trace(_cliff_level(), _scripted([
				[0, 1, 1],  # down+shift at the floorless edge → climb down
			], [0, 0, 1]), 24, "climb down into the hang sway", _setup_edge_x)
		"trace-hang-release":
			_trace(_flat_level(), _scripted([
				[0, 0, 0],
			], [0, 0, 0]), 12, "hang release onto solid floor → hangdrop", _setup_hang)
		"trace-grab":
			_trace(_grab_gap_level(), _scripted([
				[0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1],
				[0, 0, 1], [0, 0, 1], [0, 0, 1],
			], [0, 0, 0]), 60, "crafted mid-air grab", _setup_grab)
		"trace-grab-climb":
			_trace(_grab_gap_level(), _scripted([
				[0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1],
				[0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1],
			], [0, -1, 1]), 40, "grab then climb out (Up from t15)", _setup_grab)
		"trace-autodrop":
			_trace(_cliff_level(), _scripted([
				[0, 1, 1],
			], [0, 0, 1]), 80, "climb down, hold shift, sway auto-drop", _setup_edge_x)
		"trace-ss-floor":
			_trace(_flat_level(), _scripted([
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
			], [0, 0, 0]), 25, "safe step on continuous floor", Callable())
		"trace-ss-edge":
			_trace(_edge_level(), _scripted([
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
				[1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1], [1, 0, 1],
			], [0, 0, 0]), 30, "safe step at the floor edge", Callable())
		"trace-relfall":
			_trace(_pit_hang_level(), _scripted([
				[0, 0, 0],
			], [0, 0, 0]), 30, "hang release with no floor behind", _setup_pit_hang)
		"trace-shiftup":
			_trace(_ledge_level(), _scripted([
				[0, -1, 1],
			], [0, 0, 1]), 35, "shift+up from stand into the hang", _setup_stand1)
		"trace-gate5":
			_trace_gate5()
	quit(0)


func _scripted(first: Array, rest: Array) -> Callable:
	# Lambdas capture locals by value, so drive the index from the tick arg.
	return func(t: int) -> PopInput:
		var triple: Array = first[mini(t - 1, first.size() - 1)] if t <= first.size() else rest
		return PopInput.make(int(triple[0]), int(triple[1]), int(triple[2]))


func _trace(level: Array, make_input: Callable, ticks: int, label: String, setup: Callable) -> void:
	var st: Dictionary = PopSim.initial_state(4242, level)
	if setup.is_valid():
		st = setup.call(st)
	print("=== TRACE %s | initial x=%d y=%d row=%d seq=%s frame=%d" % [
		label, int(st["x"]), int(st["y"]), int(st["row"]), String(st["seq"]), int(st["frame"])])
	var x0 := int(st["x"])
	for t: int in range(1, ticks + 1):
		var inp: PopInput = make_input.call(t)
		st = PopSim.step(st, inp)
		print("tick %d in(x=%d y=%d sh=%d) -> x=%d y=%d row=%d seq=%s frame=%d op=%d action=%d fall_y=%d grab_t=%d dx=%d" % [
			t, inp.x, inp.y, inp.shift,
			int(st["x"]), int(st["y"]), int(st["row"]), String(st["seq"]), int(st["frame"]),
			int(st["op"]), int(st["action"]), int(st["fall_y"]), int(st["grab_timer"]), int(st["x"]) - x0])
		if int(st["dead"]) != 0:
			return


## Replay the Session 009 gate-5 completability script against the REAL
## sim catalog level, phase by phase, printing per-tick truth (untracked
## debug aid; the committed assertion lives in tests/test_main.gd).
func _trace_gate5() -> void:
	var lv: Dictionary = LevelCatalog.sim_level_one()
	var st: Dictionary = PopSim.initial_state(int(lv["seed"]), lv["tiles"],
		lv.get("mods", {}) as Dictionary, lv.get("entities", {}) as Dictionary)
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)          # fwd+up
	var edge_walk := PopInput.make(1, 0, 1)   # shift+fwd
	var grab := PopInput.make(0, -1, 1)       # shift+up
	print("=== TRACE gate5 (real sim_gate) initial x=%d y=%d row=%d seq=%s frame=%d" % [
		int(st["x"]), int(st["y"]), int(st["row"]), String(st["seq"]), int(st["frame"])])

	var g := 0
	while int(st["row"]) != 1 and int(st["dead"]) == 0 and g < 90:
		st = _gate5_tick(st, right, "1 drop-to-ground", g)
		g += 1
	# (2) LAND the drop (step_fall → soft_land → stand_up) and reach a
	# launchable run state on the ground floor. run_jump's take-off window
	# for the col-10 pit (mouth x 198, far lip 212) is x ∈ [150, 178]: the
	# ground roll-in f34-38 covers +19 (must stay below the mouth) and the
	# airborne arc lands at f44 (+62, past 212). startrun enters at x 167 —
	# inside the window — so exit there, before x reaches 181 (run_cycle,
	# window closed). Holding fwd+Up during the fall would be swallowed
	# anyway; only hold `right` until launchable.
	var g2 := 0
	while int(st["dead"]) == 0 and g2 < 60 and not (
			int(st["row"]) == 1
			and (String(st["seq"]) == "startrun" or String(st["seq"]) == "run_cycle")
			and int(st["x"]) >= 150 and int(st["x"]) <= 178):
		st = _gate5_tick(st, right, "2 land-to-takeoff", g2)
		g2 += 1
	var takeoff := int(st["x"])
	print("--- takeoff x=%d seq=%s frame=%d" % [int(st["x"]), String(st["seq"]), int(st["frame"])])
	# (3) fwd+Up from the run-up starts run_jump: roll in on the ground,
	# arc the pit, land past the far lip. Held input is swallowed by the
	# locked sequence, so keep holding through launch and flight.
	var g3 := 0
	while String(st["seq"]) != "run_jump" and int(st["dead"]) == 0 and g3 < 8:
		st = _gate5_tick(st, jump, "3 launch", g3)
		g3 += 1
	while String(st["seq"]) == "run_jump" and int(st["dead"]) == 0 and g3 < 40:
		st = _gate5_tick(st, jump, "3 fly", g3)
		g3 += 1
	print("--- landed x=%d row=%d seq=%s frame=%d (takeoff %d)" % [
		int(st["x"]), int(st["row"]), String(st["seq"]), int(st["frame"]), takeoff])
	while int(st["x"]) < 250 and int(st["row"]) == 1 \
			and int(st["dead"]) == 0 and g3 < 60:
		st = _gate5_tick(st, edge_walk, "3c walk-to-grab", g3)
		g3 += 1
	var g3d := 0
	while String(st["seq"]) != "stand" and int(st["dead"]) == 0 and g3d < 15:
		st = _gate5_tick(st, neutral, "3d settle", g3d)
		g3d += 1
	print("--- grab setup x=%d seq=%s frame=%d" % [int(st["x"]), String(st["seq"]), int(st["frame"])])
	print("--- grab window x=%d row=%d seq=%s" % [
		int(st["x"]), int(st["row"]), String(st["seq"])])
	var g6 := 0
	while String(st["seq"]) != "hang" and int(st["dead"]) == 0 and g6 < 30:
		st = _gate5_tick(st, grab, "6 grab", g6)
		g6 += 1
	var g7 := 0
	while String(st["seq"]) != "stand" and int(st["dead"]) == 0 and g7 < 40:
		st = _gate5_tick(st, grab, "7 climb", g7)
		g7 += 1
	print("--- after climb x=%d row=%d seq=%s" % [
		int(st["x"]), int(st["row"]), String(st["seq"])])
	var g8 := 0
	while int(st["dead"]) == 0 and g8 < 300:
		var before_gates := str((st.get("gates", {}) as Dictionary).duplicate(true))
		st = _gate5_tick(st, right, "8 cross", g8)
		var after_gates := str((st.get("gates", {}) as Dictionary).duplicate(true))
		if before_gates != after_gates:
			print("    gates changed: %s" % after_gates)
		g8 += 1
		if String(st["seq"]) == "run_cycle" and int(st["row"]) == 0 \
				and PopSim._col_of(PopSim._foot_x(st)) >= 21:
			break
	print("=== gate5 trace end x=%d row=%d seq=%s dead=%d hp=%d ticks=%d" % [
		int(st["x"]), int(st["row"]), String(st["seq"]), int(st["dead"]), int(st["hp"]),
		g + g2 + g3 + g3d + g6 + g7 + g8])


func _gate5_tick(st: Dictionary, inp: PopInput, phase: String, t: int) -> Dictionary:
	var s: Dictionary = PopSim.step(st, inp)
	print("[%s t=%d] in(x=%d y=%d sh=%d) -> x=%d y=%d row=%d seq=%s frame=%d op=%d dead=%d fall_y=%d" % [
		phase, t, inp.x, inp.y, inp.shift,
		int(s["x"]), int(s["y"]), int(s["row"]), String(s["seq"]), int(s["frame"]),
		int(s["op"]), int(s["dead"]), int(s["fall_y"])])
	return s


## A hanging kid above a solid floor: releasing Shift lands him (hangdrop).
func _setup_hang(st: Dictionary) -> Dictionary:
	st["row"] = 0
	st["y"] = int(PopTables.Y_LAND[1])
	st["x"] = 148
	st["seq"] = "hang"
	st["op"] = 0
	st["action"] = PopTables.Action.HANG_CLIMB
	return st


## Standing 2 units from the cliff lip of column 0 (foot x 69, edge distance
## 2 → the <3 climb-down rule fires on Down).
func _setup_edge_x(st: Dictionary) -> Dictionary:
	st["x"] = 72
	return st


## A falling kid at row 1, x inside column 6, shift held: the col-7 ledge lip
## sits one row up and ahead — the mid-air grab should catch it.
func _setup_grab(st: Dictionary) -> Dictionary:
	st["row"] = 1
	st["y"] = 104
	st["x"] = 148
	st["seq"] = "free_fall"
	st["frame"] = 106
	st["action"] = PopTables.Action.IN_FREEFALL
	st["fall_y"] = 15
	st["fall_x"] = 0
	return st


func _flat_level() -> Array:
	var tiles: Array = []
	for _r: int in 4:
		var row: Array = []
		for _c: int in 10:
			row.append(PopTables.Tile.FLOOR)
		tiles.append(row)
	return tiles


## Row 0 floored on col 0 only — a cliff just ahead of the start;
## rows 1-2 empty below, so the climb down sinks into open air; row 3 solid.
func _cliff_level() -> Array:
	var tiles: Array = []
	for r: int in 4:
		var row: Array = []
		for c: int in 10:
			if r == 0 and c < 1:
				row.append(PopTables.Tile.FLOOR)
			elif r >= 3:
				row.append(PopTables.Tile.FLOOR)
			else:
				row.append(PopTables.Tile.EMPTY)
		tiles.append(row)
	return tiles


## A 1-tile gap at column 6 spanning rows 0-2: the kid falls in and under
## the col-7 lip, which his hands can catch from below.
func _grab_gap_level() -> Array:
	var tiles: Array = []
	for r: int in 4:
		var row: Array = []
		for c: int in 14:
			row.append(PopTables.Tile.EMPTY if (c == 6 and r <= 2) else PopTables.Tile.FLOOR)
		tiles.append(row)
	return tiles


## Flat at row 0 col 0 only; the column ahead (col 1) is open down to the
## row-3 floor — the kid safe-steps to the lip and must hold there.
func _edge_level() -> Array:
	var tiles: Array = []
	for r: int in 4:
		var row: Array = []
		for c: int in 14:
			if r == 3 or (r == 0 and c < 1):
				row.append(PopTables.Tile.FLOOR)
			else:
				row.append(PopTables.Tile.EMPTY)
		tiles.append(row)
	return tiles


## A one-tile pit opening at col 6, row 0; the hang row (1) has no floor at
## the char column or behind — releasing the ledge must fall (release_fall).
func _pit_hang_level() -> Array:
	var tiles: Array = []
	for r: int in 4:
		var row: Array = []
		for c: int in 14:
			if r == 0 and c != 6:
				row.append(PopTables.Tile.FLOOR)
			elif r >= 3:
				row.append(PopTables.Tile.FLOOR)
			else:
				row.append(PopTables.Tile.EMPTY)
		tiles.append(row)
	return tiles


## Open air over cols 0-1 at row 0, floor from col 2 on — a ledge one row
## above the row-1 stand that a Shift+Up can catch.
func _ledge_level() -> Array:
	var tiles: Array = []
	for r: int in 4:
		var row: Array = []
		for c: int in 14:
			if r == 0 and c < 2:
				row.append(PopTables.Tile.EMPTY)
			else:
				row.append(PopTables.Tile.FLOOR)
		tiles.append(row)
	return tiles


## A hanging kid in the pit at col 6, row 1 (y = row-1 floor), nothing
## grabbable needed — the release path runs from the crafted state.
func _setup_pit_hang(st: Dictionary) -> Dictionary:
	st["row"] = 1
	st["y"] = int(PopTables.Y_LAND[2])
	st["x"] = 148
	st["seq"] = "hang"
	st["op"] = 0
	st["action"] = PopTables.Action.HANG_CLIMB
	return st


## Standing on the row-1 floor at x=79 (foot column 1), facing right.
func _setup_stand1(st: Dictionary) -> Dictionary:
	st["row"] = 1
	st["y"] = int(PopTables.Y_LAND[2])
	st["x"] = 79
	return st
