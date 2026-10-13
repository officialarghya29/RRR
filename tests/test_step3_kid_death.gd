# Session 012 step 3 — kid dies mid-fight: the echo keeps its position, the
# shield is recomputed from the live echo state, and the level stays
# completable.
#
# Contract (the behaviour this suite pins): the temporal echo is an
# INDEPENDENT participant — the kid's death (the shared force_death() /
# apply_duel_hit path) and the checkpoint respawn do NOT clear it. It ends of
# its own lifetime, of a fresh take over the echo cap, or of level teardown.
# The tests run the kid through the real sim, kill him at a known shield
# state through the real duel-damage request path, respawn through the scene
# (GameManager.respawn_at_checkpoint), and then prove the echo/shield state
# and an end-to-end completion.
#
# Scenario matrix on level 3 (the Time Warden, echo-gated shield):
#   (a) death with NO echo ever released — the kid's own plate press never
#       counts; the shield is UP through death, respawn and resume.
#   (b) death WHILE the echo holds the plate — the echo survives the death
#       and the respawn; the shield stays DOWN; the resumed fight wins.
#   (c) death AFTER the echo expired — the shield came back UP; a fresh
#       take + echo resumes the level to completion.
# and on level 2 (scenario d): the kid dies MID-DUEL, the echo keeps
# pressing the plate and the held gate re-parks right after the respawn.
#
# FAIRNESS AND DIFFICULTY ARE NOT VERIFIED — needs human playtest (same
# disclaimer the level-2/level-3 suites carry).

extends Node

var _passed: int = 0
var _failed: int = 0
## Arena host for the multi-seed invariant test (worlds + bosses, freed per
## seed — the scene-based tests above run through GameManager instead).
var _sandbox: Node2D = null


func _ready() -> void:
	_sandbox = Node2D.new()
	_sandbox.name = "Step3Sandbox"
	add_child(_sandbox)
	await get_tree().physics_frame

	_section("Level 3 death timings — the echo outlives the kid (S012 step 3)")
	await _test_b23_death_timings()

	_section("Level 2 death mid-duel — echo and held gate survive (S012 step 3, d)")
	_test_b13_death_mid_duel()

	_section("Respawn economy — energy and capacity across death/expiry (S012 step 2)")
	await _test_b23_respawn_economy()

	_section("Multi-seed death invariants — contract over many RNG phases (S012 step 2)")
	_test_b23_multi_seed_deaths()

	_finish()


# --- Harness (mirrors tests/test_main.gd's output contract) -----------------

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


# --- Shared helpers ---------------------------------------------------------

## One neutral logic tick (keeps the shield/duel ticking without moving).
func _l3_neutral(w: SimWorld) -> void:
	w.step_with(PopInput.neutral())


## Adaptive fight command (characterization, session 011 matrix cadence D):
## chase the Warden to the duel band (abs <= 15 — opp = abs + FRONT_OFFSET
## must be < HIT_MAX 29), block only his committed swings (the kid's parry
## frames eat them) and counter everything else. At the pinned duel seed
## this lands 5 hits before the kid's third incoming — the only tested
## configuration that beats the pool while surviving. Returning a WALK input
## while apart keeps the kid from walking PAST the boss toward the exit
## (measured: an abs-only script overshoots).
func _l3_cmd(boss: SimBoss, world: SimWorld) -> PopInput:
	var kx := int(world.state["x"])
	if absi(kx - boss.guard_x) > 15:
		return PopInput.make(1, 0) if boss.guard_x > kx else PopInput.make(-1, 0)
	if String(boss.guard["seq"]).contains("strike"):
		return PopInput.make(0, 0, 0, 2)   # parry the committed swing
	return PopInput.make(0, 0, 0, 1)      # counter everything else


## Fresh level 3 through the real scene. Returns [world, boss] — nulls when
## the scene did not build (the caller bails like the other suites do).
func _l3_arena() -> Array:
	GameManager.load_level(2)
	if not (GameManager.player is SimPlayer):
		return [null, null]
	var world: SimWorld = (GameManager.player as SimPlayer).world
	var boss := world.get_parent().get_node_or_null("SimBoss") as SimBoss
	return [world, boss]


## Walk into the Warden's ACTIVATION range and settle to a stand, short of
## the duel band. The kid must NOT chase into the band at speed: the
## strike band is opp = abs + 13 in [12, 29), i.e. abs in [-1, 16) while
## both fighters face each other, and the Warden's advance chains have no
## collision in the duel abstraction — a close approached at speed ends
## with him walked THROUGH the kid, after which opp goes negative and the
## reference guard keeps walking away forever (measured in scenario (a)).
func _l3_approach(world: SimWorld, boss: SimBoss) -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var t1 := 0
	while absi(int(world.state["x"]) - boss.guard_x) > 60 \
			and int(world.state["dead"]) == 0 and t1 < 400:
		world.step_with(right)
		t1 += 1
	var t2 := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t2 < 15:
		world.step_with(neutral)
		t2 += 1


## Tap-walk from wherever the kid stands onto the level-3 plate at col 4,
## settle to a stand and hold — the take the echo will replay (the same
## script the level-3 suite records).
func _record_plate_take(world: SimWorld) -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var t1 := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 4 \
			and int(world.state["dead"]) == 0 and t1 < 60:
		world.step_with(right)
		world.step_with(neutral)
		t1 += 1
	var t1b := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t1b < 15:
		world.step_with(neutral)
		t1b += 1
	world.step_ticks(8, [neutral.to_byte()])


# --- Level 3: death timings (S012 step 3) -----------------------------------

func _test_b23_death_timings() -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var strike := PopInput.make(0, 0, 0, 1)   # special bit 1 = duel strike

	# --- (0) the scene spawns the boss from the level data ---------------
	GameManager.load_level(2)
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"level 3 loads on the sim path through the real scene (state %s)" % str(GameManager.state))
	if not (GameManager.player is SimPlayer):
		GameManager.return_to_menu()
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world
	var boss := world.get_parent().get_node_or_null("SimBoss") as SimBoss
	check(boss != null and boss.skill == 4 and boss.shielded
			and int(boss.guard["hp"]) == SimBoss.BOSS_HP,
		"level 3 spawns the high-skill Warden shielded with the boss pool (skill %d, shield %s, hp %d)" % [
			boss.skill if boss != null else -1, str(boss.shielded) if boss != null else "?",
			int(boss.guard["hp"]) if boss != null else -1])
	if boss == null:
		GameManager.return_to_menu()
		return
	GameManager.return_to_menu()

	# ---- (a) death with the shield UP and no echo ever released ---------
	# The kid walks his own happy path into the Warden's band — over the
	# arena plate (his own press never counts for the shield) — with no
	# take ever released. Nothing can hold the plate, so the shield is UP
	# at the death and stays UP through the respawn; the level still
	# completes via a fresh take + echo.
	var arena: Array = _l3_arena()
	if arena[0] == null or arena[1] == null:
		check(false, "death (a): the scene builds the level-3 arena")
		GameManager.return_to_menu()
		return
	world = arena[0] as SimWorld
	boss = arena[1] as SimBoss
	var died := [false]
	var completed := [false]
	var on_died := func() -> void: died[0] = true
	var on_done := func(_id: StringName) -> void: completed[0] = true
	EventBus.player_died.connect(on_died)
	EventBus.level_completed.connect(on_done)

	# Walk into the Warden's ACTIVATION range but stop well short of the
	# duel band. The duel's strike band is opp = abs + 13 in [12, 29), i.e.
	# abs in [-1, 16) while both fighters face each other — and the kid must
	# NOT chase into it: the Warden's advance chains have no collision in the
	# duel abstraction, so a close approached at speed ends with him walked
	# THROUGH the kid; the kid's back is then turned, opp goes negative and
	# the reference guard keeps walking away forever (measured: 300 ticks of
	# g:advance to x 127). The kid stops at abs ~60 and lets the Warden close
	# the last stretch himself — he parks in the band and strikes.
	var a1 := 0
	while absi(int(world.state["x"]) - boss.guard_x) > 60 \
			and int(world.state["dead"]) == 0 and a1 < 400:
		world.step_with(right)
		a1 += 1
	check(absi(int(world.state["x"]) - boss.guard_x) <= 60,
		"death (a): the kid walks into the Warden's activation range (abs %d after %d ticks)" % [
			absi(int(world.state["x"]) - boss.guard_x), a1])
	var a1b := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and a1b < 15:
		world.step_with(neutral)
		a1b += 1
	# The Warden attacks an undefended (neutral) kid — first blood proves the
	# duel is live; the shield stays up (no echo), and the kid's own strikes
	# could never hurt the boss anyway (every point is absorbed).
	var a_hp := int(world.state["hp"])
	var a2 := 0
	while int(world.state["hp"]) == a_hp and int(world.state["dead"]) == 0 and a2 < 300:
		_l3_neutral(world)
		a2 += 1
	check(int(world.state["hp"]) < a_hp and int(world.state["dead"]) == 0,
		"death (a): the shielded Warden's first hit lands on the undefended kid (hp %d after %d ticks)" % [
			int(world.state["hp"]), a2])
	# The test takes his life mid-fight through the real duel-damage path —
	# the same request SimGuard issues; the next tick's diff publishes the
	# death (SimWorld._publish -> EventBus.player_died -> this scene).
	world.apply_duel_hit(int(world.state["hp"]))
	_l3_neutral(world)
	check(int(world.state["dead"]) == 1 and int(world.state["hp"]) == 0 and died[0],
		"death (a): the kid dies mid-fight (dead %d, hp %d, player_died %s)" % [
			int(world.state["dead"]), int(world.state["hp"]), str(died[0])])
	check(int(boss.guard["dead"]) == 0,
		"death (a): the Warden is still alive after the kid's death (boss dead %d)" % int(boss.guard["dead"]))

	# Respawn through the scene (the checkpoint respawn: fresh state, fresh
	# clock, PLAYING again — the shell state the death left behind is the
	# scene's job to restore, not the world's).
	GameManager.respawn_at_checkpoint()
	check(GameManager.state == GameManager.State.PLAYING \
			and int(world.state["tick"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"death (a): the checkpoint respawn restores the kid (tick %d, hp %d, state %s)" % [
			int(world.state["tick"]), int(world.state["hp"]), str(GameManager.state)])
	check(TemporalManager.active_sim_echoes().size() == 0,
		"death (a): no echo exists — none was ever released (echoes %d)" % \
			TemporalManager.active_sim_echoes().size())
	_l3_neutral(world)
	check(boss.shielded,
		"death (a): the shield is still UP after the respawn (echoes %d, shielded %s)" % [
			TemporalManager.active_sim_echoes().size(), str(boss.shielded)])
	# Resume: a fresh take drops the shield; the kid then FIGHTS through the
	# wait — the Warden may still be near his death-spot post, and standing
	# undefended while the echo walks to the plate is how he got slain once.
	# (Cadence D parries the committed swings, so the wait costs nothing.)
	check(TemporalManager.start_recording(), "death (a): the re-take begins")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"death (a): the fresh take releases the echo (count %d)" % TemporalManager.echo_count())
	var a_shield := -1
	var a5 := 0
	while int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and a5 < 1750:
		world.step_with(_l3_cmd(boss, world))
		if a_shield < 0 and not boss.shielded:
			a_shield = a5
		a5 += 1
	check(a_shield >= 0,
		"death (a): the fresh echo drops the shield (after %d ticks)" % a_shield)
	check(int(boss.guard["dead"]) != 0,
		"death (a): the Warden falls in the resumed fight (after %d fight ticks)" % a5)
	var a6 := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and a6 < 400:
		world.step_with(right)
		a6 += 1
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE \
			and int(world.state["dead"]) == 0,
		"death (a): the level completes after the respawn (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), a6])
	EventBus.player_died.disconnect(on_died)
	EventBus.level_completed.disconnect(on_done)
	GameManager.return_to_menu()

	# ---- (b) kill the kid WHILE the echo holds the plate (shield DOWN) --
	# The echo is an independent participant: it keeps pressing the plate
	# even after the kid dies, and the shield stays DOWN after the respawn
	# because the echo is still living. The boss falls in the resumed fight
	# and the level still completes.
	arena = _l3_arena()
	if arena[0] == null or arena[1] == null:
		check(false, "death (b): the scene builds the level-3 arena")
		GameManager.return_to_menu()
		return
	world = arena[0] as SimWorld
	boss = arena[1] as SimBoss
	died = [false]
	completed = [false]
	on_died = func() -> void: died[0] = true
	on_done = func(_id: StringName) -> void: completed[0] = true
	EventBus.player_died.connect(on_died)
	EventBus.level_completed.connect(on_done)

	check(TemporalManager.start_recording(), "death (b): the take begins at spawn")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"death (b): the release spawns the echo (count %d)" % TemporalManager.echo_count())
	var b2 := 0
	while boss.shielded and b2 < 200:
		_l3_neutral(world)
		b2 += 1
	check(not boss.shielded,
		"death (b): the echo's stance drops the shield (after %d ticks)" % b2)
	# Walk into the band — the echo stands on the plate behind him.
	var b_a1 := 0
	while absi(int(world.state["x"]) - boss.guard_x) > 15 \
			and int(world.state["dead"]) == 0 and b_a1 < 400:
		world.step_with(right)
		b_a1 += 1
	check(absi(int(world.state["x"]) - boss.guard_x) <= 15,
		"death (b): the kid walks into the Warden's band (abs %d after %d ticks)" % [
			absi(int(world.state["x"]) - boss.guard_x), b_a1])
	# The Warden attacks an undefended (neutral) kid — first blood proves the
	# duel is live while the shield is DOWN.
	var b_hp := int(world.state["hp"])
	var b3 := 0
	while int(world.state["hp"]) == b_hp and int(world.state["dead"]) == 0 and b3 < 300:
		_l3_neutral(world)
		b3 += 1
	check(int(world.state["hp"]) < b_hp and int(world.state["dead"]) == 0,
		"death (b): the Warden's first hit lands on the undefended kid (hp %d after %d ticks)" % [
			int(world.state["hp"]), b3])
	world.apply_duel_hit(int(world.state["hp"]))
	_l3_neutral(world)
	check(int(world.state["dead"]) == 1 and int(world.state["hp"]) == 0 and died[0],
		"death (b): the kid dies mid-fight with the echo holding (dead %d, hp %d, player_died %s)" % [
			int(world.state["dead"]), int(world.state["hp"]), str(died[0])])
	check(int(boss.guard["dead"]) == 0,
		"death (b): the Warden is still alive after the kid's death (boss dead %d)" % int(boss.guard["dead"]))

	GameManager.respawn_at_checkpoint()
	check(GameManager.state == GameManager.State.PLAYING \
			and int(world.state["tick"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"death (b): the checkpoint respawn restores the kid (tick %d, hp %d, state %s)" % [
			int(world.state["tick"]), int(world.state["hp"]), str(GameManager.state)])
	check(died[0] and TemporalManager.active_sim_echoes().size() == 1,
		"death (b): the echo survived the death AND the respawn — the echo is not tied to the kid's life (echoes %d)" % \
			TemporalManager.active_sim_echoes().size())
	_l3_neutral(world)
	check(not boss.shielded,
		"death (b): the shield is STILL DOWN after the respawn (echoes %d, shielded %s)" % [
			TemporalManager.active_sim_echoes().size(), str(boss.shielded)])
	var b4 := 0
	while int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and b4 < 1750:
		world.step_with(_l3_cmd(boss, world))
		b4 += 1
	check(int(boss.guard["dead"]) != 0,
		"death (b): the Warden falls in the resumed fight (after %d fight ticks)" % b4)
	var b5 := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and b5 < 400:
		world.step_with(right)
		b5 += 1
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE \
			and int(world.state["dead"]) == 0,
		"death (b): the level completes after the respawn (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), b5])
	EventBus.player_died.disconnect(on_died)
	EventBus.level_completed.disconnect(on_done)
	GameManager.return_to_menu()

	# ---- (c) kill the kid AFTER the echo has EXPIRED (shield UP) --------
	# The echo's own lifetime ends it (the production expiry path), the
	# shield comes back UP on the next logic tick, and then the kid dies.
	# The death breaks nothing: a fresh take + echo resumes the level.
	arena = _l3_arena()
	if arena[0] == null or arena[1] == null:
		check(false, "death (c): the scene builds the level-3 arena")
		GameManager.return_to_menu()
		return
	world = arena[0] as SimWorld
	boss = arena[1] as SimBoss
	died = [false]
	completed = [false]
	on_died = func() -> void: died[0] = true
	on_done = func(_id: StringName) -> void: completed[0] = true
	EventBus.player_died.connect(on_died)
	EventBus.level_completed.connect(on_done)

	check(TemporalManager.start_recording(), "death (c): the take begins at spawn")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"death (c): the release spawns the echo (count %d)" % TemporalManager.echo_count())
	var c2 := 0
	while boss.shielded and c2 < 200:
		_l3_neutral(world)
		c2 += 1
	check(not boss.shielded,
		"death (c): the echo's stance drops the shield (after %d ticks)" % c2)
	# Force the echo's lifetime to elapse. The production expiry path runs in
	# _physics_process (decrements _life_left), so let the frames run.
	for echo: TemporalEcho in TemporalManager.active_sim_echoes():
		echo._life_left = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(TemporalManager.echo_count() == 0,
		"death (c): the echo expires on its lifetime (echoes %d)" % TemporalManager.echo_count())
	_l3_neutral(world)
	check(boss.shielded,
		"death (c): the shield is UP again once the echo is gone (shielded %s)" % str(boss.shielded))
	var c_a1 := 0
	while absi(int(world.state["x"]) - boss.guard_x) > 15 \
			and int(world.state["dead"]) == 0 and c_a1 < 400:
		world.step_with(right)
		c_a1 += 1
	check(absi(int(world.state["x"]) - boss.guard_x) <= 15,
		"death (c): the kid walks into the Warden's band (abs %d after %d ticks)" % [
			absi(int(world.state["x"]) - boss.guard_x), c_a1])
	var c_hp := int(world.state["hp"])
	var c3 := 0
	while int(world.state["hp"]) == c_hp and int(world.state["dead"]) == 0 and c3 < 300:
		world.step_with(strike)
		c3 += 1
	check(int(world.state["hp"]) < c_hp and int(world.state["dead"]) == 0,
		"death (c): the shielded Warden counters the unblocked kid (hp %d after %d ticks)" % [
			int(world.state["hp"]), c3])
	world.apply_duel_hit(int(world.state["hp"]))
	_l3_neutral(world)
	check(int(world.state["dead"]) == 1 and int(world.state["hp"]) == 0 and died[0],
		"death (c): the kid dies with the shield up (dead %d, hp %d, player_died %s)" % [
			int(world.state["dead"]), int(world.state["hp"]), str(died[0])])
	check(int(boss.guard["dead"]) == 0,
		"death (c): the Warden is still alive after the kid's death (boss dead %d)" % int(boss.guard["dead"]))

	GameManager.respawn_at_checkpoint()
	check(GameManager.state == GameManager.State.PLAYING \
			and int(world.state["tick"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"death (c): the checkpoint respawn restores the kid (tick %d, hp %d, state %s)" % [
			int(world.state["tick"]), int(world.state["hp"]), str(GameManager.state)])
	check(TemporalManager.active_sim_echoes().size() == 0,
		"death (c): the echo had expired before the death — nothing lives on (echoes %d)" % \
			TemporalManager.active_sim_echoes().size())
	_l3_neutral(world)
	check(boss.shielded,
		"death (c): the shield is still UP after the respawn (no echo held it)")
	check(TemporalManager.start_recording(), "death (c): the re-take begins")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"death (c): the fresh take releases the echo (count %d)" % TemporalManager.echo_count())
	# Fight through the shield-drop wait — the Warden may already be near
	# his post again, and an undefended kid waiting to die was measured in
	# scenario (a)'s first draft.
	var c_shield := -1
	var c6 := 0
	while int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and c6 < 1750:
		world.step_with(_l3_cmd(boss, world))
		if c_shield < 0 and not boss.shielded:
			c_shield = c6
		c6 += 1
	check(c_shield >= 0,
		"death (c): the fresh echo drops the shield (after %d ticks)" % c_shield)
	check(int(boss.guard["dead"]) != 0,
		"death (c): the Warden falls in the resumed fight (after %d fight ticks)" % c6)
	var c7 := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and c7 < 400:
		world.step_with(right)
		c7 += 1
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE \
			and int(world.state["dead"]) == 0,
		"death (c): the level completes after the respawn (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), c7])
	EventBus.player_died.disconnect(on_died)
	EventBus.level_completed.disconnect(on_done)
	GameManager.return_to_menu()


# --- Level 2: death mid-duel (S012 step 3, scenario d) ----------------------

## (d) The kid dies MID-DUEL, with the echo still pressing the level-2
## plate and the level-2 gate parked open. Assertions: the state is clean
## (respawn restores the kid), the echo is untouched by the death, the held
## gate re-parks right after the respawn, and the duel + exit still complete.
func _test_b13_death_mid_duel() -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)
	var edge_walk := PopInput.make(1, 0, 1)
	var grab := PopInput.make(0, -1, 1)
	var strike := PopInput.make(0, 0, 0, 1)

	# (0) the scene builds the Hall of Echoes on the sim path
	GameManager.load_level(1)
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"level 2 loads on the sim path through the real scene (state %s)" % str(GameManager.state))
	if not (GameManager.player is SimPlayer):
		GameManager.return_to_menu()
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world
	var guard := world.get_parent().get_node_or_null("SimGuard") as SimGuard
	check(guard != null and guard.skill == 0,
		"level 2 spawns the skill-0 guard (skill %d)" % (guard.skill if guard != null else -1))
	if guard == null:
		GameManager.return_to_menu()
		return

	var events: Array = []
	var checkpoints: Array = []
	var completed := [false]
	var died := [false]
	var on_ent := func(kind: StringName, key: String) -> void: events.append("%s:%s" % [String(kind), key])
	var on_cp := func(id: StringName) -> void: checkpoints.append(String(id))
	var on_done := func(_id: StringName) -> void: completed[0] = true
	var on_died := func() -> void: died[0] = true
	EventBus.sim_entity_event.connect(on_ent)
	EventBus.checkpoint_reached.connect(on_cp)
	EventBus.level_completed.connect(on_done)
	EventBus.player_died.connect(on_died)

	# (1) record on the level-2 plate (col 3) and release — the echo holds
	# the gate open while the kid walks the thesis route to the duel.
	check(TemporalManager.start_recording(), "l2 death: the take begins at spawn")
	var e1 := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 3 \
			and int(world.state["dead"]) == 0 and e1 < 40:
		world.step_with(right)
		world.step_with(neutral)
		e1 += 1
	check(PopSim._col_of(PopSim._foot_x(world.state)) == 3,
		"l2 death: the kid walks onto the plate (foot col %d)" % PopSim._col_of(PopSim._foot_x(world.state)))
	var e1b := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and e1b < 15:
		world.step_with(neutral)
		e1b += 1
	world.step_ticks(8, [neutral.to_byte()])
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"l2 death: the release spawns the echo (count %d)" % TemporalManager.echo_count())

	# (2) the route: drop off the start floor, run-jump the pit, hang-climb
	# the ledge — the gate-5 phases, same geometry — then the duel.
	var r1 := 0
	while int(world.state["row"]) != 1 and int(world.state["dead"]) == 0 and r1 < 90:
		world.step_with(right)
		r1 += 1
	var r2 := 0
	while int(world.state["dead"]) == 0 and r2 < 60 and not (
			int(world.state["row"]) == 1
			and (String(world.state["seq"]) == "startrun" or String(world.state["seq"]) == "run_cycle")
			and int(world.state["x"]) >= 150 and int(world.state["x"]) <= 178):
		world.step_with(right)
		r2 += 1
	var r3 := 0
	while String(world.state["seq"]) != "run_jump" and int(world.state["dead"]) == 0 and r3 < 8:
		world.step_with(jump)
		r3 += 1
	while String(world.state["seq"]) == "run_jump" and int(world.state["dead"]) == 0 and r3 < 40:
		world.step_with(jump)
		r3 += 1
	check(int(world.state["row"]) == 1 and int(world.state["dead"]) == 0 and int(world.state["x"]) > 198,
		"l2 death: the jump clears the spike pit (x %d row %d dead %d)" % [
			int(world.state["x"]), int(world.state["row"]), int(world.state["dead"])])
	var r4 := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and r4 < 30:
		world.step_with(neutral)
		r4 += 1
	var r5 := 0
	while int(world.state["x"]) < 250 and int(world.state["row"]) == 1 \
			and int(world.state["dead"]) == 0 and r5 < 40:
		world.step_with(edge_walk)
		r5 += 1
	var r5b := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and r5b < 15:
		world.step_with(neutral)
		r5b += 1
	var r6 := 0
	while String(world.state["seq"]) != "hang" and int(world.state["dead"]) == 0 and r6 < 30:
		world.step_with(grab)
		r6 += 1
	var r7 := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and r7 < 40:
		world.step_with(grab)
		r7 += 1
	check(int(world.state["row"]) == 0 and int(world.state["dead"]) == 0,
		"l2 death: the climb-out stands on the ledge (row %d, dead %d)" % [
			int(world.state["row"]), int(world.state["dead"])])
	check(checkpoints.has("ground") and checkpoints.has("ledge"),
		"l2 death: both position triggers fired on the way (got %s)" % str(checkpoints))

	# (3) the duel: walk into range and fight. First blood on either side
	# proves the duel is live; MIDWAY the test takes the kid's life through
	# the real duel-damage path (the same request SimGuard issues) — the
	# duel's own winner does not matter to this contract, the guard must
	# simply outlive the kid's death.
	var kid_hp0 := int(world.state["hp"])
	var guard_hp0 := int(guard.guard["hp"])
	var d1 := 0
	while int(world.state["hp"]) == kid_hp0 and int(guard.guard["hp"]) == guard_hp0 \
			and int(world.state["dead"]) == 0 and int(guard.guard["dead"]) == 0 and d1 < 400:
		if absi(int(world.state["x"]) - guard.guard_x) <= 40:
			world.step_with(strike)
		else:
			world.step_with(right)
		d1 += 1
	check(int(world.state["hp"]) < kid_hp0 or int(guard.guard["hp"]) < guard_hp0,
		"l2 death: the duel is live — first blood before the kill (kid hp %d, guard hp %d after %d ticks)" % [
			int(world.state["hp"]), int(guard.guard["hp"]), d1])
	world.apply_duel_hit(int(world.state["hp"]))
	world.step_with(neutral)   # the death publishes on this tick's diff
	check(int(world.state["dead"]) == 1 and int(world.state["hp"]) == 0 and died[0],
		"l2 death: the kid dies mid-duel (dead %d, hp %d, player_died %s)" % [
			int(world.state["dead"]), int(world.state["hp"]), str(died[0])])
	check(int(guard.guard["dead"]) == 0,
		"l2 death: the guard outlives the kid's death (guard dead %d)" % int(guard.guard["dead"]))

	# (4) the death touches neither the echo nor the puzzle: the echo keeps
	# pressing the plate (the gate re-parks gradually behind this walk —
	# checked in (6), the same r8 instrumentation the level-2 suite uses).
	GameManager.respawn_at_checkpoint()
	check(GameManager.state == GameManager.State.PLAYING \
			and int(world.state["tick"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"l2 death: the checkpoint respawn restores the kid (tick %d, hp %d, state %s)" % [
			int(world.state["tick"]), int(world.state["hp"]), str(GameManager.state)])
	check(died[0] and TemporalManager.active_sim_echoes().size() >= 1,
		"l2 death: the echo survived the death and the respawn (echoes %d)" % \
			TemporalManager.active_sim_echoes().size())
	var presses_before := 0
	for e: String in events:
		if e == "press:0,3":
			presses_before += 1
	world.step_with(neutral)
	var presses_after := 0
	for e: String in events:
		if e == "press:0,3":
			presses_after += 1
	check(presses_after > presses_before,
		"l2 death: the echo re-presses the plate on the first post-respawn tick (presses %d -> %d)" % [
			presses_before, presses_after])

	# (5) the resumed duel: same guard, same cadence — he still falls.
	var d2 := 0
	while int(guard.guard["dead"]) == 0 and int(world.state["dead"]) == 0 and d2 < 400:
		if absi(int(world.state["x"]) - guard.guard_x) <= 40:
			world.step_with(strike)
		else:
			world.step_with(right)
		d2 += 1
	check(int(guard.guard["dead"]) != 0,
		"l2 death: the guard still falls after the respawn (dead %d after %d ticks)" % [
			int(guard.guard["dead"]), d2])

	# (6) walk through the gate — open again via the echo's held-plate re-
	# park — into the exit door; the loop ends when the SCENE completes the
	# level (exit_reached -> complete_level). Gate instrumentation mirrors
	# the level-2 suite's r8: it opens and never closes while the echo holds.
	var first_open := -1
	var closed_after_open := false
	var d3 := 0
	while GameManager.state == GameManager.State.PLAYING \
			and int(world.state["dead"]) == 0 and d3 < 300:
		world.step_with(right)
		var gate_mod := int((world.state["gates"]["0,20"] as Dictionary)["mod"])
		if first_open >= 0 and gate_mod < PopTables.GATE_OPEN_THRESHOLD:
			closed_after_open = true
		if first_open < 0 and gate_mod >= PopTables.GATE_OPEN_THRESHOLD:
			first_open = d3
		d3 += 1
	check(first_open >= 0 and not closed_after_open,
		"l2 death: the echo re-parks the gate and it never closes again (first open tick %d)" % first_open)
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE \
			and int(world.state["dead"]) == 0,
		"l2 death: the run completes end to end after the death + respawn (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), d3])

	EventBus.sim_entity_event.disconnect(on_ent)
	EventBus.checkpoint_reached.disconnect(on_cp)
	EventBus.level_completed.disconnect(on_done)
	EventBus.player_died.disconnect(on_died)
	GameManager.return_to_menu()


# --- Respawn economy (S012 step 2 / D19) ------------------------------------

## D19's economy clause, pinned end to end through the scene: the budget is
## refilled on every respawn, capacity is enforced at spawn time only, an
## EXPIRED echo is not resurrected by a restart-from-checkpoint, and a LIVE
## echo survives the death + respawn and then yields its slot to the next
## take (count stays at the cap, never above it).
func _test_b23_respawn_economy() -> void:
	var arena: Array = _l3_arena()
	if arena[0] == null or arena[1] == null:
		check(false, "economy: the scene builds the level-3 arena")
		GameManager.return_to_menu()
		return
	var world: SimWorld = arena[0] as SimWorld
	var boss: SimBoss = arena[1] as SimBoss
	var died := [false]
	var on_died := func() -> void: died[0] = true
	EventBus.player_died.connect(on_died)

	# Take 1: the release charges the budget.
	check(TemporalManager.start_recording(), "economy: take 1 begins")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"economy: take 1 releases one echo (count %d)" % TemporalManager.echo_count())
	check(is_equal_approx(TemporalManager.energy,
			TemporalManager.config.energy_max - TemporalManager.config.energy_cost_per_echo),
		"economy: the release charges the take (energy %s)" % str(TemporalManager.energy))

	# The echo expires on its lifetime (the production path: _physics_process).
	for echo: TemporalEcho in TemporalManager.active_sim_echoes():
		echo._life_left = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(TemporalManager.echo_count() == 0,
		"economy: the echo expires on its lifetime (count %d)" % TemporalManager.echo_count())

	# A restart-from-checkpoint AFTER the expiry (no death involved): the
	# expired echo stays gone, the budget refills, and the shield reads the
	# live echo state — none standing on the plate means UP.
	GameManager.respawn_at_checkpoint()
	check(GameManager.state == GameManager.State.PLAYING \
			and int(world.state["tick"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"economy: the expiry restart restores the kid (tick %d, hp %d)" % [
			int(world.state["tick"]), int(world.state["hp"])])
	check(TemporalManager.echo_count() == 0,
		"economy: the restart does not resurrect the expired echo (count %d)" % \
			TemporalManager.echo_count())
	check(is_equal_approx(TemporalManager.energy, TemporalManager.config.energy_max),
		"economy: the restart refills the budget (energy %s)" % str(TemporalManager.energy))
	_l3_neutral(world)
	check(boss.shielded,
		"economy: the shield reads the live echo state after the restart (UP, echoes %d)" % \
			TemporalManager.echo_count())
	check(TemporalManager.start_recording(), "economy: the refilled budget starts a new take")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"economy: the new take releases (count %d)" % TemporalManager.echo_count())

	# Death while the echo holds, then the checkpoint respawn: the echo
	# survives AND the budget refills again.
	_l3_approach(world, boss)
	var hp0 := int(world.state["hp"])
	var w1 := 0
	while int(world.state["hp"]) == hp0 and int(world.state["dead"]) == 0 and w1 < 600:
		_l3_neutral(world)
		w1 += 1
	world.apply_duel_hit(int(world.state["hp"]))
	_l3_neutral(world)
	check(int(world.state["dead"]) == 1 and died[0],
		"economy: the kid dies mid-fight with the echo holding (dead %d, player_died %s)" % [
			int(world.state["dead"]), str(died[0])])
	GameManager.respawn_at_checkpoint()
	check(TemporalManager.echo_count() == 1,
		"economy: the echo survived the death and the respawn (count %d)" % \
			TemporalManager.echo_count())
	check(is_equal_approx(TemporalManager.energy, TemporalManager.config.energy_max),
		"economy: the respawn refills the budget again (energy %s)" % str(TemporalManager.energy))

	# Capacity: a second live echo replaces the oldest AT SPAWN — the count
	# stays at the configured cap, never above it.
	check(TemporalManager.start_recording(),
		"economy: the refilled budget buys a second take while the first echo lives")
	_record_plate_take(world)
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == int(TemporalManager.config.max_active_echoes),
		"economy: capacity is enforced across the respawn (count %d, cap %d)" % [
			TemporalManager.echo_count(), int(TemporalManager.config.max_active_echoes)])
	check(is_equal_approx(TemporalManager.energy,
			TemporalManager.config.energy_max - TemporalManager.config.energy_cost_per_echo),
		"economy: the second release charges the take again (energy %s)" % str(TemporalManager.energy))

	EventBus.player_died.disconnect(on_died)
	GameManager.return_to_menu()


# --- Multi-seed death invariants (S012 step 2 / D19 note) -------------------

## Pinned duel outcomes at the shipped seeds characterize ONE RNG phase, so
## this test asserts the step-3 CONTRACT across many duel seeds — never exact
## outcomes: the take releases, the shield follows the live echo state, the
## duel goes live, the death publishes, the echo survives death+respawn, no
## phantom hits land on the resurrected kid, and the level stays completable
## (bounded retries allowed: at an arbitrary phase the scripted cadence may
## lose a given attempt — that is not a contract violation).
func _test_b23_multi_seed_deaths() -> void:
	var neutral := PopInput.neutral()
	var right := PopInput.make(1, 0)
	var data: Dictionary = LevelCatalog.get_sim_level(2)
	var bundle: Dictionary = {
		"tiles": data["tiles"],
		"mods": data.get("mods", {}),
		"entities": data.get("entities", {}),
	}
	var spawn_px: Vector2 = data["spawn"]
	var gdata: Dictionary = ((data["enemies"] as Dictionary)["guards"] as Array)[0]
	var plate_key := String((((data["entities"] as Dictionary)["plates"] as Dictionary).keys())[0])
	var plate_col := int(plate_key.split(",")[1])
	TemporalManager.set_echo_container(_sandbox)

	for i: int in range(20):
		var seed_n := int(data["seed"]) + i
		TemporalManager.configure_for_level(data.get("temporal", {}))
		TemporalManager.clear_echoes()
		var world := SimWorld.new()
		world.name = "SeedWorld%d" % i
		_sandbox.add_child(world)
		world.setup(bundle, seed_n, spawn_px, data.get("checkpoints", []))
		var boss := SimBoss.new()
		boss.name = "SeedBoss%d" % i
		_sandbox.add_child(boss)
		boss.setup_boss(world, int(gdata["x_sim"]), int(gdata["skill"]),
			seed_n + int(gdata.get("seed_offset", 0)), plate_key)
		var died := [false]
		var on_died := func() -> void: died[0] = true
		EventBus.player_died.connect(on_died)

		# The take: walk onto the arena plate, settle, hold, release.
		var started := TemporalManager.start_recording()
		var t1 := 0
		while PopSim._col_of(PopSim._foot_x(world.state)) != plate_col \
				and int(world.state["dead"]) == 0 and t1 < 60:
			world.step_with(right)
			world.step_with(neutral)
			t1 += 1
		var t1b := 0
		while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and t1b < 15:
			world.step_with(neutral)
			t1b += 1
		world.step_ticks(8, [neutral.to_byte()])
		TemporalManager.stop_recording()
		var ok_take := started and TemporalManager.echo_count() == 1 \
				and PopSim._col_of(PopSim._foot_x(world.state)) == plate_col

		# The echo's stance drops the shield.
		var t2 := 0
		while boss.shielded and t2 < 200:
			world.step_with(neutral)
			t2 += 1
		var ok_shield_down := not boss.shielded

		# The duel goes live, then the test takes the kid's life mid-fight.
		_l3_approach(world, boss)
		var hp0 := int(world.state["hp"])
		var t3 := 0
		while int(world.state["hp"]) == hp0 and int(world.state["dead"]) == 0 and t3 < 600:
			world.step_with(neutral)
			t3 += 1
		var ok_duel_live := not (boss.transcript as Array).is_empty()
		world.apply_duel_hit(int(world.state["hp"]))
		world.step_with(neutral)
		var ok_death := int(world.state["dead"]) == 1 and int(world.state["hp"]) == 0 and bool(died[0])
		var ok_boss_alive := int(boss.guard["dead"]) == 0

		# The contract after death + respawn (the respawned signal re-arms
		# the duel-side kid mirror — no phantom hits from the previous life).
		var ok_echo_after := TemporalManager.echo_count() == 1
		world.respawn_at(spawn_px)
		var ok_restore := int(world.state["hp"]) == PopTables.KID_HP_START \
				and int(world.state["tick"]) == 0 and int(world.state["dead"]) == 0
		var t4 := 0
		while t4 < 30:
			world.step_with(neutral)
			t4 += 1
		var ok_no_phantom := int(world.state["hp"]) == PopTables.KID_HP_START \
				and int(world.state["dead"]) == 0
		var ok_shield_live := not boss.shielded

		# Completability with bounded retries (the echo outlives every death).
		var attempts := 0
		while int(boss.guard["dead"]) == 0 and attempts < 8:
			var t5 := 0
			while int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 and t5 < 1750:
				world.step_with(_l3_cmd(boss, world))
				t5 += 1
			attempts += 1
			if int(boss.guard["dead"]) == 0:
				world.respawn_at(spawn_px)   # attempt lost; the echo survives
		var ok_fell := int(boss.guard["dead"]) != 0

		# And the level ends by walking into the door.
		var reached := [false]
		var on_exit := func() -> void: reached[0] = true
		world.exit_reached.connect(on_exit)
		var t6 := 0
		while not reached[0] and int(world.state["dead"]) == 0 and t6 < 600:
			world.step_with(right)
			t6 += 1

		check(ok_take and ok_shield_down and ok_duel_live and ok_death and ok_boss_alive \
				and ok_echo_after and ok_restore and ok_no_phantom and ok_shield_live \
				and ok_fell and reached[0],
			"multi-seed %d: contract invariants hold (take %s, shield-down %s, duel-live %s, death %s, boss-alive %s, echo %s, restore %s, no-phantom %s, shield-live %s, fell in %d attempts %s, exit %s)" % [
				seed_n, str(ok_take), str(ok_shield_down), str(ok_duel_live), str(ok_death),
				str(ok_boss_alive), str(ok_echo_after), str(ok_restore), str(ok_no_phantom),
				str(ok_shield_live), attempts, str(ok_fell), str(reached[0])])

		EventBus.player_died.disconnect(on_died)
		TemporalManager.clear_echoes()
		boss.free()
		world.free()

	TemporalManager.register_sim_world(null)
	TemporalManager.set_echo_container(null)
