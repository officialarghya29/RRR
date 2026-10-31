# Session 012 step 4 — the whole game flow, scripted headless:
# title → controls → title → credits → title → Begin → level 1 → level-complete
# screen → Continue → level 2 (pause/resume, death, restart-from-checkpoint)
# → level-complete screen → Continue → level 3 → victory screen → title.
#
# Every level is finished by its own scripted sim run through the REAL scene
# (exit_reached -> GameManager.complete_level), and every screen transition is
# driven through the real MenuScreen's action signal — the same path a button
# press takes. Per-level completability/determinism is owned by the other
# suites; this file proves the FLOW around them.

extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().physics_frame

	_section("Title, controls and credits (S012 step 4)")
	_test_title_screens()

	_section("Level 1 through the flow")
	_test_level_one()

	_section("Pause, death and restart-from-checkpoint (in level 2)")
	await _test_pause_and_checkpoint()

	_section("Level 2 through the flow")
	_test_level_two()

	_section("Level 3, victory, back to title")
	_test_level_three_and_victory()

	_finish()


# --- Harness (same output contract as the other suites) ---------------------

func _section(label: String) -> void:
	print("")
	print("== %s ==" % label)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)


func _finish() -> void:
	print("")
	print("-----------------------------------------")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("-----------------------------------------")
	get_tree().quit(1 if _failed > 0 else 0)


func _menu() -> MenuScreen:
	return GameManager.get_node("MenuLayer/Menu") as MenuScreen


# --- Scripted runs (one per level; the routes are the ones the other suites
# pin — this file only consumes them, asserting on the flow states) ----------

## Level 1: drop, run-jump the pit, hang-climb the ledge, cross the plate,
## let the gate run its schedule, walk into the exit door.
func _run_level_one(world: SimWorld) -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)
	var edge_walk := PopInput.make(1, 0, 1)
	var grab := PopInput.make(0, -1, 1)
	var t := 0
	while int(world.state["row"]) != 1 and int(world.state["dead"]) == 0 and t < 90:
		world.step_with(right)
		t += 1
	t = 0
	while int(world.state["dead"]) == 0 and t < 60 and not (
			int(world.state["row"]) == 1
			and (String(world.state["seq"]) == "startrun" or String(world.state["seq"]) == "run_cycle")
			and int(world.state["x"]) >= 150 and int(world.state["x"]) <= 178):
		world.step_with(right)
		t += 1
	t = 0
	while String(world.state["seq"]) != "run_jump" and int(world.state["dead"]) == 0 and t < 8:
		world.step_with(jump)
		t += 1
	while String(world.state["seq"]) == "run_jump" and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(jump)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 30:
		world.step_with(neutral)
		t += 1
	t = 0
	while int(world.state["x"]) < 250 and int(world.state["row"]) == 1 \
			and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(edge_walk)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 15:
		world.step_with(neutral)
		t += 1
	t = 0
	while String(world.state["seq"]) != "hang" and int(world.state["dead"]) == 0 and t < 30:
		world.step_with(grab)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(grab)
		t += 1
	t = 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and t < 300:
		world.step_with(right)
		t += 1


## Level 2: release the echo on the plate, walk the thesis route (drop, pit,
## hang-climb), beat the skill-0 guard, walk through the held gate to the door.
func _run_level_two(world: SimWorld) -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)
	var edge_walk := PopInput.make(1, 0, 1)
	var grab := PopInput.make(0, -1, 1)
	var strike := PopInput.make(0, 0, 0, 1)

	TemporalManager.start_recording()
	var t := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 3 \
			and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(right)
		world.step_with(neutral)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 15:
		world.step_with(neutral)
		t += 1
	world.step_ticks(8, [neutral.to_byte()])
	TemporalManager.stop_recording()

	t = 0
	while int(world.state["row"]) != 1 and int(world.state["dead"]) == 0 and t < 90:
		world.step_with(right)
		t += 1
	t = 0
	while int(world.state["dead"]) == 0 and t < 60 and not (
			int(world.state["row"]) == 1
			and (String(world.state["seq"]) == "startrun" or String(world.state["seq"]) == "run_cycle")
			and int(world.state["x"]) >= 150 and int(world.state["x"]) <= 178):
		world.step_with(right)
		t += 1
	t = 0
	while String(world.state["seq"]) != "run_jump" and int(world.state["dead"]) == 0 and t < 8:
		world.step_with(jump)
		t += 1
	while String(world.state["seq"]) == "run_jump" and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(jump)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 30:
		world.step_with(neutral)
		t += 1
	t = 0
	while int(world.state["x"]) < 250 and int(world.state["row"]) == 1 \
			and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(edge_walk)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 15:
		world.step_with(neutral)
		t += 1
	t = 0
	while String(world.state["seq"]) != "hang" and int(world.state["dead"]) == 0 and t < 30:
		world.step_with(grab)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 40:
		world.step_with(grab)
		t += 1

	var guard := world.get_parent().get_node_or_null("SimGuard") as SimGuard
	t = 0
	while guard != null and int(guard.guard["dead"]) == 0 and int(world.state["dead"]) == 0 and t < 400:
		if absi(int(world.state["x"]) - guard.guard_x) <= 40:
			world.step_with(strike)
		else:
			world.step_with(right)
		t += 1
	t = 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and t < 300:
		world.step_with(right)
		t += 1


## Level 3: release the echo on the arena plate, fight the Warden with the
## tested cadence while the shield is down, walk into the exit door.
func _run_level_three(world: SimWorld) -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var boss := world.get_parent().get_node_or_null("SimBoss") as SimBoss

	TemporalManager.start_recording()
	var t := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 4 \
			and int(world.state["dead"]) == 0 and t < 60:
		world.step_with(right)
		world.step_with(neutral)
		t += 1
	t = 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t < 15:
		world.step_with(neutral)
		t += 1
	world.step_ticks(8, [neutral.to_byte()])
	TemporalManager.stop_recording()

	t = 0
	while boss != null and boss.shielded and t < 200:
		world.step_with(neutral)
		t += 1
	t = 0
	while boss != null and int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and t < 1750:
		world.step_with(_l3_cmd(boss, world))
		t += 1
	t = 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and t < 400:
		world.step_with(right)
		t += 1


## Cadence D (session 011 matrix), as in the boss suites: chase to the band,
## parry the committed swing, counter everything else.
func _l3_cmd(boss: SimBoss, world: SimWorld) -> PopInput:
	var kx := int(world.state["x"])
	if absi(kx - boss.guard_x) > 15:
		return PopInput.make(1, 0) if boss.guard_x > kx else PopInput.make(-1, 0)
	if String(boss.guard["seq"]).contains("strike"):
		return PopInput.make(0, 0, 0, 2)
	return PopInput.make(0, 0, 0, 1)


# --- The flow ---------------------------------------------------------------

func _test_title_screens() -> void:
	var menu := _menu()
	check(GameManager.state == GameManager.State.MENU and menu.visible,
		"boot lands on the title screen (state %s)" % str(GameManager.state))
	check(menu.screen_title().contains("ECHOES OF TIME"),
		"the title carries the game's name (%s)" % menu.screen_title().replace("\n", " / "))
	menu.action_requested.emit(&"controls")
	check(menu.visible and menu.screen_title() == "CONTROLS",
		"Controls opens from the title")
	check(menu.screen_body().contains("[Q] record") and menu.screen_body().contains("echo"),
		"the controls screen documents the echo verb")
	menu.action_requested.emit(&"menu")
	check(GameManager.state == GameManager.State.MENU and menu.screen_title().contains("ECHOES OF TIME"),
		"Back returns to the title")
	menu.action_requested.emit(&"credits")
	check(menu.visible and menu.screen_title() == "CREDITS",
		"Credits opens from the title")
	check(menu.screen_body().contains("inspired by the 1989 classic"),
		"the credits carry the tribute line")
	check(menu.screen_body().contains("officialarghya29/RRR"),
		"the credits carry the upstream credit")
	menu.action_requested.emit(&"menu")
	check(GameManager.state == GameManager.State.MENU and menu.visible,
		"Back from the credits returns to the title")


func _test_level_one() -> void:
	var menu := _menu()
	menu.action_requested.emit(&"start")
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"Begin the descent starts level 1 on the sim path (state %s)" % str(GameManager.state))
	if not (GameManager.player is SimPlayer):
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world
	_run_level_one(world)
	check(GameManager.state == GameManager.State.LEVEL_COMPLETE,
		"level 1 completes end to end through the scene (state %s)" % str(GameManager.state))
	check(menu.visible and menu.screen_title() == "THE MOMENT HOLDS"
			and menu.screen_body().contains("Level cleared"),
		"the level-complete screen is up (%s)" % menu.screen_title())


func _test_pause_and_checkpoint() -> void:
	var menu := _menu()
	menu.action_requested.emit(&"next_level")
	check(GameManager.state == GameManager.State.PLAYING and GameManager.current_level_index == 1,
		"Continue loads level 2 (index %d, state %s)" % [
			GameManager.current_level_index, str(GameManager.state)])
	if not (GameManager.player is SimPlayer):
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world

	GameManager.set_paused(true)
	check(GameManager.state == GameManager.State.PAUSED and menu.visible
			and menu.screen_title() == "PAUSED",
		"pausing brings up the pause screen")
	menu.action_requested.emit(&"resume")
	check(GameManager.state == GameManager.State.PLAYING and not menu.visible,
		"Resume returns to the game (state %s)" % str(GameManager.state))

	# Death reaches the shell; the death beat auto-restarts at the checkpoint
	# (GameManager's 1.1 s timer — real frames, awaited here).
	world.force_death()
	check(GameManager.state == GameManager.State.DEAD,
		"the kid's death reaches the shell (state %s)" % str(GameManager.state))
	var f := 0
	while GameManager.state == GameManager.State.DEAD and f < 400:
		await get_tree().physics_frame
		f += 1
	check(GameManager.state == GameManager.State.PLAYING,
		"the death beat restarts the kid at the checkpoint (state %s after %d frames)" % [
			str(GameManager.state), f])
	check(int(world.state["hp"]) == PopTables.KID_HP_START and int(world.state["tick"]) == 0,
		"the restarted kid is whole (hp %d, tick %d)" % [
			int(world.state["hp"]), int(world.state["tick"])])

	# And the pause menu's Restart checkpoint takes the same road on demand.
	GameManager.set_paused(true)
	menu.action_requested.emit(&"restart_checkpoint")
	check(GameManager.state == GameManager.State.PLAYING and not menu.visible
			and int(world.state["hp"]) == PopTables.KID_HP_START,
		"the pause menu's Restart checkpoint returns to play whole (state %s)" % str(GameManager.state))


func _test_level_two() -> void:
	var menu := _menu()
	if GameManager.state != GameManager.State.PLAYING or not (GameManager.player is SimPlayer):
		check(false, "level 2 is running before its scripted run")
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world
	_run_level_two(world)
	check(GameManager.state == GameManager.State.LEVEL_COMPLETE,
		"level 2 completes end to end through the scene (state %s)" % str(GameManager.state))
	check(menu.visible and menu.screen_body().contains("Level cleared"),
		"the level-complete screen is up again")


func _test_level_three_and_victory() -> void:
	var menu := _menu()
	menu.action_requested.emit(&"next_level")
	check(GameManager.state == GameManager.State.PLAYING and GameManager.current_level_index == 2,
		"Continue loads level 3 (index %d)" % GameManager.current_level_index)
	if not (GameManager.player is SimPlayer):
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world
	_run_level_three(world)
	check(GameManager.state == GameManager.State.LEVEL_COMPLETE,
		"the Warden falls and level 3 completes (state %s)" % str(GameManager.state))
	check(menu.visible and menu.screen_title() == "THE PALACE REMEMBERS"
			and menu.screen_body().contains("Echoes of Time"),
		"the victory screen is up on the last level")
	menu.action_requested.emit(&"menu")
	check(GameManager.state == GameManager.State.MENU
			and menu.screen_title().contains("ECHOES OF TIME"),
		"Abandon to menu returns to the title (state %s)" % str(GameManager.state))
