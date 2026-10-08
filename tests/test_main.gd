extends Node
## Headless verification harness.
##
## Run with:
## [codeblock]
## ./.tools/godot --headless --path . res://tests/test_main.tscn
## [/codeblock]
## Exits with status 1 if any assertion fails, so it is usable as a CI gate.
##
## These are integration tests, not unit tests: they instantiate the real
## [TemporalEcho], the real [PressurePlate] and the real level data, because the
## thing most worth proving is that a recorded memory actually drives the world.

var _passed: int = 0
var _failed: int = 0
var _sandbox: Node2D = null


func _ready() -> void:
	_sandbox = Node2D.new()
	_sandbox.name = "TestSandbox"
	add_child(_sandbox)

	await get_tree().physics_frame

	_section("Input map")
	_test_input_map()

	_section("Sim determinism gate (plan 8 gate 1)")
	_test_sim_determinism()

	_section("pop_tables ↔ PARITY anti-drift (plan A2.1)")
	_test_pop_tables_vs_parity()

	_section("A2.2 step function acceptance (plan A2.2)")
	_test_a22_acceptance()

	_section("A2.3 hang/climb/grab/crouch/safe-step acceptance (plan A2.3)")
	_test_a23_acceptance("")

	_section("A3.1 SimClock (plan A3.1)")
	_test_sim_clock()

	_section("A3.3 InputActions → pop_input latch (plan A3.3)")
	_test_pop_input_latch()

	_section("A3.2 pop_view sandbox (plan A3.2)")
	_test_pop_view_sandbox()

	_section("A4.1 gates, plates and the level exit (plan A4.1)")
	_test_a41_entities()

	_section("B1 minimal input-byte echo (plan B1 / §8 gate 4)")
	_test_b1_minimal_echo()

	_section("A4.2 spikes, loose floors and chompers (plan A4.2)")
	_test_a42_traps()

	_section("A4.3 guard duel at 10 fps (plan A4.3 / §8 gate 3)")
	_test_a43_duel()

	_section("Health component")
	_test_health()

	_section("Temporal recorder")
	_test_recorder()

	_section("Level data")
	_test_level_data()

	_section("Puzzle wiring")
	_test_puzzle_wiring()

	_section("Advanced levels")
	_test_advanced_levels()

	_section("Temporal rule overrides")
	_test_temporal_overrides()

	_section("Boss encounter")
	_test_boss()

	_section("Enemy statistics")
	_test_enemy_stats()

	_section("Player state machine")
	await _test_player_states()

	_section("Temporal echo playback")
	await _test_echo_replay()

	_finish()


# --- Harness ----------------------------------------------------------------

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


func _wait_physics(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func _finish() -> void:
	print("")
	print("-----------------------------------------")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("-----------------------------------------")
	get_tree().quit(1 if _failed > 0 else 0)


# --- Tests ------------------------------------------------------------------


## Plan §8 gate 1: a fixed seed plus a fixed 600-tick input script must hash
## equal across two runs, while a second seed must hash different — and a
## single flipped input bit must also diverge, proving the script is causal
## rather than the hash simply ignoring it.
func _test_sim_determinism() -> void:
	var script: Array = _fixed_input_script(600)
	# The sim resolves floors and falls, so the gate runs on a flat level:
	# identical runs must hash equal, and the script must stay causal.
	var level := _flat_level()

	var state_a: Dictionary = PopSim.run(12345, script, level)
	var state_b: Dictionary = PopSim.run(12345, script, level)
	check(PopSim.hash_state(state_a) == PopSim.hash_state(state_b),
		"same seed + same 600-tick script → identical state hash")
	check(int(state_a["tick"]) == 600, "the script stepped exactly 600 ticks")

	var state_c: Dictionary = PopSim.run(20261006, script, level)
	check(PopSim.hash_state(state_a) != PopSim.hash_state(state_c),
		"same script from a different seed → different state hash")

	# Tick 37 is the first running tick of the pattern (axis held right): flipping
	# it to the left must not just branch but permanently alter the final state
	# (a blip that cancels out would leave the end-state hash equal).
	var altered: Array = script.duplicate()
	altered[37] = PopInput.make(-1).to_byte()
	check(PopSim.hash_state(PopSim.run(12345, altered, level)) != PopSim.hash_state(state_a),
		"one altered input tick → different state hash (input is causal)")

	var back := PopInput.from_byte(PopInput.make(-1, 1, 1, 5).to_byte())
	check(back.x == -1 and back.y == 1 and back.shift == 1 and back.special == 5,
		"pop_input byte round-trip preserves all four fields")


## Deterministic (integer arithmetic only) — no RNG may touch the script.
func _fixed_input_script(ticks: int) -> Array:
	const NEUTRAL_TURN_RUN: Array = [0, 1, 1, -1, -1, 0]
	var script: Array = []
	for i: int in ticks:
		var x: int = NEUTRAL_TURN_RUN[(i / 37) % 6]
		var shift: int = 1 if (i / 13) % 4 == 0 else 0
		script.append(PopInput.make(x, 0, shift).to_byte())
	return script


func _test_input_map() -> void:
	var missing: Array[String] = []
	for action: StringName in InputActions.DEFAULTS:
		if not InputMap.has_action(action):
			missing.append(String(action))
	check(missing.is_empty(), "every declared action exists in the InputMap (%s)" % ("ok" if missing.is_empty() else str(missing)))

	var jump_events := InputMap.action_get_events(&"jump")
	check(jump_events.size() > 0, "'jump' has at least one bound key")

	# Re-running setup must be a no-op, not a duplicate-binding bug.
	var before := InputMap.action_get_events(&"jump").size()
	InputActions.ensure_defaults()
	check(InputMap.action_get_events(&"jump").size() == before, "ensure_defaults is idempotent")


func _test_sim_clock() -> void:
	# --- A3.1 SimClock: real-time → tick counts ---------------------------
	var hz := PopTables.TICK_HZ_TRAVERSE
	var clock := SimClock.new()
	var ticks := 0
	for _i: int in range(60):
		ticks += clock.advance(1.0 / 60.0)
	check(ticks == hz,
		"60 frames of 1/60 s produce %d ticks at %d Hz (got %d)" % [hz, hz, ticks])
	var half := SimClock.new()
	var half_ticks := 0
	for _i: int in range(30):
		half_ticks += half.advance(1.0 / 60.0)
	check(half_ticks == hz / 2,
		"0.5 s produces half the ticks (%d, got %d)" % [hz / 2, half_ticks])
	check(half.alpha >= 0.0 and half.alpha < 1.0,
		"alpha stays in [0,1) between ticks (got %f)" % half.alpha)

	# --- A3.1 prev/curr/alpha consistency ---------------------------------
	var s0 := PopSim.initial_state(1)
	var s1 := PopSim.step(s0, PopInput.make(1))
	var interp := SimClock.new(s0)
	check(interp.curr == s0 and interp.ticks == 0,
		"a fresh clock holds one state as both prev and curr")
	interp.push(s1)
	check(interp.prev == s0 and interp.curr == s1 and interp.ticks == 1,
		"push shifts curr→prev and counts the tick")
	check(is_equal_approx(interp.lerp_channel("x"), float(s0["x"])),
		"alpha 0 interpolates exactly at prev (x=%.1f)" % interp.lerp_channel("x"))
	interp.alpha = 0.5
	var mid := 0.5 * (float(s0["x"]) + float(s1["x"]))
	check(absf(interp.lerp_channel("x") - mid) < 0.001,
		"alpha 0.5 interpolates the midpoint (%.2f ~ %.2f)" % [interp.lerp_channel("x"), mid])

	# --- A3.1 sword-drawn rate switching ----------------------------------
	var fight := SimClock.new({}, true)
	var fight_ticks := 0
	for _i: int in range(60):
		fight_ticks += fight.advance(1.0 / 60.0)
	check(fight.hz == PopTables.TICK_HZ_SWORD and fight_ticks == PopTables.TICK_HZ_SWORD,
		"sword drawn switches to %d Hz (got %d Hz, %d ticks)" % [PopTables.TICK_HZ_SWORD, fight.hz, fight_ticks])


func _test_pop_input_latch() -> void:
	# --- A3.3 input latch: sub-tick tap survives to the next tick ---------
	var input := PopInputLatch.new()
	input.sample(false, true, false, false, false)   # frame 1: tap right
	input.sample(false, false, false, false, false)  # frame 2: released
	var delivered := input.take()
	check(delivered.x == 1,
		"a tap shorter than one tick is latched and delivered (x=%d)" % delivered.x)
	check(input.take().is_neutral(), "the latch resets after it is consumed")
	input.sample(true, true, false, false, false)    # opposite directions cancel
	check(input.take().x == 0, "opposite directions in one interval cancel")
	check(InputMap.has_action(&"grab"), "the grab action is registered for the latch")


func _test_pop_view_sandbox() -> void:
	# --- A3.2 sandbox level + view stepping -------------------------------
	var lvl := PopView.sandbox_level()
	check(lvl.size() == 3 and (lvl[0] as Array).size() == 12,
		"pop_lab sandbox is 3 rows × 12 columns")
	check(int((lvl[0] as Array)[4]) == PopTables.Tile.EMPTY
			and int((lvl[1] as Array)[8]) == PopTables.Tile.FLOOR,
		"sandbox has a pit at (row 0, col 4) and a raised ledge at (row 1, col 8)")
	var view := PopView.new()
	_sandbox.add_child(view)
	view.set_process(false)  # keep the test deterministic
	check(view.clock != null and String(view.clock.curr.get("seq", "")) == "stand",
		"PopView boots the sim in stand")
	var before := view.clock.ticks
	view.frame_step()
	check(view.clock.ticks == before + 1,
		"frame-step advances exactly one sim tick (%d → %d)" % [before, view.clock.ticks])
	view.queue_free()


func _test_health() -> void:
	var health := Health.new()
	health.max_health = 100
	health.invulnerability_time = 0.5
	_sandbox.add_child(health)
	health.reset()

	check(health.current == 100, "initialises to max health")

	check(health.take_damage(30), "damage lands when vulnerable")
	check(health.current == 70, "health decreases by the damage amount")
	check(not health.take_damage(30), "a second hit inside the i-frame window is refused")
	check(health.current == 70, "i-frames leave health unchanged")

	health.grant_invulnerability(0.0)
	health.heal(10)
	check(health.current == 80, "heal restores health")

	health.kill()
	check(health.is_dead and health.current == 0, "kill() forces death past i-frames")

	health.queue_free()


func _test_recorder() -> void:
	var config := TemporalConfig.new()
	config.max_recording_duration = 0.1
	config.min_recording_duration = 0.05
	var recorder := TemporalRecorder.new(config)
	recorder.start()
	check(recorder.is_recording, "recorder reports recording after start()")

	# Feed synthetic frames: the recorder must never exceed its duration budget.
	var frames := 0
	while recorder.is_recording and frames < 500:
		recorder.record(1.0 / 60.0, Vector2(float(frames), 0.0), 0.0, Vector2.ZERO, &"run", 1)
		frames += 1

	check(frames <= 8, "recording hard-stops at the duration cap (took %d frames)" % frames)
	check(not recorder.is_recording, "recorder reports stopped")
	check(recorder.has_usable_data(), "a 0.1s take is usable given a 0.05s minimum")
	check(recorder.duration() <= config.max_recording_duration + 0.02, "recorded duration respects the cap")

	# Events attach to the newest frame, which is what the echo replays.
	recorder.add_event(&"interact")
	check(recorder.get_snapshots()[-1].has_events(), "add_event attaches to the latest frame")

	# Too-short takes must be rejected, not silently used.
	config.min_recording_duration = 5.0
	check(not recorder.has_usable_data(), "a take shorter than the minimum is unusable")


func _test_level_data() -> void:
	check(LevelCatalog.count() == 5, "catalog exposes all five levels (found %d)" % LevelCatalog.count())

	for index: int in LevelCatalog.count():
		var data := LevelCatalog.get_level(index)
		check(not data.is_empty(), "level %d has data" % index)
		check(data.has("spawn") and data.has("bounds") and data.has("platforms"), "level %d has spawn/bounds/platforms" % index)
		check(data["platforms"].size() > 0, "level %d has at least one platform" % index)

		# Wiring references span props AND enemies (the boss listens to a plate),
		# so both groups have to be pooled before checking. A dangling reference
		# ships a mechanism that can never be operated.
		var ids := {}
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				var spec_id := String(spec.get("id", ""))
				if not spec_id.is_empty():
					ids[spec_id] = true

		var dangling: Array[String] = []
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				for source_id: String in spec.get("listens_to", []):
					if not ids.has(source_id):
						dangling.append("%s -> %s" % [spec.get("id", "?"), source_id])
		check(dangling.is_empty(), "level %d has no dangling listens_to references (%s)" % [index, "ok" if dangling.is_empty() else str(dangling)])

		# Every wired target must actually accept wiring.
		var unwireable: Array[String] = []
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				if spec.get("listens_to", []).is_empty():
					continue
				var type_id := String(spec.get("type", ""))
				var registry: Dictionary = LevelBuilder.enemy_types() if group == "enemies" else LevelBuilder.object_types()
				if not registry.has(type_id):
					unwireable.append(type_id)
					continue
				var probe: Node = (registry[type_id] as GDScript).new()
				if not probe.has_method("bind_sources"):
					unwireable.append(type_id)
				probe.free()
		check(unwireable.is_empty(), "level %d wiring targets all support bind_sources (%s)" % [index, "ok" if unwireable.is_empty() else str(unwireable)])


func _test_puzzle_wiring() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(1))

	var plate := builder.get_node_or_null("pressure_plate_plate_near") as PressurePlate
	var door_near := builder.get_node_or_null("door_door_near") as Door
	var rune := builder.get_node_or_null("temporal_switch_rune_hall") as TemporalSwitch
	var door_far := builder.get_node_or_null("door_door_far") as Door
	var bridge := builder.get_node_or_null("moving_platform_bridge") as MovingPlatform

	check(plate != null, "near pressure plate was built")
	check(door_near != null, "near door was built")
	check(rune != null, "temporal rune was built")
	check(door_far != null, "far door was built")
	check(bridge != null, "bridge platform was built")

	if plate == null or door_near == null or rune == null or door_far == null:
		builder.queue_free()
		return

	check(not door_near.is_open, "near door starts closed")
	plate.set_active(true)
	check(door_near.is_open, "holding the plate opens the door it is wired to")
	plate.set_active(false)
	check(not door_near.is_open, "releasing the plate closes that door again")

	check(not rune.is_on(), "rune starts unlit")
	check(not door_far.is_open, "far door starts closed")
	rune.set_active(true)
	check(door_far.is_open, "the rune opens the far door")
	check(bridge.is_engaged(), "the same rune engages the bridge platform")

	builder.queue_free()


func _test_player_states() -> void:
	var player := Player.new()
	_sandbox.add_child(player)

	check(player.state_machine.states.size() == 13, "all 13 states are registered (found %d)" % player.state_machine.states.size())

	# An unknown state must be rejected without corrupting the machine.
	# The engine ERROR logged on the next line is INTENTIONAL: it is the rejection
	# path being exercised. The accompanying assertion is the real check.
	var before := player.state_machine.state_name()
	player.state_machine.transition_to(&"does_not_exist")
	check(player.state_machine.state_name() == before, "transition to an unknown state is ignored")

	# Transitions are deferred by design, so the change must NOT be visible on the
	# same frame, and must be in place on the next one. Dead is terminal, which
	# makes it stable enough to assert against.
	player.state_machine.transition_to(&"dead")
	check(player.state_machine.state_name() != &"dead", "transition is deferred, not applied mid-frame")
	await _wait_physics(2)
	check(player.state_machine.state_name() == &"dead", "deferred transition lands on the next physics step")

	player.queue_free()


func _test_echo_replay() -> void:
	var container := Node2D.new()
	_sandbox.add_child(container)
	var plate := PressurePlate.new()
	plate.configure(Vector2(90.0, 14.0))
	container.add_child(plate)

	# A synthetic take that walks right and stops standing on the plate.
	# Deliberately offsets the path so the end pose is nowhere near the origin:
	# that way "the echo held its final pose" cannot pass by accident.
	var snapshots: Array[TemporalSnapshot] = []
	var frame_count := 24
	for i: int in frame_count:
		snapshots.append(TemporalSnapshot.create(
			float(i + 1) / 60.0,
			Vector2(-230.0 + float(i) * 10.0, -14.0),
			0.0,
			Vector2(60.0, 0.0),
			&"run",
			1
		))
	var final_position: Vector2 = snapshots[-1].position

	var config := TemporalConfig.new()
	config.loop_echo = false
	config.echo_lifetime = 10.0
	TemporalManager.config = config
	TemporalManager.set_echo_container(container)

	var echo := TemporalManager.spawn_echo(snapshots)
	check(echo != null, "spawn_echo returns an echo")
	check(TemporalManager.echo_count() == 1, "the echo is registered as active")
	if echo == null:
		container.queue_free()
		return

	# The echo spawns on its first frame, not at the world origin.
	check(echo.global_position.is_equal_approx(snapshots[0].position), "echo starts at the first recorded frame")

	# Let playback run past the end of the take.
	await _wait_physics(frame_count + 12)

	check(echo.global_position.distance_to(final_position) < 1.0,
		"echo holds its final recorded pose after playback ends (at %s, expected %s)" % [echo.global_position, final_position])

	# The whole point: the memory is a physical weight on the plate.
	check(plate.is_active, "an echo standing on a pressure plate activates it")

	# Determinism: a second echo from the same take follows the same path.
	var second := TemporalManager.spawn_echo(snapshots)
	check(second != null, "a second echo can be spawned")
	if second != null:
		check(second.global_position.is_equal_approx(snapshots[0].position),
			"replaying the same take starts from the same position (deterministic)")

	# Capacity is enforced, not advisory.
	await _wait_physics(2)
	check(TemporalManager.echo_count() <= config.max_active_echoes,
		"active echo count respects max_active_echoes (%d <= %d)" % [TemporalManager.echo_count(), config.max_active_echoes])

	TemporalManager.clear_echoes()
	await _wait_physics(2)
	check(TemporalManager.echo_count() == 0, "clear_echoes removes every echo")

	container.queue_free()


## Level 4 is the directive's advanced tier: three sources must be live at once.
func _test_advanced_levels() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(3))

	var plate_a := builder.get_node_or_null("pressure_plate_sanctum_plate_a") as PressurePlate
	var plate_b := builder.get_node_or_null("pressure_plate_sanctum_plate_b") as PressurePlate
	var rune := builder.get_node_or_null("temporal_switch_sanctum_rune") as TemporalSwitch
	var door := builder.get_node_or_null("door_sanctum_door") as Door
	var bridge := builder.get_node_or_null("moving_platform_sanctum_bridge") as MovingPlatform
	var sentinel := builder.get_node_or_null("enemy_temporal_sentinel_1")

	check(plate_a != null and plate_b != null, "both sanctum plates were built")
	check(rune != null, "the sanctum rune was built")
	check(door != null, "the three-source sanctum door was built")
	check(bridge != null, "the sanctum bridge was built")
	check(sentinel != null, "the Temporal Sentinel was built")

	if door == null or plate_a == null or plate_b == null or rune == null:
		builder.queue_free()
		return

	check(not door.is_open, "the sanctum door starts closed")
	plate_a.set_active(true)
	check(not door.is_open, "one of three sources is not enough")
	plate_b.set_active(true)
	check(not door.is_open, "two of three sources is still not enough")
	rune.set_active(true)
	check(door.is_open, "all three sources finally open the door")
	plate_b.set_active(false)
	check(not door.is_open, "losing any single source closes it again")

	builder.queue_free()


## A level may raise the recording window and the echo cap. The stock rules must
## come back afterwards, or the sanctum's upgrade would leak into the boss.
func _test_temporal_overrides() -> void:
	var overrides: Dictionary = LevelCatalog.get_level(3).get("temporal", {})
	check(overrides.get("max_active_echoes", 0) == 2, "level 4 requests the two-echo tier")
	check(overrides.get("max_recording_duration", 0.0) == 12.0, "level 4 requests the 12 s recording window")
	check(LevelCatalog.get_level(0).get("temporal", {}).is_empty(), "level 1 requests no overrides")

	TemporalManager.configure_for_level(overrides)
	check(TemporalManager.config.max_active_echoes == 2, "the override raises the echo cap")
	check(TemporalManager.config.max_recording_duration == 12.0, "the override raises the recording window")

	TemporalManager.configure_for_level({})
	check(TemporalManager.config.max_active_echoes == 1, "stock echo cap is restored afterwards")
	check(TemporalManager.config.max_recording_duration == 8.0, "stock recording window is restored afterwards")


## The Warden is the only enemy designed around the echo mechanic: its shield is
## down only while an arena plate is held, and a shielded hit is nullified.
func _test_boss() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(4))

	var boss := builder.get_node_or_null("enemy_time_warden_0") as TimeWarden
	var plate := builder.get_node_or_null("pressure_plate_warden_plate") as PressurePlate

	check(boss != null, "the Time Warden was built")
	check(plate != null, "the arena plate was built")
	if boss == null or plate == null:
		builder.queue_free()
		return

	check(boss.stats.stagger_immune, "the Warden never staggers, so it cannot be stun-locked")
	# A hovering boss would drift above the player's swing arc and be unkillable.
	check(boss.stats.uses_gravity, "the Warden stays grounded, inside melee reach")
	check(boss.is_shielded(), "the Warden starts shielded")

	var before := boss.health.current
	check(not boss.hurtbox.receive_hit(50, 0.0, Vector2.ZERO), "a hit on the shielded Warden is refused")
	check(boss.health.current == before, "the shielded Warden takes no damage at all")

	plate.set_active(true)
	check(not boss.is_shielded(), "holding the arena plate drops the shield")
	check(boss.hurtbox.receive_hit(50, 0.0, Vector2.ZERO), "a hit lands once the shield is down")
	check(boss.health.current < before, "the unshielded Warden takes damage")

	# Phase thresholds are data; drive them directly rather than grinding 320 HP.
	boss.health.current = 150
	boss.health.changed.emit(150, boss.health.max_health)
	check(boss.phase == TimeWarden.Phase.TWO, "falling below 60% health advances to phase two")
	boss.health.current = 40
	boss.health.changed.emit(40, boss.health.max_health)
	check(boss.phase == TimeWarden.Phase.THREE, "falling below 25% health advances to phase three")
	check(boss.stats.volley_count == 5, "phase three widens the volley")

	plate.set_active(false)
	check(boss.is_shielded(), "releasing the plate restores the shield")

	builder.queue_free()


## Guards the defect where an enemy's weapon hitbox sat on its own chest instead
## of in front of it: every melee archetype must reach at least as far as it
## commits to attacking, or it swings at air forever.
func _test_enemy_stats() -> void:
	var archetypes := LevelBuilder.enemy_types()
	check(archetypes.size() >= 4, "four enemy archetypes are registered (found %d)" % archetypes.size())

	for type_id: String in archetypes:
		var enemy: EnemyBase = (archetypes[type_id] as GDScript).new()
		var stats: EnemyStats = enemy._make_default_stats()
		check(stats.max_health > 0, "%s has a positive health pool" % type_id)
		check(stats.detection_radius > 0.0, "%s can detect the player" % type_id)
		check(stats.disengage_radius >= stats.detection_radius,
			"%s never disengages before it detects" % type_id)

		if stats.ranged:
			check(stats.preferred_range < stats.attack_range,
				"%s holds station inside its firing envelope (%.0f < %.0f)" % [type_id, stats.preferred_range, stats.attack_range])
		else:
			check(EnemyBase.WEAPON_REACH < stats.attack_range,
				"%s weapon reach (%.0f) is inside its attack range (%.0f)" % [type_id, EnemyBase.WEAPON_REACH, stats.attack_range])

		enemy.free()


# --- Plan A2.1: pop_tables.gd ↔ docs/PARITY.md anti-drift ------------------
#
# Plan A2.1 accept: a test asserting each constant matches its PARITY.md row,
# so the two cannot drift apart. Scalar constants are checked against their
# rows; the id maps and kid frame rows one for one; and the re-authored
# sequences are replayed through a mini play_seq interpreter (tick = ops up to
# and including the next FRAME op, JUMP switches sequence mid-tick —
# `seg006.c:569-684`) whose per-tick dx/dy/cumulative streams must reproduce
# the §3/§4/§5 tables exactly.

const _MISSING_PARITY_VALUE := -999999999


func _test_pop_tables_vs_parity() -> void:
	var md := FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable")
	if md.is_empty():
		return

	# --- scalar constants: pop_tables value == PARITY row ------------------
	check(_parity_int(md, "1", "Logic frame, traverse") == PopTables.TICK_HZ_TRAVERSE,
		"TICK_HZ_TRAVERSE matches PARITY §1")
	check(_parity_int(md, "1", "Logic frame, sword drawn") == PopTables.TICK_HZ_SWORD,
		"TICK_HZ_SWORD matches PARITY §1")

	var nums := _ints(_parity_cell(md, "2", "Unit scale"))
	check(nums.size() >= 3 and nums[0] == PopTables.TILE_W and nums[2] == PopTables.TILE_H,
		"TILE_W/TILE_H match PARITY §2")
	check(_int_array_equal(_ints(_parity_cell(md, "2", "Floor y per row")), PopTables.Y_LAND),		"Y_LAND matches PARITY §2")
	check(_int_array_equal(_ints(_parity_cell(md, "2", "Tile x positions")), PopTables.X_BUMP),
		"X_BUMP matches PARITY §2")


	check(_parity_int(md, "2", "First on-screen column") == PopTables.FIRST_ONSCREEN_COLUMN,
		"FIRST_ONSCREEN_COLUMN matches PARITY §2")

	nums = _ints(_parity_cell(md, "7", "Integration"))
	check(nums.size() >= 2 and nums[0] == PopTables.FALL_ACCEL and nums[1] == PopTables.FALL_SPEED_MAX,
		"fall accel/cap match PARITY §7")
	check(_parity_int(md, "7", "Soft land") == PopTables.SOFT_LAND_MAX,
		"SOFT_LAND_MAX matches PARITY §7")
	nums = _ints(_parity_cell(md, "7", "Medium land"))
	check(nums.size() >= 2 and nums[0] == PopTables.MEDIUM_LAND_MIN and nums[1] == PopTables.MEDIUM_LAND_MAX,
		"medium-land window matches PARITY §7")
	check(_parity_int(md, "7", "Death") == PopTables.DEATH_SPEED,
		"DEATH_SPEED matches PARITY §7")

	check(_parity_int(md, "18", "Direction change (turn)", 1) == PopTables.TURN_TICKS,
		"TURN_TICKS matches PARITY §18")
	check(_parity_int(md, "18", "Run stop", 1) == PopTables.RUN_STOP_TICKS,
		"RUN_STOP_TICKS matches PARITY §18")

	# §6 stand frame: climb/turn/land all jump to `stand`, whose opening frame
	# the reference fixes at 15 (`seqtbl.c:261-263`). This binds pop_tables'
	# stand sequence to the PARITY row — the gap that let the old "stand at
	# frame 18" wording (a tick-index/frame-id conflation) survive A2.1.
	var stand_open := int(PopTables.SEQUENCES["stand"][1][1])
	check(_parity_int(md, "6", "stand frame") == stand_open,
		"stand sequence opening frame f%d matches PARITY §6 (`seqtbl.c:261-263`)" % stand_open)

	check(_int_array_equal(_ints(_parity_cell(md, "2", "Non-floor tiles")), PopTables.NON_FLOOR_TILES),
		"NON_FLOOR_TILES matches PARITY §2")
	nums = _ints(_parity_row(md, "8", "extend")[3] if _parity_row(md, "8", "extend").size() > 3 else "")
	check(nums.size() >= 2 and nums[1] == PopTables.SPIKE_EXTEND_MAX,
		"SPIKE_EXTEND_MAX matches PARITY §8 extend row")

	# pop_sim's measured replacements must equal the table values they cite.
	check(PopSim.TURN_TICKS == PopTables.TURN_TICKS, "pop_sim TURN_TICKS uses PopTables.TURN_TICKS")
	# ...and it must be *bound* to the table in source: the value check above
	# passes for a hardcoded literal too, which would silently decouple the
	# constant from PopTables (the corruption the Session 004 audit found).
	var pop_sim_src := FileAccess.get_file_as_string("res://scripts/pop/pop_sim.gd")
	check(pop_sim_src.contains("const TURN_TICKS: int = PopTables.TURN_TICKS"),
		"pop_sim binds TURN_TICKS to PopTables.TURN_TICKS in source, not a literal")
	check(PopSim.STAND_Y == int(PopTables.Y_LAND[1]), "pop_sim STAND_Y is the measured row-0 floor y")

	# --- id maps (§16): our enums vs reference ids 1:1 ---------------------
	var ids := _parity_ids(md)
	check(ids.is_empty() == false, "PARITY §16 id table parsed")
	var bad: Array[String] = []
	for name: String in PopTables.Tile:
		if not ids["tile"].has(name) or int(ids["tile"][name]) != int(PopTables.Tile[name]):
			bad.append(name)
	check(bad.is_empty(), "tile enum matches PARITY §16 (%s)" % ("ok" if bad.is_empty() else str(bad)))
	bad = []
	for name: String in PopTables.Action:
		if not ids["action"].has(name) or int(ids["action"][name]) != int(PopTables.Action[name]):
			bad.append(name)
	check(bad.is_empty(), "action enum matches PARITY §16 (%s)" % ("ok" if bad.is_empty() else str(bad)))
	bad = []
	for name: String in PopTables.Sound:
		if not ids["sound"].has(name) or int(ids["sound"][name]) != int(PopTables.Sound[name]):
			bad.append(name)
	check(bad.is_empty(), "sound enum matches PARITY §16 (%s)" % ("ok" if bad.is_empty() else str(bad)))
	check(ids["tile"].size() == PopTables.Tile.size(),
		"PARITY §16 carries all %d tiles (found %d)" % [PopTables.Tile.size(), ids["tile"].size()])
	check(ids["hp"].has("START") and int(ids["hp"]["START"]) == PopTables.KID_HP_START,
		"KID_HP_START matches PARITY §16")

	# --- kid frame rows (§17) one for one ----------------------------------
	var pframes := _parity_frames(md)
	check(pframes.size() == PopTables.KID_FRAME.size(),
		"PARITY §17 carries exactly %d frame rows (found %d)" % [PopTables.KID_FRAME.size(), pframes.size()])
	bad = []
	for frame: int in PopTables.KID_FRAME:
		var row: Dictionary = PopTables.KID_FRAME[frame]
		var want: Array = [row["dx"], row["dy"], row["weight"], row["thin"], row["needs_floor"], row["even_odd"]]
		if not pframes.has(frame):
			bad.append("missing f%d" % frame)
		elif not _int_array_equal(pframes[frame], want):
			bad.append("f%d" % frame)
	check(bad.is_empty(), "kid frame rows match PARITY §17 (%s)" % ("ok" if bad.is_empty() else str(bad)))

	# Every frame id a sequence sets must exist in the frame table.
	bad = []
	for seq_name: String in PopTables.SEQUENCES:
		for op: Array in PopTables.SEQUENCES[seq_name]:
			if int(op[0]) == PopTables.Op.FRAME and not PopTables.KID_FRAME.has(int(op[1])):
				bad.append("%s f%d" % [seq_name, op[1]])
	check(bad.is_empty(), "every sequence frame id has a KID_FRAME row (%s)" % ("ok" if bad.is_empty() else str(bad)))

	# --- sequence streams vs §3/§4/§5 tables ------------------------------
	_test_run_stream_vs_parity(md)
	_test_stand_jump_stream_vs_parity(md)
	_test_run_jump_stream_vs_parity(md)


## §3: startrun enters the cycle; ticks 7–15 are f7(entry dx3) … →f7(dx4).
func _test_run_stream_vs_parity(md: String) -> void:
	var ticks := _seq_ticks("startrun", 15)
	check(ticks.size() == 15, "startrun+run_cycle produced 15 ticks (got %d)" % ticks.size())
	if ticks.size() < 15:
		return
	var want := _expand_cells(_parity_row(md, "3", "frame").slice(1),
		_parity_row(md, "3", "dx").slice(1))
	var got: Array = []
	for i: int in range(6, 15):
		got.append(int(ticks[i]["dx"]))
	check(_int_array_equal(got, want), "run dx stream matches PARITY §3")
	var steady := 0
	for i: int in range(1, want.size()):
		steady += int(want[i])
	check(steady == 26 and _parity_section(md, "3").contains("26 units"),
		"steady run cycle totals the 26 units claimed in PARITY §3")


## §4: standing jump — 19 ticks through JUMP(stand), dx/dy/cum x.
func _test_stand_jump_stream_vs_parity(md: String) -> void:
	var hdr := _parity_row(md, "4", "frame").slice(1)
	var want_dx := _expand_cells(hdr, _parity_row(md, "4", "dx").slice(1))
	var want_dy := _expand_cells(hdr, _parity_row(md, "4", "dy").slice(1))
	var want_cum := _expand_cells(hdr, _parity_row(md, "4", "cum x").slice(1))
	var ticks := _seq_ticks("stand_jump", 19)
	check(ticks.size() == 19, "stand_jump produced 19 ticks (got %d)" % ticks.size())
	if ticks.size() < 19:
		return
	var dx: Array = []
	var dy: Array = []
	var cum: Array = []
	var run := 0
	for t: Dictionary in ticks:
		run += int(t["dx"])
		dx.append(int(t["dx"]))
		dy.append(int(t["dy"]))
		cum.append(run)
	check(_int_array_equal(dx, want_dx), "stand_jump dx stream matches PARITY §4")
	check(_int_array_equal(dy, want_dy), "stand_jump dy stream matches PARITY §4")
	check(_int_array_equal(cum, want_cum), "stand_jump cumulative x matches PARITY §4")


## §5: running jump — 12 ticks through JUMP(run_cycle), dx/dy/cum x/cum y.
func _test_run_jump_stream_vs_parity(md: String) -> void:
	var hdr := _parity_row(md, "5", "frame").slice(1)
	var want_dx := _expand_cells(hdr, _parity_row(md, "5", "dx").slice(1))
	var want_dy := _expand_cells(hdr, _parity_row(md, "5", "dy").slice(1))
	var want_cum_x := _expand_cells(hdr, _parity_row(md, "5", "cum x").slice(1))
	var want_cum_y := _expand_cells(hdr, _parity_row(md, "5", "cum y").slice(1))
	var ticks := _seq_ticks("run_jump", 12)
	check(ticks.size() == 12, "run_jump produced 12 ticks (got %d)" % ticks.size())
	if ticks.size() < 12:
		return
	var dx: Array = []
	var dy: Array = []
	var cum_x: Array = []
	var cum_y: Array = []
	var rx := 0
	var ry := 0
	for t: Dictionary in ticks:
		rx += int(t["dx"])
		ry += int(t["dy"])
		dx.append(int(t["dx"]))
		dy.append(int(t["dy"]))
		cum_x.append(rx)
		cum_y.append(ry)
	check(_int_array_equal(dx, want_dx), "run_jump dx stream matches PARITY §5")
	check(_int_array_equal(dy, want_dy), "run_jump dy stream matches PARITY §5")
	check(_int_array_equal(cum_x, want_cum_x), "run_jump cumulative x matches PARITY §5")
	check(_int_array_equal(cum_y, want_cum_y), "run_jump cumulative y matches PARITY §5")


## Mini play_seq: ops run until a FRAME op ends the tick; JUMP switches the
## sequence without ending the tick (`seg006.c:569-684`). Non-stream ops
## (ACTION, SOUND, KNOCK_DOWN, SET_FALL, DIE, FLIP) do not move the character.
func _seq_ticks(start: String, count: int) -> Array:
	var seq := start
	var op_i := 0
	var ticks: Array = []
	var cur := {"dx": 0, "dy": 0, "frame": -1}
	var steps := 0
	while ticks.size() < count and steps < 10000:
		steps += 1
		var ops: Array = PopTables.SEQUENCES[seq]
		if op_i >= ops.size():
			break
		var op: Array = ops[op_i]
		op_i += 1
		match int(op[0]):
			PopTables.Op.DX:
				cur["dx"] = int(cur["dx"]) + int(op[1])
			PopTables.Op.DY:
				cur["dy"] = int(cur["dy"]) + int(op[1])
			PopTables.Op.FRAME:
				cur["frame"] = int(op[1])
				ticks.append(cur)
				cur = {"dx": 0, "dy": 0, "frame": -1}
			PopTables.Op.JUMP:
				seq = String(op[1])
				op_i = 0
			_:
				pass
	return ticks


# --- tiny PARITY.md markdown readers ---------------------------------------

func _parity_section(md: String, num: String) -> String:
	var begin := md.find("## %s. " % num)
	if begin < 0:
		return ""
	var end := md.find("\n## ", begin + 1)
	return md.substr(begin, (end - begin) if end > 0 else (md.length() - begin))


func _md_cells(line: String) -> Array:
	var parts := line.split("|")
	var cells: Array = []
	for i: int in range(1, parts.size() - 1):
		cells.append(parts[i].strip_edges())
	return cells


func _parity_row(md: String, num: String, label: String) -> Array:
	for line: String in _parity_section(md, num).split("\n"):
		if not line.begins_with("|"):
			continue
		var cells := _md_cells(line)
		if cells.size() > 0 and String(cells[0]) == label:
			return cells
	return []


func _parity_cell(md: String, num: String, label: String, index: int = 1) -> String:
	var row := _parity_row(md, num, label)
	if row.size() > index:
		return String(row[index])
	return ""


func _parity_int(md: String, num: String, label: String, index: int = 1) -> int:
	var nums := _ints(_parity_cell(md, num, label, index))
	return int(nums[nums.size() - 1]) if nums.size() > 0 else _MISSING_PARITY_VALUE


## Integers from a cell, with backticked code spans dropped first so
## identifiers like `y_land[row+1]` cannot contribute stray digits. Only the
## unicode minus is normalised: en-dashes in ranges ("f18–f22", "1–4") must
## stay separators, not sign characters.
func _ints(text: String) -> Array:
	var cleaned := RegEx.create_from_string("`[^`]*`").sub(text, "", true)
	cleaned = cleaned.replace("−", "-")
	var out: Array = []
	for m: RegExMatch in RegEx.create_from_string("-?\\d+").search_all(cleaned):
		out.append(int(m.get_string()))
	return out


## Expand value cells against header spans: "f18–f22" covers 5 frames, so its
## value cell may carry one number (repeat), span numbers, or a start→end pair
## that steps uniformly ("2→10" over 5 frames → 2,4,6,8,10).
func _expand_cells(header: Array, values: Array) -> Array:
	var out: Array = []
	for i: int in range(header.size()):
		var span := _span_of(String(header[i]))
		var nums: Array = []
		if i < values.size():
			nums = _ints(String(values[i]))
		if span <= 1:
			out.append(int(nums[0]) if nums.size() > 0 else _MISSING_PARITY_VALUE)
		elif nums.size() == span:
			for n: int in nums:
				out.append(n)
		elif nums.size() == 1:
			for _k: int in span:
				out.append(int(nums[0]))
		elif nums.size() == 2 and (int(nums[1]) - int(nums[0])) % (span - 1) == 0:
			var step := (int(nums[1]) - int(nums[0])) / (span - 1)
			for k: int in span:
				out.append(int(nums[0]) + step * k)
		else:
			out.append(_MISSING_PARITY_VALUE)
	return out


func _span_of(header_cell: String) -> int:
	var nums := _ints(header_cell)
	if nums.size() >= 2:
		return int(nums[1]) - int(nums[0]) + 1
	return 1


func _parity_ids(md: String) -> Dictionary:
	var ids := {"tile": {}, "action": {}, "sound": {}, "hp": {}}
	for line: String in _parity_section(md, "16").split("\n"):
		if not line.begins_with("|"):
			continue
		var cells := _md_cells(line)
		if cells.size() >= 4 and ids.has(String(cells[0])):
			ids[String(cells[0])][String(cells[1])] = int(cells[2])
	return ids


func _parity_frames(md: String) -> Dictionary:
	var out := {}
	for line: String in _parity_section(md, "17").split("\n"):
		if not line.begins_with("|"):
			continue
		var cells := _md_cells(line)
		if cells.size() >= 7 and String(cells[0]).is_valid_int():
			out[int(cells[0])] = [int(cells[1]), int(cells[2]), int(cells[3]),
				int(cells[4]), int(cells[5]), int(cells[6])]
	return out


func _int_array_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


# --- Plan A2.2: step function acceptance ----------------------------------
#
# Plan A2.2 accept: determinism double-run hash equality; standing jump =
# 1 tile and run jump = 2 tiles of horizontal distance, cross-checked against
# docs/PARITY.md §4/§5; falling 3 rows kills, 2 rows costs 1 HP. The section
# also exercises the other A2.2 behaviors (turn, run stop, soft/medium land,
# spike contact, floor-edge snap). Measured values are printed inside the
# PASS labels; any mismatch against PARITY.md is a reported gap — constants
# are never tuned to turn a red check green.
#
# A2.2 receives the PARITY.md text from the caller when available and only
# reloads it from disk when called with an empty string; that lets _ready()
# first exercise _test_pop_tables_vs_parity (which loads the pop classes
# through their first successful use of PopTables) before A2.2's live
# PopSim/PopInput calls need the class_name references to resolve.


## A wide flat floor (4 rows x 32 cols of FLOOR). The determinism script
## runs the kid across several hundred units, so the platform must outspan
## his reachable x range — otherwise "flat level" would silently mean
## "flat until he walks off the edge".
func _flat_level() -> Array:
	var level: Array = []
	for _r: int in 4:
		var cells: Array = []
		for _c: int in 32:
			cells.append(PopTables.Tile.FLOOR)
		level.append(cells)
	return level


## Row 0 is floored for columns 0-4 only (the kid walks off the edge at
## column 5); rows below `landing_row` are empty while `landing_row` and
## below are solid, so a walk-off drops the kid exactly `landing_row` rows
## before touchdown — 1 row = soft land, 2 rows = medium, 3 rows = death.
func _hole_level(landing_row: int) -> Array:
	var level: Array = []
	for r: int in 4:
		var cells: Array = []
		for c: int in 10:
			if r == 0 and c < 5:
				cells.append(PopTables.Tile.FLOOR)
			elif r >= landing_row:
				cells.append(PopTables.Tile.FLOOR)
			else:
				cells.append(PopTables.Tile.EMPTY)
		level.append(cells)
	return level


## Force a landing on the very next step: the kid hangs in free fall at
## row 1 with his feet already at that row's floor (`y_land[row+1]`,
## `seg005.c:124`), so one step resolves do_fall → land → edge rule
## without a long setup fall.
func _crafted_landing(tiles: Array, x: int) -> Dictionary:
	var st := PopSim.initial_state(11, tiles)
	st["row"] = 1
	st["y"] = int(PopTables.Y_LAND[2])
	st["x"] = x
	st["seq"] = "free_fall"
	st["frame"] = 106
	st["action"] = PopTables.Action.IN_FREEFALL
	st["fall_y"] = 0
	st["fall_x"] = 0
	return PopSim.step(st, PopInput.neutral())


## Index of a frame label inside an expanded PARITY header: "f18–f22" covers
## five positions, a lone "f16" one, a header cell without a number
## ("stand") one too; returns -1 when the frame is not carried. (The
## arrow cell "→f7" parses as frame 7, which these tests never seek.)
func _frame_index(header: Array, frame: int) -> int:
	var offset := 0
	for cell: Variant in header:
		var nums := _ints(String(cell))
		if nums.is_empty():
			offset += 1
		elif nums.size() >= 2:
			if frame >= int(nums[0]) and frame <= int(nums[1]):
				return offset + (frame - int(nums[0]))
			offset += int(nums[1]) - int(nums[0]) + 1
		else:
			if frame == int(nums[0]):
				return offset
			offset += 1
	return -1


## A2.3 scenario helpers (sim-level geometry, not PARITY constants).
## These exist only to make the A2.3 behavioral tests readable; every PARITY
## value used in the A2.3 assertions is taken from PARITY.md and cited there.

## 1-tile pit at row 0..2 with a single floor under the lip at columns 0..3.
## The kid starts at the lip, row 0, so walking forward falls through the pit
## and lands on the floor at `landing_row` (1 row = soft, 2 = medium, 3 = death).
func _pit_level(pit_width: int, landing_row: int) -> Array:
	var level: Array = []
	for r: int in 4:
		var cells: Array = []
		for c: int in 10:
			if r == 0 and c < 5 + pit_width:
				cells.append(PopTables.Tile.FLOOR)
			elif r >= landing_row:
				cells.append(PopTables.Tile.FLOOR)
			else:
				cells.append(PopTables.Tile.EMPTY)
		level.append(cells)
	return level


## Cliff-edge hang set-up: row 0 lip at columns 0..4, floor at `landing_row`
## below; the kid hangs at row 0 just left of the lip so a hang-release
## (Shift released) drops toward the floor at `landing_row`.
func _hang_lip_level(lip_cols: int, landing_row: int) -> Array:
	var level: Array = []
	for r: int in 4:
		var cells: Array = []
		for c: int in 10:
			if r == 0 and c < lip_cols:
				cells.append(PopTables.Tile.FLOOR)
			elif r >= landing_row:
				cells.append(PopTables.Tile.FLOOR)
			else:
				cells.append(PopTables.Tile.EMPTY)
		level.append(cells)
	return level


## Place the kid at the lip of a hang level, mid-air above the lip so a
## falling grab can fire when Shift is held and a grabbable tile exists
## ahead-above. `row=0`, `y=Y_LAND[1]`, facing right.
func _setup_hang_at_lip(st: Dictionary, level: Array, lip_x: int) -> Dictionary:
	st["row"] = 0
	st["y"] = int(PopTables.Y_LAND[1])
	st["x"] = lip_x
	st["seq"] = "hang"
	st["frame"] = 91
	st["action"] = PopTables.Action.HANG_CLIMB
	st["tiles"] = level
	return st


## Place the kid standing at the edge of a floor so a safe_step probe can
## walk toward the empty space and exercise edge distance behavior.
func _setup_stand_at_edge(st: Dictionary, level: Array, x: int, dir: int) -> Dictionary:
	st["row"] = 1
	st["y"] = int(PopTables.Y_LAND[2])
	st["x"] = x
	st["dir"] = dir
	st["seq"] = "stand"
	st["frame"] = 15
	st["action"] = PopTables.Action.STAND
	st["tiles"] = level
	return st


func _test_a22_acceptance(md: String = "") -> void:
	if md.is_empty():
		md = FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A2.2 cross-checks")
	if md.is_empty():
		return
	var level := _flat_level()

	# --- (a) determinism double-run hash equality ------------------------
	var script: Array = _fixed_input_script(400)
	var run1 := PopSim.run(777, script, level)
	var run2 := PopSim.run(777, script, level)
	check(PopSim.hash_state(run1) == PopSim.hash_state(run2),
		"double-run of the 400-tick script hashes equal (A2.2 determinism; sim characterization, not parity evidence)")
	# Measurement, not a gate: where does the script leave him on a flat floor?
	print("  MEAS 400-tick flat-floor run ends: x=%d hp=%d dead=%d row=%d seq=%s" % [
		int(run1["x"]), int(run1["hp"]), int(run1["dead"]),
		int(run1["row"]), String(run1["seq"])])
	# (c0) PARITY-derived fall thresholds as read by the A2.2 landing gates.
	var soft_max_a22 := _parity_int(md, "7", "Soft land", 1)
	var medium_nums_a22: Array = _ints(_parity_cell(md, "7", "Medium land"))
	var medium_min_a22: int = int(medium_nums_a22[0]) if medium_nums_a22.size() > 0 else _MISSING_PARITY_VALUE
	var medium_max_a22: int = int(medium_nums_a22[1]) if medium_nums_a22.size() > 1 else _MISSING_PARITY_VALUE
	var death_min_a22 := _parity_int(md, "7", "Death", 1)
	check(int(soft_max_a22) == 22,
		"A2.2 reads PARITY §7 soft-land threshold <22 (got %d)" % int(soft_max_a22))
	check(int(medium_min_a22) == 22 and int(medium_max_a22) == 33,
		"A2.2 reads PARITY §7 medium-land window 22 ≤ speed < 33 (got %d–%d)" % [int(medium_min_a22), int(medium_max_a22)])
	check(int(death_min_a22) == 33,
		"A2.2 reads PARITY §7 death threshold ≥33 (got %d)" % int(death_min_a22))
	# normalize the PARITY thresholds onto the table constants used by the
	# landing-loop gates below, so any PARITY-vs-pop_tables drift is surfaced
	# as its own check rather than silently tainting a behavioral assertion.
	check(PopTables.SOFT_LAND_MAX == int(soft_max_a22),
		"A2.2 normalizes PARITY §7 soft-land onto PopTables.SOFT_LAND_MAX (%d == %d)" % [PopTables.SOFT_LAND_MAX, int(soft_max_a22)])
	check(PopTables.MEDIUM_LAND_MIN == int(medium_min_a22) and PopTables.MEDIUM_LAND_MAX == int(medium_max_a22),
		"A2.2 normalizes PARITY §7 medium-land onto PopTables (%d–%d == %d–%d)" % [
			PopTables.MEDIUM_LAND_MIN, PopTables.MEDIUM_LAND_MAX,
			int(medium_min_a22), int(medium_max_a22)])
	check(PopTables.DEATH_SPEED == int(death_min_a22),
		"A2.2 normalizes PARITY §7 death onto PopTables.DEATH_SPEED (%d == %d)" % [PopTables.DEATH_SPEED, int(death_min_a22)])

	# --- (b1) standing jump: 1-tile gap, cross-checked vs PARITY §4 -----
	var st: Dictionary = PopSim.initial_state(4242, level)
	var x0 := int(st["x"])
	var land_dx := -1
	var total_dx := -1
	var t := 0
	while t < 60:
		st = PopSim.step(st, PopInput.make(1, -1))  # forward+up: standing jump (seg005.c:385-395)
		t += 1
		if int(st["frame"]) == 27 and land_dx < 0:  # landing frame, PARITY §4
			land_dx = int(st["x"]) - x0
		if String(st["seq"]) == "stand":
			total_dx = int(st["x"]) - x0
			break
	check(String(st["seq"]) == "stand" and total_dx >= 0,
		"standing jump plays out and returns to stand in %d ticks (sim characterization, not parity evidence)" % t)
	var hdr4 := _parity_row(md, "4", "frame").slice(1)
	var want4 := _expand_cells(hdr4, _parity_row(md, "4", "cum x").slice(1))
	var i27 := _frame_index(hdr4, 27)
	var want_land4 := int(want4[i27]) if i27 >= 0 and i27 < want4.size() else -1
	check(land_dx == want_land4 and want_land4 >= 0,
		"standing-jump landing distance %d == PARITY §4 cum-x at f27 (%d)" % [land_dx, want_land4])
	check(land_dx >= PopTables.TILE_W,
		"standing jump covers the canonical 1-tile gap (%d >= %d units)" % [land_dx, PopTables.TILE_W])
	var want_end4 := int(want4[want4.size() - 1]) if want4.size() > 0 else -1
	check(total_dx == want_end4,
		"standing-jump total travel %d == PARITY §4 end (%d)" % [total_dx, want_end4])

	# --- (b1b) standing-jump trigger mapping: forward+Up vs plain Up ---------
	# Reference bind (PARITY §4 "Standing-jump trigger"): keyboard forward+Up
	# starts stand_jump from control_standing (seg005.c:385-395) / up_pressed
	# (seg005.c:453-458); plain Up from stand routes to the jump-up family.
	var trigger_row := _parity_row(md, "4", "Standing-jump trigger")
	check(trigger_row.size() >= 2,
		"PARITY §4 carries the Standing-jump trigger row (forward+Up → stand_jump)")
	var tj: Dictionary = PopSim.initial_state(4242, level)
	var tj0_seq := String(tj["seq"])
	var tj_fw: Dictionary = PopSim.step(tj.duplicate(), PopInput.make(1, -1))
	var tj_pu: Dictionary = PopSim.step(tj.duplicate(), PopInput.make(0, -1))
	check(String(tj_fw["seq"]) == "stand_jump",
		"forward+Up from stand starts stand_jump (PARITY-sourced §4; got %s)" % String(tj_fw["seq"]))
	check(String(tj_pu["seq"]) != "stand_jump",
		"plain Up from stand does NOT start stand_jump (PARITY-sourced §4; got %s)" % String(tj_pu["seq"]))

	# --- (b2) run jump: 2-tile gap, cross-checked vs PARITY §5 -----------
	st = PopSim.initial_state(5150, level)
	var start_x := int(st["x"])
	t = 0
	while t < 40 and String(st["seq"]) != "run_cycle":
		st = PopSim.step(st, PopInput.make(1))
		t += 1
	check(String(st["seq"]) == "run_cycle" and int(st["x"]) > start_x,
		"the kid runs forward and reaches the run cycle (x %d → %d in %d ticks; sim characterization, not parity evidence)" % [start_x, int(st["x"]), t])
	var jx0 := int(st["x"])
	var dx43 := -1
	var dx44 := -1
	var back_dx := -1
	while t < 80:
		st = PopSim.step(st, PopInput.make(1, -1))  # jump while running
		t += 1
		if int(st["frame"]) == 43 and dx43 < 0:
			dx43 = int(st["x"]) - jx0
		if int(st["frame"]) == 44 and dx44 < 0:  # cum-y back to 0 = touchdown
			dx44 = int(st["x"]) - jx0
		if String(st["seq"]) == "run_cycle":
			back_dx = int(st["x"]) - jx0
			break
	check(back_dx >= 0 and String(st["seq"]) == "run_cycle",
		"run jump lands and rejoins the run cycle (x back at +%d; sim characterization, not parity evidence)" % back_dx)
	var hdr5 := _parity_row(md, "5", "frame").slice(1)
	var want5 := _expand_cells(hdr5, _parity_row(md, "5", "cum x").slice(1))
	var i43 := _frame_index(hdr5, 43)
	var i44 := _frame_index(hdr5, 44)
	var want43 := int(want5[i43]) if i43 >= 0 and i43 < want5.size() else -1
	var want44 := int(want5[i44]) if i44 >= 0 and i44 < want5.size() else -1
	check(dx43 == want43 and want43 >= 0,
		"run-jump x at f43 = %d == PARITY §5 cum-x (%d)" % [dx43, want43])
	check(dx44 == want44 and want44 >= 0,
		"run-jump landing distance %d == PARITY §5 cum-x at f44 (%d)" % [dx44, want44])
	check(dx44 >= 2 * PopTables.TILE_W,
		"run jump covers the canonical 2-tile gap (%d >= %d units)" % [dx44, 2 * PopTables.TILE_W])
	var want_end5 := int(want5[want5.size() - 1]) if want5.size() > 0 else -1
	check(back_dx == want_end5,
		"run-jump total travel %d == PARITY §5 end (%d)" % [back_dx, want_end5])

	# --- turn and run stop: the measured durations, PARITY §18 -----------
	# The §18 tick counts cover the animation frames (turn: f45–f52; run stop:
	# f53…f52). The trailing `jmp(stand)` (`seqtbl.c:449`, `seqtbl.c:627`) does
	# not end its tick — a frame op returns from play_seq (`seg006.c:682`) — so
	# the stand frame (act + f15, `seqtbl.c:261-263`) appears one tick later.
	st = PopSim.initial_state(9, level)
	for _i: int in PopTables.TURN_TICKS:
		st = PopSim.step(st, PopInput.make(-1))
	check(int(st["frame"]) == 52 and int(st["dir"]) == -1,
		"turn covers the measured %d ticks through f45–f52 (frame %d, dir %d)" % [
			PopTables.TURN_TICKS, int(st["frame"]), int(st["dir"])])
	st = PopSim.step(st, PopInput.make(-1))
	check(String(st["seq"]) == "stand" and int(st["frame"]) == 15,
		"the trailing jmp(stand) shows the stand frame one tick later (seq %s, frame %d)" % [
			String(st["seq"]), int(st["frame"])])

	st = PopSim.initial_state(10, level)
	t = 0
	while t < 40 and String(st["seq"]) != "run_cycle":
		st = PopSim.step(st, PopInput.make(1))
		t += 1
	check(String(st["seq"]) == "run_cycle", "the kid is running before the run-stop check")
	for _i: int in PopTables.RUN_STOP_TICKS:
		st = PopSim.step(st, PopInput.make(0))  # release the direction → run stop
	check(int(st["frame"]) == 52,
		"run stop covers the measured %d ticks f53…f52 (frame %d, seq %s)" % [
			PopTables.RUN_STOP_TICKS, int(st["frame"]), String(st["seq"])])
	st = PopSim.step(st, PopInput.make(0))
	check(String(st["seq"]) == "stand" and int(st["frame"]) == 15,
		"run stop's jmp(stand) reaches the stand frame one tick later (seq %s, frame %d)" % [
			String(st["seq"]), int(st["frame"])])

	# --- (c) fall thresholds: 3 rows kills, 2 rows costs 1 HP ------------
	# Impact speed is the previous tick's fall_y accelerated +3 this tick
	# (fall_accel runs before do_fall inside the landing tick,
	# `seg006.c:870-894` then `seg005.c:37-111`), capped at 33.
	for landing_row: int in [1, 2, 3]:
		var fs: Dictionary = PopSim.initial_state(31337, _hole_level(landing_row))
		var prev_fy := int(fs["fall_y"])
		var ft := 0
		while ft < 150:
			prev_fy = int(fs["fall_y"])
			fs = PopSim.step(fs, PopInput.make(1))
			ft += 1
			if int(fs["dead"]) != 0 or String(fs["seq"]) in ["soft_land", "med_land", "hard_land"]:
				break
		var impact := mini(prev_fy + PopTables.FALL_ACCEL, PopTables.FALL_SPEED_MAX)
		if landing_row == 1:
			check(String(fs["seq"]) == "soft_land"
				and int(fs["hp"]) == PopTables.KID_HP_START
				and int(fs["y"]) == int(PopTables.Y_LAND[2]),
				"fall 1 row lands soft: impact %d < %d (A2.2→PopTables.SOFT_LAND_MAX), no HP lost (hp %d, y %d)" % [
					impact, int(soft_max_a22), int(fs["hp"]), int(fs["y"])])
		elif landing_row == 2:
			check(String(fs["seq"]) == "med_land"
				and int(fs["hp"]) == PopTables.KID_HP_START - 1
				and int(fs["dead"]) == 0,
				"fall 2 rows costs exactly 1 HP: impact %d in [%d,%d) (A2.2→PopTables.MEDIUM_LAND), hp %d → %d" % [
					impact, int(medium_min_a22), int(medium_max_a22),
					PopTables.KID_HP_START, int(fs["hp"])])
		else:
			# y distinguishes a real touchdown on the row-3 floor (y_land 244,
			# hard_land's opening dy −2 → 242) from an off-bottom fell_out
			# (`seg006.c:1321-1326`), which otherwise looks identical.
			check(int(fs["dead"]) == 1 and int(fs["hp"]) == 0
				and String(fs["seq"]) == "hard_land"
				and int(fs["y"]) == int(PopTables.Y_LAND[4]) - 2,
				"fall 3 rows kills: impact %d >= %d (A2.2→PopTables.DEATH_SPEED), hp 0, on row 3 (y %d, seq %s)" % [
					impact, int(death_min_a22), int(fs["y"]), String(fs["seq"])])

	# --- spike contact (disable-to-0xFF, impale frame, x_bump snap) ------
	var slevel: Array = []
	for r: int in 4:
		var cells: Array = []
		for c: int in 10:
			cells.append(PopTables.Tile.SPIKES if (r == 0 and c == 3) else PopTables.Tile.FLOOR)
		slevel.append(cells)
	var smods := {"0,3": 2}  # harm class 2 = extending (seg007.c:1171-1176)
	var ss: Dictionary = PopSim.initial_state(7, slevel, smods)
	var ht := 0
	while ht < 60 and int(ss["dead"]) == 0:
		ss = PopSim.step(ss, PopInput.make(1))
		ht += 1
	check(int(ss["dead"]) == 1 and int(ss["hp"]) == 0,
		"running onto extended spikes kills (hp %d, dead %d, at tick %d)" % [int(ss["hp"]), int(ss["dead"]), ht])
	check(String(ss["seq"]) == "impale" and int(ss["frame"]) == 177,
		"spike contact plays impale frame 177 (seq %s, frame %d; sim characterization, not parity evidence)" % [String(ss["seq"]), int(ss["frame"])])
	check(int(ss["y"]) == int(PopTables.Y_LAND[1]),
		"impale snaps y to the row floor (y %d == y_land %d)" % [int(ss["y"]), int(PopTables.Y_LAND[1])])
	check(int((ss["mods"] as Dictionary).get("0,3", 0)) == 0xFF,
		"the spiked tile is disabled to 0xFF (got 0x%02X)" % int((ss["mods"] as Dictionary).get("0,3", 0)))
	check(int(smods["0,3"]) == 2,
		"the caller's mods dict is untouched — a run cannot leak state (sim characterization, not parity evidence)")
	# Control: retracted spikes (mod 0xFF reads back as class 0) must let the
	# same kid run past the same tile alive.
	var hs: Dictionary = PopSim.initial_state(7, slevel, {"0,3": 0xFF})
	ht = 0
	while ht < 60 and int(hs["x"]) <= 124 and int(hs["dead"]) == 0:
		hs = PopSim.step(hs, PopInput.make(1))
		ht += 1
	check(int(hs["dead"]) == 0 and int(hs["hp"]) == PopTables.KID_HP_START and int(hs["x"]) > 124,
		"retracted spikes (0xFF) let the kid run past safely (x %d, hp %d)" % [int(hs["x"]), int(hs["hp"])])

	# --- floor-edge snap on landing (PARITY §2 "Edge snap on landing") ---
	# Reference (seg005.c:126-131 in land()): no floor ahead within 3 units of
	# the foot → Char.x = char_dx_forward(-3).
	var snap_units := _parity_int(md, "2", "Edge snap on landing")
	check(snap_units == 3,
		"A2.2 reads PARITY §2 edge snap of 3 units (got %d)" % snap_units)
	# Case 1: no floor within snap_units ahead of the foot → pulled back snap_units
	# (then soft_land's opening dx +1 moves him again — the net is −3).
	var elevel := _flat_level()
	elevel[1][6] = PopTables.Tile.EMPTY
	var snapped := _crafted_landing(elevel, 141)  # foot 139 → 2 units from edge
	check(int(snapped["x"]) == 141 - snap_units + 1,
		"edge landing with no floor ahead pulls back %d units (PARITY-sourced §2; x 141 → %d)" % [snap_units, int(snapped["x"])])
	check(int(snapped["y"]) == int(PopTables.Y_LAND[2]) and String(snapped["seq"]) == "soft_land",
		"landing snaps y to y_land and plays soft land (y %d, seq %s)" % [int(snapped["y"]), String(snapped["seq"])])
	# Case 2: same hole, but 6 units from the edge → no pull-back (3 < 6 fails).
	var loose := _crafted_landing(elevel, 137)
	check(int(loose["x"]) == 137 + 1,
		"a landing 6 units from the edge is not pulled back (PARITY-sourced §2; x 137 → %d)" % int(loose["x"]))
	# Case 3: floor continues past the edge → the first operand fails, no pull-back.
	var guarded := _crafted_landing(level, 141)
	check(int(guarded["x"]) == 141 + 1,
		"floor continuing past the edge disables the pull-back (PARITY-sourced §2; x 141 → %d)" % int(guarded["x"]))


# --- A2.3 acceptance: hang / climb / grab / crouch / safe-step (plan A2.3)
## Unlike A2.2, A2.3 cannot be scoped to a single deterministic flat-floor
## duration. Hang, grab, climb, crouch, and safe-step are geometry- and
## rule-sensitive behaviors whose acceptance is the behavioral contract:
## the pop sim / pop_input stack must land on the documented sequence,
## frame, and timer values on the explicit setups below. Scope A re-derives
## the §6/§7 stream lengths and thresholds through the same mini play_seq
## interpreter used by A2.1 so a broken sequence table fails the section;
## scope B asserts the live PopSim behavior on crafted levels.
##
func _test_a23_acceptance(md: String) -> void:
	if md.is_empty():
		md = FileAccess.get_file_as_string("res://docs/PARITY.md")
	print("  A2.3 acceptance (hang/climb/grab/crouch/safe-step) — sim behavior, not PARITY constants")
	# scope A: §6/§7 frame-count and threshold re-derivation via the mini
	# play_seq interpreter (seqtbl.c semantics, not the real PopSim step).
	var climb_up_ticks := _seq_ticks("climb_up", 18)
	# 18 is the tick count re-derived from pop_tables.SEQUENCES (6 f135–f140 +
	# 8 f141–f148 + f149 + f118 + f119 + the stand tick); §6 states only the
	# 6-frame opening, so this is a table-derived check, not a §-row value
	# (sim characterization, not parity evidence).
	check(climb_up_ticks.size() == 18,
		"climb_up runs 18 ticks (table-derived; f135–f140 + jmp(stand) over 18 ticks; seqtbl.c:590-600) (sim characterization, not parity evidence)")
	# The stream ends by jumping into `stand`, whose opening frame is the
	# SEQUENCES value (f15). Assert against that rather than a hardcoded
	# number so a stand-table edit is caught here (PARITY §6: “f141 … stand”).
	var stand_open: int = int(PopTables.SEQUENCES["stand"][1][1])
	if climb_up_ticks.size() >= 18:
		check(int(climb_up_ticks[17]["frame"]) == stand_open,
			"climb_up stream ends on the stand opening frame f%d (PARITY §6: f135–f140 … stand)" % stand_open)

	var climb_down_ticks := _seq_ticks("climb_down", 10)
	check(climb_down_ticks.size() == 10,
		"climb_down runs 10 ticks to hang sway (PARITY §6: 6 frames, then dx−5, dy+63, row+1 → hang sway in 10 frames; seqtbl.c:581-588)")
	if climb_down_ticks.size() == 10:
		check(int(climb_down_ticks[9]["frame"]) == 91,
			"climb_down ends on f91 hang sway (PARITY §6)")

	var climb_fail_ticks := _seq_ticks("climb_fail", 11)
	check(climb_fail_ticks.size() == 11,
		"climb_fail runs 11 ticks (PARITY §6: 11 frames, dx−7 → hangdrop; seqtbl.c:575-579)")
	if climb_fail_ticks.size() == 11:
		check(int(climb_fail_ticks[10]["frame"]) == 81,
			"climb_fail ends on hangdrop f81 (PARITY §6)")

	var hangdrop_ticks := _seq_ticks("hang_drop", 5)
	check(hangdrop_ticks.size() == 5,
		"hang_drop runs 5 ticks (PARITY §6: f81–f85 then dx+3 → stand; seqtbl.c:602-607)")
	if hangdrop_ticks.size() == 5:
		check(int(hangdrop_ticks[4]["frame"]) == 85,
			"hang_drop ends on f85 (PARITY §6)")

	var soft_max := _parity_int(md, "7", "Soft land", 1)
	var medium_nums: Array = _ints(_parity_cell(md, "7", "Medium land"))
	var medium_min: int = int(medium_nums[0]) if medium_nums.size() > 0 else _MISSING_PARITY_VALUE
	var medium_max: int = int(medium_nums[1]) if medium_nums.size() > 1 else _MISSING_PARITY_VALUE
	var death_min := _parity_int(md, "7", "Death", 1)
	check(int(soft_max) == 22,
		"PARITY §7 soft-land threshold <22 (got %d)" % int(soft_max))
	check(int(medium_min) == 22 and int(medium_max) == 33,
		"PARITY §7 medium-land window 22 ≤ speed < 33 (got %d–%d)" % [int(medium_min), int(medium_max)])
	check(int(death_min) == 33,
		"PARITY §7 death threshold ≥33 (got %d)" % int(death_min))

	# === Scope B: scenario behavior (explicit levels; sim behavior) =======
	# Scenario geometry below is sim-level setup, NOT a PARITY constant.
	# Only the cited PARITY numbers above are PARITY-derived.

	# pit climb: walk into a 1-tile pit with scripted inputs.
	var pit_level := _pit_level(1, 3)   # 1-tile pit, floor at row 3
	var pit: Dictionary = PopSim.initial_state(777, pit_level)
	pit["dir"] = 1
	pit["x"] = 60
	pit["seq"] = "stand"
	pit["frame"] = 15
	pit["action"] = PopTables.Action.STAND
	var pit_ticks: int = 0
	while pit_ticks < 40 and String(pit["seq"]) == "stand":
		pit = PopSim.step(pit, PopInput.make(1, 0, 0))
		pit_ticks += 1
	check(String(pit["seq"]) != "stand",
		"walking into a 1-tile pit leaves stand (sim characterization, not parity evidence)")
	check(int(pit["row"]) > 0,
		"pit walk drops the kid to row %d (sim characterization, not parity evidence)" % int(pit["row"]))

	# mid-air grab from a fall: success case.
	var grab_level := _hang_lip_level(5, 3)   # lip cols 0..4, floor at row 3
	var grab_state := _setup_hang_at_lip(PopSim.initial_state(1111, grab_level), grab_level, 133)
	grab_state["dir"] = -1
	grab_state["row"] = 1
	grab_state["y"] = 90
	grab_state["seq"] = "free_fall"
	grab_state["frame"] = 106
	grab_state["action"] = PopTables.Action.IN_FREEFALL
	grab_state["fall_y"] = 10
	grab_state["fall_x"] = 0
	var gt: int = 0
	var grabbed: bool = false
	while gt < 60 and not grabbed:
		grab_state = PopSim.step(grab_state, PopInput.make(0, 0, 1))
		gt += 1
		if int(grab_state["grab_timer"]) == PopTables.GRAB_TIMER:
			grabbed = true
	check(grabbed,
		"mid-air grab fires on a fall with Shift held and a grabbable ledge ahead-above (sim characterization, not parity evidence)")
	check(int(grab_state["grab_timer"]) == PopTables.GRAB_TIMER,
		"successful mid-air grab sets grab_timer = %d (PARITY §6: grab_timer = 12)" % int(grab_state["grab_timer"]))
	check(String(grab_state["seq"]) == "grab_hang",
		"successful mid-air grab enters grab_hang (sim characterization, not parity evidence)")

	# mid-air grab must NOT fire without Shift.
	var nograb_state := _setup_hang_at_lip(PopSim.initial_state(2222, grab_level), grab_level, 133)
	nograb_state["dir"] = -1
	nograb_state["row"] = 1
	nograb_state["y"] = 90
	nograb_state["seq"] = "free_fall"
	nograb_state["frame"] = 106
	nograb_state["action"] = PopTables.Action.IN_FREEFALL
	nograb_state["fall_y"] = 10
	nograb_state["fall_x"] = 0
	gt = 0
	var should_not_grab: bool = true
	while gt < 40 and should_not_grab:
		nograb_state = PopSim.step(nograb_state, PopInput.make(0, 0, 0))
		gt += 1
		if int(nograb_state["grab_timer"]) == PopTables.GRAB_TIMER:
			should_not_grab = false
	check(should_not_grab,
		"mid-air grab does NOT fire without Shift held (sim characterization, not parity evidence)")
	check(String(nograb_state["seq"]) != "grab_hang",
		"no-Shift fall does not enter grab_hang (sim characterization, not parity evidence)")

	# hang release / drop.
	var release_state := _setup_hang_at_lip(PopSim.initial_state(3333, grab_level), grab_level, 60)
	gt = 0
	while gt < 20 and String(release_state["seq"]) == "hang":
		release_state = PopSim.step(release_state, PopInput.make(0, 0, 0))
		gt += 1
	check(String(release_state["seq"]) == "hang_drop",
		"idle hang release ends in hang_drop (sim characterization, not parity evidence)")
	check(int(release_state["frame"]) == 81,
		"hang_drop starts on f81 (PARITY §6: hangdrop f81–f85; seqtbl.c:602-607)")

	# climb up / climb down observable sequence choices.
	var climb_state := _setup_hang_at_lip(PopSim.initial_state(4444, grab_level), grab_level, 60)
	while int(climb_state["grab_timer"]) > 0:
		climb_state = PopSim.step(climb_state, PopInput.make(0, 0, 0))
	climb_state = PopSim.step(climb_state, PopInput.make(0, -1, 0))
	check(String(climb_state["seq"]) == "climb_up",
		"Up at grab_timer 0 routes to climb_up (sim characterization, not parity evidence)")
	check(int(climb_state["frame"]) == 135,
		"climb_up starts on f135 (PARITY §6: 6 frames f135–f140; seqtbl.c:590-600)")

	# crouch.
	var crouch_state := PopSim.initial_state(5555, _flat_level())
	crouch_state["dir"] = 1
	crouch_state = PopSim.step(crouch_state, PopInput.make(0, 1, 0))
	check(String(crouch_state["seq"]) == "crouch",
		"Down from stand enters crouch (sim characterization, not parity evidence)")
	check(int(crouch_state["frame"]) == 107,
		"crouch starts on f107 (PARITY §6 context: stoop head; seqtbl.c:857-861)")

	# safe-step edge probing.
	# Floor ahead → the plain 11-unit safe step (seq_39). The flat floor
	# guarantees a standable tile ahead of the kid's column, so the
	# floor-ahead branch — not a d-unit edge step — is exercised.
	var edge_level := _flat_level()
	var edge_state := _setup_stand_at_edge(PopSim.initial_state(6666, edge_level), edge_level, 75, 1)
	edge_state = PopSim.step(edge_state, PopInput.make(1, 0, 1))
	check(String(edge_state["seq"]) == "safe_step_11",
		"shift+forward with floor ahead enters safe_step_11 (sim characterization, not parity evidence)")
	check(int(edge_state["frame"]) == 121,
		"safe_step_11 starts on f121 (PARITY §6 context: step frames; seqtbl.c:765-774)")
	print("  GAP: A2.3 scenario geometry is sim-level, not PARITY-derived (pit/grab/hang/climb/crouch/safe-step helpers above).")
	print("  GAP: A2.3 safe-step-on-edge-at-distance-0 is unmodeled (A2.3-optional; seg005.c:595-605).")


# --- Plan A4.1: gates, plates and the level exit ---------------------------
#
# Accept: a test level exercises plate→gate open/close timing within ±1 tick of
# the values in docs/PARITY.md §9/§10. Every expected number below is read from
# a PARITY row (never from sim output); machine behaviour with no independent
# oracle is labelled "sim characterization".

## A PopSim state on the A4.1 test level with the kid standing in column `col`
## (frame 15, foot offset dx−weight = −3, so x = col's left edge + 7 + 3).
func _a41_state(seed: int, col: int) -> Dictionary:
	var bundle := PopLevel.small_test_level()
	var st: Dictionary = PopSim.initial_state(seed, bundle["tiles"], bundle["mods"], bundle["entities"])
	st["row"] = 0
	st["y"] = int(PopTables.Y_LAND[1])
	st["dir"] = 1
	st["seq"] = "stand"
	st["op"] = 0
	st["frame"] = 15
	st["action"] = PopTables.Action.STAND
	st["x"] = PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN + col] + 10
	return st


func _test_a41_entities() -> void:
	var md := FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A4.1 cross-checks")
	if md.is_empty():
		return

	# --- expected values, read from PARITY §9/§10 -------------------------
	var close_delta := _parity_int(md, "9", "normal closing")            # −1
	var open_delta := _parity_int(md, "9", "opening / permanent")        # +4
	var fast_speeds: Array = _ints(_parity_cell(md, "9", "fast close (types 3–8)"))
	var open_row: Array = _ints(_parity_cell(md, "9", "open reached"))   # 188, 238, 255
	var leveldoor_row: Array = _ints(_parity_cell(md, "9", "level (exit) door"))
	var plate_timer := _parity_int(md, "10", "press timer", 2)           # 5
	var repress_below_nums: Array = _ints(_parity_cell(md, "10", "press timer", 1))

	# --- constants match those rows (anti-drift) --------------------------
	check(PopTables.DOOR_DELTA[0] == close_delta and PopTables.DOOR_DELTA[1] == open_delta,
		"DOOR_DELTA matches PARITY §9 normal-closing / opening rows")
	check(PopTables.GATE_OPEN_THRESHOLD == int(open_row[0]) and PopTables.GATE_PARKED == int(open_row[1]),
		"gate open threshold + park match PARITY §9 open-reached row")
	check(PopTables.GATE_PERMANENT == 0xFF and _parity_cell(md, "9", "open reached").contains("0xFF"),
		"permanent-open modifier 0xFF matches PARITY §9 open-reached row")
	var fast_ok := true
	for i: int in 6:
		if PopTables.GATE_CLOSE_SPEEDS[3 + i] != int(fast_speeds[i]):
			fast_ok = false
	check(fast_ok, "GATE_CLOSE_SPEEDS match PARITY §9 fast-close row (20…120)")
	check(PopTables.LEVELDOOR_START == int(leveldoor_row[4])
			and PopTables.LEVELDOOR_CLOSE_SPEEDS[1] == int(leveldoor_row[1]),
		"level-door start + speed match PARITY §9 level (exit) door row")
	check(PopTables.PLATE_HOLD_TIMER == plate_timer,
		"plate hold timer matches PARITY §10 press-timer row")
	check(PopTables.PLATE_REPRESS_BELOW == int(repress_below_nums[0]),
		"plate re-press threshold matches PARITY §10 press-timer row (stops below 2)")

	# --- level shape from the room-grid loader ---------------------------
	var bundle := PopLevel.small_test_level()
	var tiles: Array = bundle["tiles"]
	check(tiles.size() == PopLevel.ROOM_H and (tiles[0] as Array).size() == 2 * PopLevel.ROOM_W,
		"pop_level flattens two 10×3 rooms into a 3×20 tile grid")
	check(int(tiles[0][3]) == PopTables.Tile.BUTTON_RAISE
			and int(tiles[0][7]) == PopTables.Tile.GATE
			and int(tiles[0][15]) == PopTables.Tile.EXIT_DOOR_LEFT,
		"the test level places the plate, gate and exit door")

	# --- plate press + gate opening --------------------------------------
	var gate_key := "0,7"
	var st := _a41_state(4242, 3)   # kid stands on the plate at column 3
	st = PopSim.step(st, PopInput.neutral())
	var plate_timer_now: int = int((st["plates"] as Dictionary)["0,3"])
	check(plate_timer_now == PopTables.PLATE_HOLD_TIMER - 1,
		"a press sets the hold timer to 5 then decrements once (PARITY §10 press-timer row; got %d)" % plate_timer_now)
	check(int((st["gates"] as Dictionary)[gate_key]["type"]) == 1,
		"the raise plate starts the linked gate opening (PARITY §9 opening row)")

	var open_tick := 0
	var g: Dictionary = (st["gates"] as Dictionary)[gate_key]
	while int(g["mod"]) < PopTables.GATE_PARKED and int(st["tick"]) < 400:
		st = PopSim.step(st, PopInput.neutral())
		g = (st["gates"] as Dictionary)[gate_key]
		open_tick = int(st["tick"])
	check(int(g["mod"]) == PopTables.GATE_PARKED,
		"the gate parks at 238 once open (PARITY §9 open-reached row; got %d)" % int(g["mod"]))
	var expected_open_tick: int = int(open_row[0]) / PopTables.DOOR_DELTA[1]   # 188 / 4
	check(abs(open_tick - expected_open_tick) <= 1,
		"gate opens in %d±1 ticks (PARITY §9: 188 at +4/frame; got %d)" % [expected_open_tick, open_tick])

	# --- gate closing -----------------------------------------------------
	var close_tick := open_tick
	while int(g["mod"]) > 0 and int(st["tick"]) < 900:
		st = PopSim.step(st, PopInput.neutral())
		g = (st["gates"] as Dictionary)[gate_key]
		close_tick = int(st["tick"])
	check(int(g["mod"]) == 0,
		"the gate closes back to 0 (PARITY §9 close-reached row)")
	var expected_close_ticks: int = PopTables.GATE_PARKED / abs(PopTables.DOOR_DELTA[0])  # 238 / 1
	check(abs((close_tick - open_tick) - expected_close_ticks) <= 1,
		"gate closes in %d±1 ticks (PARITY §9 normal closing −1/frame; got %d)" % [expected_close_ticks, close_tick - open_tick])

	# --- re-press only after release (PARITY §10) -------------------------
	# Step off the plate until the timer drops below 2, then step back on: the
	# plate must fire the gate again.
	st["x"] = PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN + 6] + 10
	var off: Dictionary = PopSim.step(st, PopInput.neutral())
	for _i: int in 5:
		off = PopSim.step(off, PopInput.neutral())
	var off_timer: int = int((off["plates"] as Dictionary)["0,3"])
	check(off_timer < PopTables.PLATE_REPRESS_BELOW,
		"the hold timer decays below 2 after release (PARITY §10 press-timer row; got %d)" % off_timer)
	off["x"] = PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN + 3] + 10
	var back: Dictionary = PopSim.step(off, PopInput.neutral())
	var back_gate: Dictionary = (back["gates"] as Dictionary)[gate_key]
	check(int(back_gate["type"]) == 1 and int(back_gate["mod"]) > 0,
		"stepping back on the plate re-fires the gate (PARITY §10: re-press only when below 2)")

	# --- level-exit door --------------------------------------------------
	var st2 := _a41_state(99, 6)    # kid off the plate; the door still runs
	check(int((st2["exit"] as Dictionary)["mod"]) == PopTables.LEVELDOOR_START,
		"the exit door starts fully open at 43 (PARITY §9 level (exit) door row)")
	var door_ticks := 0
	while int((st2["exit"] as Dictionary)["mod"]) > 0 and door_ticks < 50:
		st2 = PopSim.step(st2, PopInput.neutral())
		door_ticks += 1
	check(int((st2["exit"] as Dictionary)["mod"]) == 0,
		"the exit door closes to 0 (PARITY §9 level (exit) door row)")
	check(door_ticks == 3,
		"the exit door fast-closes in 3 ticks through the {0,5,17,99} ramp (PARITY §9; got %d)" % door_ticks)

	# --- closer plate fires a fast close (PARITY §9 fast-close row) --------
	var closer := {
		"gates": {"0,2": {"mod": PopTables.GATE_PARKED, "type": 0}},
		"plates": {"0,1": 0},
		"links": [{"plate": "0,1", "gate": "0,2"}],
		"exit": {},
	}
	PopLevel.step_entities(closer, 0, 1, PopTables.Tile.BUTTON_DROP)
	var closer_gate: Dictionary = closer["gates"]["0,2"]
	check(int(closer_gate["type"]) >= 3 and int(closer_gate["mod"]) < PopTables.GATE_PARKED,
		"a closer plate starts a fast close (PARITY §9 fast-close row; seg007.c:636-637)")

	# --- determinism: entity state is inside the hash ---------------------
	var e1 := _a41_state(4242, 3)
	var e2 := _a41_state(4242, 3)
	for _i: int in 60:
		e1 = PopSim.step(e1, PopInput.neutral())
		e2 = PopSim.step(e2, PopInput.neutral())
	check(PopSim.hash_state(e1) == PopSim.hash_state(e2),
		"two identical plate runs hash equal, gate/plate state included")
	var e3 := _a41_state(9999, 3)
	for _i: int in 60:
		e3 = PopSim.step(e3, PopInput.neutral())
	check(PopSim.hash_state(e1) != PopSim.hash_state(e3),
		"a different seed diverges with gate/plate state in the hash")


# --- Plan B1 (thin slice): input-byte echo --------------------------------
#
# Accept (plan §8 gate 4): record N ticks of input bytes, release a second sim
# participant that replays them, it triggers a plate, and the state hashes are
# identical across two runs — while flipping one recorded bit makes the run
# diverge. Reuses pop_input bytes; the legacy TemporalManager path is untouched.
func _test_b1_minimal_echo() -> void:
	var bundle := PopLevel.small_test_level()
	# Hold right for 40 ticks: the kid runs from column 0 across the plate at
	# column 3, which triggers the linked gate.
	var script: Array = []
	for _i: int in 40:
		script.append(PopInput.make(1, 0, 0).to_byte())

	var rec: Dictionary = PopReplay.record_run(20261008, script,
		bundle["tiles"], bundle["mods"], bundle["entities"])
	var echo: PopReplay = rec["replay"]
	var recorded: Dictionary = rec["final"]
	check(echo.size() == 40, "the echo recorded 40 input ticks (plan B1)")

	# A second sim participant replays the recorded bytes into its own run.
	var a: Dictionary = echo.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	var b: Dictionary = echo.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	check(PopSim.hash_state(a) == PopSim.hash_state(recorded),
		"the replay participant reproduces the recorded final state")
	check(PopSim.hash_state(a) == PopSim.hash_state(b),
		"two replays of the same recording hash identical (plan §8 gate 4)")
	var gate: Dictionary = (a["gates"] as Dictionary)["0,7"]
	check(int(gate["mod"]) > PopTables.GATE_CLOSED,
		"the replayed run triggers the plate, which moves the linked gate")

	# Flipping one recorded input bit must change the run (causality).
	var flipped: PopReplay = echo.with_flipped_bit(5, 0)
	var diverged: Dictionary = flipped.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	check(PopSim.hash_state(diverged) != PopSim.hash_state(a),
		"flipping one recorded bit makes the run diverge (plan §8 gate 4)")


# --- Plan A4.2: spikes, loose floors and chompers --------------------------
#
# Accept: replayed testcases reproduce documented outcomes; unit tests assert
# modifier-state transitions from PARITY.md §8/§11 tables. Every expected
# number is read from a PARITY row; anything without an independent oracle is
# labelled "sim characterization".

## A flat 4x16 level with one `tile` at (0, `col`).
func _a42_level(tile: int, col: int) -> Array:
	var level: Array = []
	for r: int in 4:
		var cells: Array = []
		for c: int in 16:
			cells.append(tile if (r == 0 and c == col) else PopTables.Tile.FLOOR)
		level.append(cells)
	return level


## A standing kid in column `kid_col` of a level carrying `tile` at `col`.
func _a42_state(seed: int, kid_col: int, tile: int, col: int) -> Dictionary:
	var st: Dictionary = PopSim.initial_state(seed, _a42_level(tile, col))
	st["row"] = 0
	st["y"] = int(PopTables.Y_LAND[1])
	st["dir"] = 1
	st["seq"] = "stand"
	st["op"] = 0
	st["frame"] = 15
	st["action"] = PopTables.Action.STAND
	st["x"] = PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN + kid_col] + 10
	return st


func _test_a42_traps() -> void:
	var md := FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A4.2 cross-checks")
	if md.is_empty():
		return

	# --- expected values, read from PARITY §8/§11 -------------------------
	var extend_frames := _parity_int(md, "8", "extend", 2)        # 5
	var hold_frames := _parity_int(md, "8", "extended hold", 2)    # 15
	var retract_frames := _parity_int(md, "8", "retract", 2)       # 3
	var delay_nums: Array = _ints(_parity_cell(md, "11", "press→fall delay"))
	var shake_text := _parity_cell(md, "11", "shake band")
	var crush_text := _parity_cell(md, "11", "crush test")
	var chomp_text := _parity_cell(md, "11", "chomper cycle")

	check(extend_frames == 5 and hold_frames == 15 and retract_frames == 3,
		"PARITY §8 phase counts read as 5/15/3")
	check(PopTables.SPIKE_CYCLE_TICKS == extend_frames + hold_frames + retract_frames,
		"SPIKE_CYCLE_TICKS equals the PARITY §8 phase sum (got %d)" % PopTables.SPIKE_CYCLE_TICKS)
	check(PopTables.LOOSE_FALL_DELAY == int(delay_nums[0]),
		"LOOSE_FALL_DELAY matches PARITY §11 press→fall delay row (got %d)" % int(delay_nums[0]))
	check(PopTables.LOOSE_SHAKE_START == 0x80 and PopTables.LOOSE_SHAKE_RESET == 0x84
			and shake_text.contains("0x80") and shake_text.contains("0x83") and shake_text.contains("0x84"),
		"shake band 0x80–0x83 / reset ≥0x84 matches PARITY §11 shake-band row")
	check(PopTables.CRUSH_DEPTH == 30 and crush_text.contains("30"),
		"CRUSH_DEPTH 30 matches PARITY §11 crush-test row")
	check(PopTables.CHOMPER_FRAMES == 15 and chomp_text.contains("15 frames")
			and chomp_text.contains("frame 2") and chomp_text.contains("0x80")
			and chomp_text.contains("frame 6"),
		"chomper cycle 15 / bite frame 2 / blood 0x80 / stop past frame 6 match PARITY §11")

	# --- spike cycle: modifier transitions (PARITY §8) --------------------
	var st := _a42_state(7, 2, PopTables.Tile.SPIKES, 5)
	check(PopLevel.trigger(st, 0, 5), "a spike tile starts its animation (sim characterization, not parity evidence)")
	var sseq: Array = []
	for _i: int in 26:
		st = PopSim.step(st, PopInput.neutral())
		sseq.append(int((st["mods"] as Dictionary).get("0,5", 0)))
	check(int(sseq[0]) == 1 and int(sseq[3]) == 4,
		"extend runs 1..4 over 4 ticks (PARITY §8 extend row; got %d..%d)" % [sseq[0], sseq[3]])
	check(int(sseq[4]) == PopTables.SPIKE_HOLD_START,
		"the 5th extend frame snaps to the hold modifier 0x8F (PARITY §8 extend row)")
	check(int(sseq[18]) == PopTables.SPIKE_HOLD_END,
		"the hold counts down to 0x81 after 15 frames (PARITY §8 hold row; got 0x%02X)" % int(sseq[18]))
	check(int(sseq[19]) == PopTables.SPIKE_RETRACT_START,
		"retract begins at 6 (PARITY §8 hold row: …→6)")
	check(int(sseq[20]) == 7 and int(sseq[21]) == 8,
		"retract runs 7 then 8 (PARITY §8 retract row)")
	check(int(sseq[22]) == 0 and int(sseq[23]) == 0,
		"the cycle resets to 0 and stops on tick 23 (PARITY §8 retract row: 9→0, stop)")

	# --- harmful-state rules (PARITY §8 "Harmful?") -----------------------
	var extend_harm := _parity_cell(md, "8", "extend", 3)
	var hold_harm := _parity_cell(md, "8", "extended hold", 3)
	var retract_harm := _parity_cell(md, "8", "retract", 3)
	var disabled_harm := _parity_cell(md, "8", "disabled", 3)
	var cls_ok := true
	for m: int in [1, 2, 3, 4]:
		if PopSim._spike_harm_class(m) != 2:
			cls_ok = false
	check(cls_ok and extend_harm.contains("class 2"),
		"modifiers 1–4 are class 2 (PARITY §8 extend row)")
	check(PopSim._spike_harm_class(PopTables.SPIKE_HOLD_START) == 1 and hold_harm.contains("class 1"),
		"the hold modifier is class 1 (PARITY §8 hold row)")
	var retract_ok := true
	for m: int in [6, 7, 8]:
		if PopSim._spike_harm_class(m) != 0:
			retract_ok = false
	check(retract_ok and retract_harm.contains("no"),
		"retract modifiers 6/7/8 are harmless (PARITY §8 retract row)")
	check(PopSim._spike_harm_class(PopTables.SPIKE_DISABLED) == 0 and disabled_harm.contains("no"),
		"0xFF is harmless (PARITY §8 disabled row)")

	# --- replayed testcase: extend kills, retract is safe -----------------
	var kill_level := _a42_level(PopTables.Tile.SPIKES, 3)
	var ks: Dictionary = PopSim.initial_state(7, kill_level, {"0,3": 3})  # PARITY §8 extend row
	var kt := 0
	while kt < 60 and int(ks["dead"]) == 0:
		ks = PopSim.step(ks, PopInput.make(1))
		kt += 1
	check(int(ks["dead"]) == 1,
		"replay: running spikes in the extend window (mod 3) kill (PARITY §8 extend row)")
	var ok_level := _a42_level(PopTables.Tile.SPIKES, 3)
	var os: Dictionary = PopSim.initial_state(7, ok_level, {"0,3": 8})  # PARITY §8 retract row
	kt = 0
	while kt < 60 and int(os["x"]) <= 124 and int(os["dead"]) == 0:
		os = PopSim.step(os, PopInput.make(1))
		kt += 1
	check(int(os["dead"]) == 0 and int(os["x"]) > 124,
		"replay: the retract window (mod 8) lets him run past (PARITY §8 retract row)")

	# --- loose floor: press→fall delay (PARITY §11) -----------------------
	var lst := _a42_state(5, 2, PopTables.Tile.FLOOR_LOOSE, 5)
	check(PopLevel.trigger(lst, 0, 5), "a loose floor starts its countdown (sim characterization, not parity evidence)")
	var lseq: Array = []
	for _i: int in 13:
		lst = PopSim.step(lst, PopInput.neutral())
		lseq.append(int((lst["mods"] as Dictionary).get("0,5", 0)))
	check(int(lseq[9]) == 10 and int(lseq[10]) == 0,
		"the loose floor counts 1..10 then detaches on tick 11 (PARITY §11 press→fall delay row)")
	check(int((lst["tiles"] as Array)[0][5]) == PopTables.Tile.EMPTY,
		"the detached floor leaves an empty tile (sim characterization of the fall)")

	# --- loose floor: shake band (PARITY §11) -----------------------------
	var sst := _a42_state(6, 2, PopTables.Tile.FLOOR_LOOSE, 5)
	(sst["mods"] as Dictionary)["0,5"] = PopTables.LOOSE_SHAKE_START
	check(PopLevel.trigger(sst, 0, 5), "a loose floor in the shake band keeps shaking (sim characterization, not parity evidence)")
	var shake_seq: Array = []
	for _i: int in 6:
		sst = PopSim.step(sst, PopInput.neutral())
		shake_seq.append(int((sst["mods"] as Dictionary).get("0,5", 0)))
	check(int(shake_seq[0]) == 0x81 and int(shake_seq[2]) == 0x83,
		"the shake band steps 0x81→0x83 (PARITY §11 shake-band row)")
	check(int(shake_seq[3]) == 0 and int(shake_seq[4]) == 0,
		"reaching 0x84 resets the modifier to 0 (PARITY §11 shake-band row)")

	# --- the kid falls through a floor that detaches under him -------------
	var fdt := _a42_state(8, 5, PopTables.Tile.FLOOR_LOOSE, 5)  # kid ON the loose floor
	check(PopLevel.trigger(fdt, 0, 5), "a loose floor under the kid starts its countdown")
	var fell := false
	for _i: int in 14:
		fdt = PopSim.step(fdt, PopInput.neutral())
		if int((fdt["tiles"] as Array)[0][5]) == PopTables.Tile.EMPTY \
				and String(fdt["seq"]) != "stand":
			fell = true
	check(fell, "the kid falls through the detached floor (sim characterization, not parity evidence)")

	# --- chomper cycle (PARITY §11) ---------------------------------------
	var cst := _a42_state(9, 2, PopTables.Tile.CHOMPER, 5)
	check(PopLevel.trigger(cst, 0, 5), "a chomper starts its cycle (sim characterization, not parity evidence)")
	var cseq: Array = []
	for _i: int in 18:
		cst = PopSim.step(cst, PopInput.neutral())
		cseq.append(int((cst["mods"] as Dictionary).get("0,5", 0)))
	check(int(cseq[0]) == 1 and int(cseq[14]) == 15,
		"the chomper counts frames 1..15 (PARITY §11 chomper-cycle row)")
	check(int(cseq[15]) == 1,
		"frame 16 wraps back to 1 (PARITY §11 chomper-cycle row; got %d)" % int(cseq[15]))
	check((cst["anims"] as Dictionary).has("0,5"),
		"the chomper keeps cycling while the kid is alive in its row (sim characterization, not parity evidence)")

	# --- chomper stop rule: kid left the row (PARITY §11) -----------------
	var sst2 := _a42_state(10, 2, PopTables.Tile.CHOMPER, 5)
	sst2["row"] = 1   # the kid has left the chomper's row
	check(PopLevel.trigger(sst2, 0, 5), "the chomper starts with the kid one row down")
	var stopped := false
	for _i: int in 12:
		sst2 = PopSim.step(sst2, PopInput.neutral())
		if not (sst2["anims"] as Dictionary).has("0,5"):
			stopped = true
	check(stopped, "the chomper stops past frame 6 when the kid left its row (PARITY §11)")

	# --- chomper bite sets the blood flag on frame 2 (PARITY §11) ---------
	var bst := _a42_state(11, 5, PopTables.Tile.CHOMPER, 5)  # kid ON the chomper tile
	check(PopLevel.trigger(bst, 0, 5), "the chomper starts with the kid in its tile")
	var bitten := -1
	for _i: int in 4:
		bst = PopSim.step(bst, PopInput.neutral())
		var bm: int = int((bst["mods"] as Dictionary).get("0,5", 0))
		# capture the first tick the blood flag appears — it must be frame 2
		if (bm & PopTables.CHOMPER_BLOOD) and bitten == -1:
			bitten = bm
	check(bitten != -1 and (bitten & 0x7F) == PopTables.CHOMPER_BITE_FRAME,
		"biting the kid sets the blood flag on frame 2 (PARITY §11 chomper-cycle row; got 0x%02X)" % bitten)

	# --- crush rule (PARITY §11 crush-test row) ---------------------------
	var kid_y := int(PopTables.Y_LAND[1])
	check(PopLevel.crush_test(kid_y, kid_y - 10, 3, 3),
		"a block 10 units ABOVE the feet crushes (PARITY §11 crush-test row; seg007.c:1591-1601)")
	check(not PopLevel.crush_test(kid_y, kid_y - PopTables.CRUSH_DEPTH - 1, 3, 3),
		"a block 31 units above the feet does not (PARITY §11 crush-test row)")
	check(not PopLevel.crush_test(kid_y, kid_y + 10, 3, 3),
		"a block below the feet does not (seg007.c:1591 curmob.y < Char.y)")
	check(not PopLevel.crush_test(kid_y, kid_y - 10, 3, 4),
		"a different column is not a crush (PARITY §11 crush-test row)")

	# --- the falling block actually crushes a kid below it -----------------
	var cdt := _a42_state(12, 5, PopTables.Tile.FLOOR_LOOSE, 5)
	cdt["row"] = 1
	cdt["y"] = int(PopTables.Y_LAND[2])   # the kid stands a row below that floor
	check(PopLevel.trigger(cdt, 0, 5), "the loose floor above the kid starts its countdown")
	var hit := false
	for _i: int in 30:
		cdt = PopSim.step(cdt, PopInput.neutral())
		if int(cdt["hp"]) < PopTables.KID_HP_START:
			hit = true
	check(hit, "the falling block crushes a kid in the same column below it (PARITY §11 crush-test row; seg007.c:1591-1601; hp %d)" % int(cdt["hp"]))

	# The same run twice must hash equal — the falling block is part of state.
	var cdt2 := _a42_state(12, 5, PopTables.Tile.FLOOR_LOOSE, 5)
	cdt2["row"] = 1
	cdt2["y"] = int(PopTables.Y_LAND[2])
	check(PopLevel.trigger(cdt2, 0, 5), "the determinism run triggers the same floor")
	for _i: int in 30:
		cdt2 = PopSim.step(cdt2, PopInput.neutral())
	check(PopSim.hash_state(cdt) == PopSim.hash_state(cdt2),
		"the crush run is reproducible with the falling block in the hash")


# --- Plan A4.3: the guard duel ---------------------------------------------
#
# Accept: scripted duel inputs vs. skill-0 guard win/lose deterministically;
# re-run with seed=N produces identical duel transcripts. Expected values come
# from PARITY §12 (decision tables/HP) and §13 (sword frames); §14 names the
# generator. Anything without an independent oracle is "sim characterization".

## The 12 skill cells of a PARITY §12 table row (cells 1..12 = skill 0..11).
func _a43_row(md: String, label: String) -> Array:
	var cells := _parity_row(md, "12", label)
	var out: Array = []
	for i: int in range(1, 13):
		var nums: Array = _ints(String(cells[i])) if i < cells.size() else []
		out.append(int(nums[0]) if nums.size() > 0 else _MISSING_PARITY_VALUE)
	return out


func _test_a43_duel() -> void:
	var md := FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A4.3 cross-checks")
	if md.is_empty():
		return

	# --- §12 decision tables / HP (anti-drift) ----------------------------
	check(_a43_row(md, "strike odds") == PopGuard.STRIKE_ODDS, "strike odds match PARITY §12")
	check(_a43_row(md, "re-strike odds") == PopGuard.RESTRIKE_ODDS, "re-strike odds match PARITY §12")
	check(_a43_row(md, "block odds") == PopGuard.BLOCK_ODDS, "block odds match PARITY §12")
	check(_a43_row(md, "immediate re-block odds") == PopGuard.IMPBLOCK_ODDS, "immediate re-block odds match PARITY §12")
	check(_a43_row(md, "advance odds") == PopGuard.ADVANCE_ODDS, "advance odds match PARITY §12")
	check(_a43_row(md, "refractory frames") == PopGuard.REFRACTIMER, "refractory frames match PARITY §12")
	check(_a43_row(md, "bonus HP") == PopGuard.BONUS_HP, "bonus HP matches PARITY §12")
	check(_a43_row(md, "base HP") == PopGuard.BASE_HP, "base HP matches PARITY §12")
	check(PopGuard.guard_hp(0) == 4, "a skill-0 guard has 4 HP (PARITY §12 base 4 + bonus 0)")
	check(PopGuard.REFRACTIMER[0] == 16, "skill-0 refractory is 16 frames (PARITY §12)")

	# --- §13 sword frame chains ------------------------------------------
	var ready_cell := _parity_cell(md, "13", "ready", 1)
	var strike_cell := _parity_cell(md, "13", "strike", 1)
	var block_cell := _parity_cell(md, "13", "block", 1)
	var s13 := _parity_section(md, "13")
	check(ready_cell.contains("f158") and PopGuard.READY_FRAME == 158,
		"the ready frame f158 matches PARITY §13")
	check(strike_cell.contains("f168") and strike_cell.contains("f157")
			and PopGuard.CHAIN_STRIKE == [168, 151, 152, 153, 154, 155, 156, 157],
		"the strike chain matches PARITY §13 (f168…f157, 8 frames)")
	check(block_cell.contains("f169") and block_cell.contains("f150")
			and PopGuard.CHAIN_BLOCK == [169, 150],
		"the block chain matches PARITY §13 (f169→f150)")
	check(s13.contains("f153, f154") and PopGuard.KID_HIT_FRAMES == [153, 154],
		"the kid's hit window f153/f154 matches PARITY §13")
	check(s13.contains("f150 or f161") and PopGuard.PARRY_FRAMES == [150, 161],
		"the parry frames f150/f161 match PARITY §13")

	# --- a strike lands only when the defender is not parrying ------------
	var g1 := PopGuard.initial(0)
	var k1 := PopGuard.initial_kid()
	g1["seq"] = "strike"
	g1["frame"] = PopGuard.KID_HIT_FRAMES[0]     # the guard is in its hit window
	g1["index"] = 3
	var t1: Array = []
	PopGuard._resolve(k1, g1, t1)
	check(int(k1["hp"]) == PopTables.KID_HP_START - 1,
		"a strike in f153 hits an undefended kid (PARITY §13 hit window; hp %d)" % int(k1["hp"]))
	check(t1 == ["kid:hit"], "the hit is recorded in the transcript")

	var g2 := PopGuard.initial(0)
	var k2 := PopGuard.initial_kid()
	g2["seq"] = "strike"
	g2["frame"] = PopGuard.KID_HIT_FRAMES[0]
	k2["seq"] = "block"
	k2["frame"] = PopGuard.PARRY_FRAMES[0]       # f150 = parry
	var t2: Array = []
	PopGuard._resolve(k2, g2, t2)
	check(int(k2["hp"]) == PopTables.KID_HP_START and String(g2["seq"]) == "blocked",
		"a parry at f150 stops the hit and turns the strike aside (PARITY §13)")
	check(t2 == ["k:parry"], "the parry is recorded in the transcript")

	# --- the scripted duel (plan §8 gate 3) -------------------------------
	var attack: Array = []
	for i: int in 400:
		attack.append("strike" if (i % 5) == 0 else "ready")
	var w1 := PopGuard.duel(20261008, 0, attack, 400)
	var w2 := PopGuard.duel(20261008, 0, attack, 400)
	check((w1["transcript"] as Array) == (w2["transcript"] as Array),
		"same seed → identical duel transcript (plan §8 gate 3)")
	check(String(w1["winner"]) == String(w2["winner"])
			and int(w1["guard_hp"]) == int(w2["guard_hp"])
			and int(w1["kid_hp"]) == int(w2["kid_hp"]),
		"same seed → identical duel outcome")
	check(String(w1["winner"]) == "kid" or String(w1["winner"]) == "guard",
		"the scripted duel runs to a win or a lose (winner %s after %d ticks; guard hp %d, kid hp %d)" % [
			String(w1["winner"]), int(w1["ticks"]), int(w1["guard_hp"]), int(w1["kid_hp"])])

	# --- the seed is actually in play (§14 generator) ----------------------
	var pacing: Array = []
	for i: int in 400:
		pacing.append("ready" if (i % 4) == 3 else "block")   # ~50% parry coverage
	var p1 := PopGuard.duel(20261008, 0, pacing, 400)
	var p2 := PopGuard.duel(777, 0, pacing, 400)
	check((p1["transcript"] as Array) == (PopGuard.duel(20261008, 0, pacing, 400)["transcript"] as Array),
		"the long pacing run is reproducible for the same seed")
	check((p1["transcript"] as Array) != (p2["transcript"] as Array),
		"a different seed produces a different duel transcript (PARITY §14 generator)")
	print("  MEAS duel(seed 20261008, skill 0, attack): winner=%s ticks=%d guard_hp=%d kid_hp=%d transcript=%d events" % [
		String(w1["winner"]), int(w1["ticks"]), int(w1["guard_hp"]), int(w1["kid_hp"]),
		(w1["transcript"] as Array).size()])
	print("  GAP: A4.3 — spiked/chomped *causes* of death are not wired into the duel (both parties die on HP only); guard advance/retreat dx does not gate reach.")
