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

	_section("Held-plate gate hold (PARITY §10; seg007.c:764)")
	_test_held_plate_gate_hold()

	_section("B1 minimal input-byte echo (plan B1 / §8 gate 4)")
	_test_b1_minimal_echo()

	_section("A4.2 spikes, loose floors and chompers (plan A4.2)")
	_test_a42_traps()

	_section("A4.3 guard duel at 10 fps (plan A4.3 / §8 gate 3)")
	_test_a43_duel()

	_section("A5.1 parity harness (plan A5.1)")
	_test_a51_harness("")

	_section("B0 sim path (plan B0.1)")
	_test_b0_sim_path()

	_section("B0 echo on the sim path (plan B0.1 step 4)")
	_test_b0_echo()

	_section("B1.3 echo presses sim-side plates (plan B1.3)")
	_test_b13_echo_plate()

	_section("Guard duel on the sim path (plan §4.7, session 010)")
	_test_sim_guard_duel()

	_section("Level 2 Hall of Echoes (plan B1.3 + trim L2, session 010)")
	_test_b13_level2()

	_section("Level 3 boss: the Time Warden's echo-gated shield (plan B2.3/B3.1, session 011)")
	await _test_b23_level3_boss()

	_section("SoundEvents hook points (session 010 step 4)")
	_test_sound_events()

	_section("SfxPlayer wiring: id -> stream, pool, echo treatment (session 013 step 1)")
	_test_sfx_player()

	_section("View: world-to-screen mapping (session 011 step 2; VIEW tests, not parity)")
	_test_view_mapping()

	_section("B0 completability smoke (plan 8 gate 5)")
	_test_b0_completability()

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
		"pop_level flattens two 10×3 rooms into a 3×20 tile grid (sim characterization: hand-built fixture, no external oracle)")
	check(int(tiles[0][3]) == PopTables.Tile.BUTTON_RAISE
			and int(tiles[0][7]) == PopTables.Tile.GATE
			and int(tiles[0][15]) == PopTables.Tile.EXIT_DOOR_LEFT,
		"the test level places the plate, gate and exit door (sim characterization: hand-built fixture)")

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
	# The close schedule is observable AFTER release: while the kid stands on
	# the plate the reference re-triggers its links every held tick
	# (`seg007.c:764`), re-parking the gate at 238 — a held plate's gate never
	# closes. So step him off (col 3 -> col 6) and watch the §9 close run.
	st["x"] = PopTables.X_BUMP[PopTables.FIRST_ONSCREEN_COLUMN + 6] + 10
	var close_tick := open_tick
	while int(g["mod"]) > 0 and int(st["tick"]) < 900:
		st = PopSim.step(st, PopInput.neutral())
		g = (st["gates"] as Dictionary)[gate_key]
		close_tick = int(st["tick"])
	check(int(g["mod"]) == 0,
		"the gate closes back to 0 once the kid steps off (PARITY §9 close-reached row)")
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
		"the exit door fast-closes in 3 ticks through the {0,5,17,99} ramp (PARITY §9 arithmetic on level-door rows; got %d)" % door_ticks)

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
		"two identical plate runs hash equal, gate/plate state included (sim characterization: determinism probe)")
	var e3 := _a41_state(9999, 3)
	for _i: int in 60:
		e3 = PopSim.step(e3, PopInput.neutral())
	check(PopSim.hash_state(e1) != PopSim.hash_state(e3),
		"a different seed diverges with gate/plate state in the hash (sim characterization: determinism probe)")


## Session 010 regression (B1.3 / level 2's mechanism): the reference
## re-triggers a held plate's links EVERY tick (`seg007.c:764`, do_trigger_list
## sits outside the link_timer < 2 branch), so a body standing on a raise plate
## keeps re-parking its gate at GATE_PARKED and the gate never closes while
## held — stepping off hands control back to the §9 close schedule. This is
## the exact mechanic a temporal echo rides to hold a gate open for the kid.
func _test_held_plate_gate_hold() -> void:
	var bundle := PopLevel.small_test_level()
	var s: Dictionary = PopSim.initial_state(
		4242, bundle["tiles"], bundle["mods"], bundle["entities"])
	var gate_key := "0,7"

	# (1) A body held on the plate re-triggers the gate each tick: from the
	# first press it opens at +4/tick, parks at 238, then oscillates 238/237
	# (re-park, then the -1 close tick) — always >= the open threshold.
	var parked_tick := -1
	var ever_closed_while_held := false
	for tick: int in 120:
		PopLevel.step_entities(s, 0, 3, PopTables.Tile.BUTTON_RAISE)
		var mod := int((s["gates"][gate_key] as Dictionary)["mod"])
		if mod >= PopTables.GATE_PARKED and parked_tick < 0:
			parked_tick = tick
		if parked_tick >= 0 and mod < PopTables.GATE_OPEN_THRESHOLD:
			ever_closed_while_held = true
	check(parked_tick == 46,
		"a held plate parks its gate at %d on tick 46 (the 47th held tick: 4*47 = 188 crosses the threshold, PARITY §9 open-reached row; got %d)" % [
			PopTables.GATE_PARKED, parked_tick])
	check(not ever_closed_while_held,
		"the gate stays >= %d open for the whole hold (seg007.c:781 re-park, PARITY §10)" % PopTables.GATE_OPEN_THRESHOLD)
	check(int(s["plates"]["0,3"]) == PopTables.PLATE_HOLD_TIMER - 1,
		"the plate timer settles at %d while held (PARITY §10 press-timer row)" % (PopTables.PLATE_HOLD_TIMER - 1))

	# (2) Stepping off hands control to the close schedule: the park value
	# then falls -1/tick (PARITY §9 closing row) — below the open threshold
	# after 50 ticks and fully closed exactly `mod_at_stepoff` ticks later.
	var mod_off := int((s["gates"][gate_key] as Dictionary)["mod"])
	var below_threshold := -1
	var reached_zero := -1
	for tick: int in 300:
		PopLevel.step_entities(s, 0, 0, PopTables.Tile.FLOOR)   # off the plate
		var mod := int((s["gates"][gate_key] as Dictionary)["mod"])
		if mod < PopTables.GATE_OPEN_THRESHOLD and below_threshold < 0:
			below_threshold = tick
		if mod == 0 and reached_zero < 0:
			reached_zero = tick
	check(below_threshold == mod_off - PopTables.GATE_OPEN_THRESHOLD,
		"after stepping off the gate drops below %d at tick %d (the §9 -1/tick close from %d)" % [
			PopTables.GATE_OPEN_THRESHOLD, below_threshold, mod_off])
	check(reached_zero == mod_off - 1,
		"the gate closes fully %d ticks after stepping off (PARITY §9 park-to-zero row; got %d)" % [
			mod_off - 1, reached_zero])


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
	check(echo.events.size() == echo.size(),
		"every recorded tick carries an event vector (plan §8 gate 4)")

	# The echo participant must run the SAME pop_sim.step as the player: a
	# manual PopSim.step loop over the recorded bytes equals replay().
	var manual: Dictionary = PopSim.initial_state(echo.seed,
		bundle["tiles"], bundle["mods"], bundle["entities"])
	for packed: Variant in echo.bytes:
		manual = PopSim.step(manual, PopInput.from_byte(int(packed)))
	var a: Dictionary = echo.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	check(PopSim.hash_state(manual) == PopSim.hash_state(a),
		"the echo participant steps through the same pop_sim.step as the player")

	# Two full runs: identical state hashes AND identical event vectors.
	var b: Dictionary = echo.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	check(PopSim.hash_state(a) == PopSim.hash_state(recorded),
		"the replay participant reproduces the recorded final state")
	check(PopSim.hash_state(a) == PopSim.hash_state(b),
		"two replays of the same recording hash identical (plan §8 gate 4)")
	var ra: Dictionary = echo.replay_events(bundle["tiles"], bundle["mods"], bundle["entities"])
	var rb: Dictionary = echo.replay_events(bundle["tiles"], bundle["mods"], bundle["entities"])
	check((ra["events"] as Array) == echo.events,
		"the replayed event vector matches the recorded one")
	check((ra["events"] as Array) == (rb["events"] as Array),
		"two runs produce identical event vectors (plan §8 gate 4)")
	var vec_text: String = "|".join(ra["events"] as Array)
	check(vec_text.contains("press:0,3"),
		"the event vector records the plate press (plan §8 gate 4)")
	check(vec_text.contains("opening:0,7"),
		"the event vector records the linked gate opening (PARITY §9)")
	var gate: Dictionary = (a["gates"] as Dictionary)["0,7"]
	check(int(gate["mod"]) > PopTables.GATE_CLOSED,
		"the replayed run triggers the plate, which moves the linked gate")

	# Flipping one recorded input bit must change the run (causality).
	var flipped: PopReplay = echo.with_flipped_bit(5, 0)
	var diverged: Dictionary = flipped.replay(bundle["tiles"], bundle["mods"], bundle["entities"])
	check(PopSim.hash_state(diverged) != PopSim.hash_state(a),
		"flipping one recorded bit makes the run diverge (plan §8 gate 4)")

	# --- bounded ring: 8 s at 12 fps = 96 bytes (plan B1.1) ---------------
	var long_script: Array = []
	for i: int in 120:
		long_script.append(PopInput.make(1 if i % 20 < 10 else 0, 0, 0).to_byte())
	var ring_rec: Dictionary = PopReplay.record_run(7, long_script,
		bundle["tiles"], bundle["mods"], bundle["entities"])
	var ring: PopReplay = ring_rec["replay"]
	check(ring.size() == PopReplay.RING_CAPACITY,
		"the ring caps the buffer at 96 bytes (8 s at 12 fps; got %d)" % ring.size())
	check(ring.at_capacity(), "the cap is actually engaged, not just short of it")
	check(int(ring.bytes[0]) == int(long_script[120 - PopReplay.RING_CAPACITY]),
		"the ring evicts the oldest byte first (bounded ring, plan B1.1)")
	check(ring.events.size() == ring.size(),
		"event vectors are evicted together with their bytes (ring-aligned)")


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
		"a block 10 units ABOVE the feet crushes (PARITY §11 crush-test row; seg007.c:1185-1195)")
	check(not PopLevel.crush_test(kid_y, kid_y - PopTables.CRUSH_DEPTH - 1, 3, 3),
		"a block 31 units above the feet does not (PARITY §11 crush-test row)")
	check(not PopLevel.crush_test(kid_y, kid_y + 10, 3, 3),
		"a block below the feet does not (seg007.c:1185 curmob.y < Char.y)")
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
	check(hit, "the falling block crushes a kid in the same column below it (PARITY §11 crush-test row; seg007.c:1185-1195; fall rate is sim characterization, PARITY §7 placeholder; hp %d)" % int(cdt["hp"]))

	# The same run twice must hash equal — the falling block is part of state.
	var cdt2 := _a42_state(12, 5, PopTables.Tile.FLOOR_LOOSE, 5)
	cdt2["row"] = 1
	cdt2["y"] = int(PopTables.Y_LAND[2])
	check(PopLevel.trigger(cdt2, 0, 5), "the determinism run triggers the same floor")
	for _i: int in 30:
		cdt2 = PopSim.step(cdt2, PopInput.neutral())
	check(PopSim.hash_state(cdt) == PopSim.hash_state(cdt2),
		"the crush run is reproducible with the falling block in the hash (sim characterization: determinism probe)")


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
	check(_a43_row(md, "strike odds") == PopGuard.column("strike"), "strike odds match PARITY §12")
	check(_a43_row(md, "re-strike odds") == PopGuard.column("restrike"), "re-strike odds match PARITY §12")
	check(_a43_row(md, "block odds") == PopGuard.column("block"), "block odds match PARITY §12")
	check(_a43_row(md, "immediate re-block odds") == PopGuard.column("immediate_block"), "immediate re-block odds match PARITY §12")
	check(_a43_row(md, "advance odds") == PopGuard.column("advance"), "advance odds match PARITY §12")
	check(_a43_row(md, "refractory frames") == PopGuard.column("refractory"), "refractory frames match PARITY §12")
	check(_a43_row(md, "bonus HP") == PopGuard.column("bonus_hp"), "bonus HP matches PARITY §12")
	check(_a43_row(md, "base HP") == PopGuard.column("base_hp"), "base HP matches PARITY §12")
	check(PopGuard.guard_hp(0) == 4, "a skill-0 guard has 4 HP (PARITY §12 base 4 + bonus 0)")
	check(PopGuard.odds(0, "refractory") == 16, "skill-0 refractory is 16 frames (PARITY §12)")

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

	# --- §20 reach rows (anti-drift) ----------------------------------------
	var s20 := _parity_section(md, "20")
	check(s20.contains("char_opp_dist") and _parity_int(md, "20", "front offset") == PopGuard.FRONT_OFFSET,
		"the +13 front offset matches PARITY §20 (seg006.c:2127-2129)")
	check(_parity_int(md, "20", "hit range max") == PopGuard.HIT_MAX and PopGuard.HIT_MAX == 29,
		"the hit range max 29 matches PARITY §20 (seg002.c:1021)")
	check(_parity_int(md, "20", "reach minimum drawn") == PopGuard.HIT_MIN_DRAWN
			and PopGuard.HIT_MIN_DRAWN == 12,
		"reach minimum with the defender drawn is 12 (PARITY §20, seg002.c:1018)")
	check(_parity_int(md, "20", "reach minimum undrawn") == PopGuard.HIT_MIN_UNSHEATHED,
		"reach minimum with the defender undrawn is 8 (PARITY §20, seg002.c:1016)")
	check(_parity_int(md, "20", "damage frame") == PopGuard.STRIKE_DAMAGE_FRAME,
		"the damage frame f154 matches PARITY §20 (seg002.c:1014)")
	check(_parity_int(md, "20", "engage gate") == PopGuard.ENGAGE_RANGE,
		"the engage gate 35 matches PARITY §20 (seg002.c:758)")
	check(_parity_int(md, "20", "too-close band") == PopGuard.TOO_CLOSE
			and _parity_int(md, "20", "too-close unsheathed") == PopGuard.TOO_CLOSE_UNSHEATHED,
		"the too-close bands 12/8 match PARITY §20 (seg002.c:759)")
	check(_parity_int(md, "20", "armed advance band") == PopGuard.ARMED_ADVANCE_BELOW,
		"the armed advance band 10 matches PARITY §20 (seg002.c:849)")
	check(_parity_int(md, "20", "strike band low") == PopGuard.TOO_CLOSE,
		"the strike band low edge 12 matches PARITY §20 (seg002.c:854)")
	check(_parity_int(md, "20", "parry far") == PopGuard.PARRY_FAR,
		"the parry-far retreat threshold 32 matches PARITY §20 (seg005.c:1063)")
	check(_parity_int(md, "20", "kid strike timer") == PopGuard.STRIKE_TIMER_START,
		"the kid strike timer 15 matches PARITY §20 (seg005.c:994)")
	check(_parity_int(md, "20", "re-block timer") == PopGuard.REBLOCK_START,
		"the re-block timer 4 matches PARITY §20 (seg002.c:1028)")
	check(_ints(_parity_cell(md, "20", "advance dx")) == [2, 4, 6]
			and PopGuard.CHAIN_DX["advance"] == [2, 4, 0],
		"advance dx +2/+4 (total +6) matches PARITY §20 (seqtbl.c:316-318)")
	check(_ints(_parity_cell(md, "20", "fastadvance dx")) == [6, 6]
			and PopGuard.CHAIN_DX["fastadvance"] == [6, 0],
		"fastadvance dx +6 matches PARITY §20 (seqtbl.c:322-323)")
	check(_ints(_parity_cell(md, "20", "retreat dx")) == [-3, -2, -5]
			and PopGuard.CHAIN_DX["retreat"] == [-3, -2],
		"retreat dx -3/-2 (total -5) matches PARITY §20 (seqtbl.c:327-328)")
	check(s20.contains("7–14") and s20.contains("34–39") and s20.contains("43 and 26"),
		"the spike harm windows match PARITY §20 (seg006.c:958-960)")
	check(s20.contains("stored cycle frame reads 2") and s20.contains("1…15"),
		"the chomper kill state and cycle match PARITY §20 (seg004.c:444, seg007.c:284-289)")

	# --- char_opp_dist (PARITY §20 distance rows) ---------------------------
	check(PopGuard.opp_dist(100, 0, 107, -1) == 20,
		"facing fighters: raw 7 + 13 = signed 20 (seg006.c:2123-2129)")
	check(PopGuard.opp_dist(107, -1, 100, 0) == 20,
		"the guard computes the same signed distance (seg006.c:2124-2126)")
	check(PopGuard.opp_dist(100, 0, 95, -1) == -5,
		"an opponent behind the char stays negative — no +13 (seg006.c:2127)")
	check(PopGuard.opp_dist(100, 0, 107, 0) == 7,
		"same directions get no +13 (seg006.c:2127-2129)")

	# --- a strike lands only inside [reach min, 29) -------------------------
	var g1 := PopGuard.initial(0)
	var k1 := PopGuard.initial_kid()
	g1["seq"] = "strike"
	g1["frame"] = PopGuard.STRIKE_DAMAGE_FRAME        # f154: the poke (`seg002.c:1014`)
	g1["index"] = 4
	var t1: Array = []
	PopGuard._resolve(k1, g1, t1)
	check(int(k1["hp"]) == PopTables.KID_HP_START - 1,
		"a strike in f154 hits an undefended kid at distance 20 (PARITY §20; hp %d)" % int(k1["hp"]))
	check(t1 == ["kid:hit"], "the hit is recorded in the transcript")

	# f153 passes the hit gate but never damages (correction vs Session 005:
	# `seg002.c:1014` checks frame_154_poking only)
	var g1b := PopGuard.initial(0)
	var k1b := PopGuard.initial_kid()
	g1b["seq"] = "strike"
	g1b["frame"] = PopGuard.KID_HIT_FRAMES[0]         # f153: wind-up
	var t1b: Array = []
	PopGuard._resolve(k1b, g1b, t1b)
	check(int(k1b["hp"]) == PopTables.KID_HP_START and t1b.is_empty(),
		"f153 alone does not damage (PARITY §20 damage frame 154; hp %d)" % int(k1b["hp"]))

	# reach edges around the drawn minimum 12 and max 29 (`seg002.c:1018-1021`)
	var g3 := PopGuard.initial(0)
	var k3 := PopGuard.initial_kid()
	g3["seq"] = "strike"
	g3["frame"] = PopGuard.STRIKE_DAMAGE_FRAME
	var t3: Array = []
	PopGuard._resolve(k3, g3, t3, 11)
	check(int(k3["hp"]) == PopTables.KID_HP_START,
		"distance 11 is short of the drawn minimum 12 (hp %d)" % int(k3["hp"]))
	var g4 := PopGuard.initial(0)
	var k4 := PopGuard.initial_kid()
	g4["seq"] = "strike"
	g4["frame"] = PopGuard.STRIKE_DAMAGE_FRAME
	var t4: Array = []
	PopGuard._resolve(k4, g4, t4, 29)
	check(int(k4["hp"]) == PopTables.KID_HP_START,
		"distance 29 is outside the hit range (hp %d)" % int(k4["hp"]))
	k4["sword"] = 0                                   # an undrawn defender: min 8
	var t5: Array = []
	PopGuard._resolve(k4, g4, t5, 8)
	check(int(k4["hp"]) == PopTables.KID_HP_START - 1,
		"an undrawn defender is hit from distance 8 (PARITY §20; hp %d)" % int(k4["hp"]))
	k4["hp"] = PopTables.KID_HP_START
	var t6: Array = []
	PopGuard._resolve(k4, g4, t6, 7)
	check(int(k4["hp"]) == PopTables.KID_HP_START,
		"distance 7 is short of the undrawn minimum 8 (hp %d)" % int(k4["hp"]))

	# parry turn-aside needs 0 <= distance < 29 (`seg002.c:1009-1013`)
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
	check(int(g2["reblock"]) == PopGuard.REBLOCK_START,
		"a parried guard attack starts the re-block timer at 4 (PARITY §20, seg002.c:1028)")
	var g5 := PopGuard.initial(0)
	var k5 := PopGuard.initial_kid()
	g5["seq"] = "strike"
	g5["frame"] = PopGuard.STRIKE_DAMAGE_FRAME
	k5["seq"] = "block"
	k5["frame"] = PopGuard.PARRY_FRAMES[0]
	var t7: Array = []
	PopGuard._resolve(k5, g5, t7, 30)   # >= 29: outside the parry branch, no damage either
	check(int(k5["hp"]) == PopTables.KID_HP_START and t7.is_empty(),
		"beyond 29 the parry no longer turns the strike aside (hp %d)" % int(k5["hp"]))

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
	# --- the decision ladder bands (PARITY §20) ------------------------------
	var rr := PopRng.new()
	rr.state = PopRng.normalize_seed(4242)
	var before := rr.state
	var kg := PopGuard.initial_kid()
	var gg := PopGuard.initial(0)
	var td: Array = []
	check(PopGuard._decide(gg, kg, rr, td, 40) != 0 and String(gg["seq"]) == "advance"
			and rr.state == before,
		"far (40 >= 35): advance with no RNG draw (seg002.c:758/795-801)")

	gg = PopGuard.initial(0)
	gg["refractimer"] = 5
	kg = PopGuard.initial_kid()
	rr.state = PopRng.normalize_seed(4242)
	before = rr.state
	td = []
	check(PopGuard._decide(gg, kg, rr, td, 40) == 0 and String(gg["seq"]) == "ready"
			and rr.state == before,
		"far while refracted: hold with no RNG draw (seg002.c:773)")

	gg = PopGuard.initial(0)
	kg = PopGuard.initial_kid()
	rr.state = PopRng.normalize_seed(4242)
	before = rr.state
	td = []
	check(PopGuard._decide(gg, kg, rr, td, 10) != 0 and String(gg["seq"]) == "advance"
			and rr.state == before,
		"too close (10 < 12): close in with no RNG draw (seg002.c:759-766)")

	gg = PopGuard.initial(0)
	kg = PopGuard.initial_kid()
	kg["dir"] = -1                    # the kid has turned: both face left
	rr.state = PopRng.normalize_seed(4242)
	before = rr.state
	td = []
	check(PopGuard._decide(gg, kg, rr, td, 10) != 0 and String(gg["seq"]) == "retreat"
			and rr.state == before,
		"too close facing the same way: back off (seg002.c:761-763)")

	# [12, 29), kid idle in f155: exactly one strike draw
	gg = PopGuard.initial(0)
	kg = PopGuard.initial_kid()
	kg["frame"] = 155                 # neither a block-react nor a strike-skip frame
	rr.state = PopRng.normalize_seed(4242)
	var probe := PopRng.new()
	probe.state = rr.state
	var draw := probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state,
		"the armed band draws exactly once when only the strike can fire (seg002.c:857-899)")
	if PopGuard.odds(0, "strike") > draw:
		check(String(gg["seq"]) == "strike" and td == ["g:strike"],
			"a firing strike draw starts the strike chain (draw %d < 61)" % draw)
	else:
		check(String(gg["seq"]) == "ready" and td.is_empty(),
			"a failed strike draw stands (draw %d >= 61)" % draw)

	# [12, 29), kid in f152: block draw then strike draw, in that order
	gg = PopGuard.initial(0)
	kg = PopGuard.initial_kid()
	kg["frame"] = 152
	rr.state = PopRng.normalize_seed(77)
	probe.state = rr.state
	var d1 := probe.rand_below(256)
	var d2 := probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state,
		"block then strike draws twice per tick (seg002.c:875, seg002.c:897)")
	var want: Array = []
	var want_seq := "ready"
	if PopGuard.odds(0, "block") > d1:
		want.append("g:block")
		want_seq = "block"
	if PopGuard.odds(0, "strike") > d2:
		want.append("g:strike")       # strike overrides block (seg005.c:993-997)
		want_seq = "strike"
	check(td == want and String(gg["seq"]) == want_seq,
		"the transcript and chain match both draws (block %d, strike %d)" % [d1, d2])

	# refracted: the block still draws, the strike branch does not (seg002.c:853)
	gg = PopGuard.initial(0)
	gg["refractimer"] = 5
	kg = PopGuard.initial_kid()
	kg["frame"] = 152
	rr.state = PopRng.normalize_seed(77)
	probe.state = rr.state
	d1 = probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state,
		"refracted: the block draws but the strike does not (seg002.c:853, seg002.c:875)")
	if PopGuard.odds(0, "block") > d1:
		check(String(gg["seq"]) == "block" and td == ["g:block"],
			"a firing block draw starts the block (draw %d < 150)" % d1)
	else:
		check(String(gg["seq"]) == "ready" and td.is_empty(),
			"a failed block draw stands (draw %d >= 150)" % d1)

	# block hold: restrike from f150 uses restrikeprob (PARITY §12 row)
	gg = PopGuard.initial(0)
	gg["seq"] = "block"
	gg["frame"] = PopGuard.PARRY_FRAMES[0]      # f150 in the hold loop
	kg = PopGuard.initial_kid()
	kg["frame"] = 155
	rr.state = PopRng.normalize_seed(4242)
	probe.state = rr.state
	probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state and String(gg["seq"]) == "block" and td.is_empty(),
		"skill 0 restrike odds 0: the hold never re-strikes (PARITY §12, seg002.c:893-895)")

	gg = PopGuard.initial(9)
	gg["seq"] = "block"
	gg["frame"] = PopGuard.PARRY_FRAMES[0]
	kg = PopGuard.initial_kid()
	kg["frame"] = 155
	rr.state = PopRng.normalize_seed(4242)
	probe.state = rr.state
	var d3 := probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state,
		"the hold restrike draws exactly once (seg002.c:893-895)")
	if PopGuard.odds(9, "restrike") > d3:
		check(String(gg["seq"]) == "block_strike" and td == ["g:strike"],
			"skill 9 restrike odds 255: the hold re-strikes from f150 (draw %d)" % d3)
	else:
		check(String(gg["seq"]) == "block" and td.is_empty(),
			"a failed restrike keeps the hold (draw %d)" % d3)

	# from f169 the strike draw is consumed but sword_strike refuses the frame
	gg = PopGuard.initial(0)
	gg["seq"] = "block"
	gg["frame"] = PopGuard.CHAIN_BLOCK[0]       # f169
	kg = PopGuard.initial_kid()
	kg["frame"] = 155
	rr.state = PopRng.normalize_seed(4242)
	probe.state = rr.state
	var d4 := probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 20)
	check(rr.state == probe.state and String(gg["seq"]) == "block" and td.is_empty(),
		"from f169 the draw is spent but no chain starts (seg005.c:1036-1049; draw %d)" % d4)

	# guard_advance draws nothing while the kid's sword-strike timer runs for
	# skill > 0 (skill 0 always draws; seg002.c:864-865)
	gg = PopGuard.initial(1)
	kg = PopGuard.initial_kid()
	kg["sword_strike"] = PopGuard.STRIKE_TIMER_START
	rr.state = PopRng.normalize_seed(4242)
	before = rr.state
	td = []
	check(PopGuard._decide(gg, kg, rr, td, 32) == 0 and String(gg["seq"]) == "ready"
			and rr.state == before,
		"skill 1 + kid strike timer: guard_advance draws nothing (seg002.c:864-865)")

	gg = PopGuard.initial(0)
	kg = PopGuard.initial_kid()
	kg["sword_strike"] = PopGuard.STRIKE_TIMER_START
	rr.state = PopRng.normalize_seed(4242)
	probe.state = rr.state
	var d5 := probe.rand_below(256)
	td = []
	PopGuard._decide(gg, kg, rr, td, 32)         # [29, 35): the armed advance band
	check(rr.state == probe.state,
		"skill 0 always draws advprob, whatever the strike timer (seg002.c:865)")
	if PopGuard.odds(0, "advance") > d5:
		check(String(gg["seq"]) == "advance",
			"a firing advance draw starts the advance (draw %d < 255)" % d5)
	else:
		check(String(gg["seq"]) == "ready",
			"a failed advance draw stands (draw %d >= 255)" % d5)

	# a hurt guard waits out his own refractimer (check_sword_hurt)
	var gh := PopGuard.initial(0)
	var kh := PopGuard.initial_kid()
	kh["seq"] = "strike"
	kh["frame"] = PopGuard.STRIKE_DAMAGE_FRAME
	var th: Array = []
	PopGuard._resolve(kh, gh, th)
	check(int(gh["hp"]) == PopGuard.guard_hp(0) - 1
			and int(gh["refractimer"]) == PopGuard.odds(0, "refractory"),
		"a hit on the guard sets refractimer to 16 (PARITY §12, seg002.c:973)")

	# --- the walk chains pay their dx beside each frame (PARITY §13/§20) ----
	var walk := PopGuard.initial_kid()
	check(PopGuard._start(walk, "fastadvance") == 6 and PopGuard._advance(walk) == 0,
		"fastadvance pays +6 at f164 and nothing at f165 (seqtbl.c:322-323)")
	walk = PopGuard.initial(0)
	check(PopGuard._start(walk, "advance") == 2 and PopGuard._advance(walk) == 4
			and PopGuard._advance(walk) == 0,
		"advance pays +2 f163 then +4 f164 (seqtbl.c:316-318)")
	walk = PopGuard.initial_kid()
	check(PopGuard._start(walk, "retreat") == -3 and PopGuard._advance(walk) == -2,
		"retreat pays -3 f160 then -2 f157 (seqtbl.c:327-328)")

	# --- distance actually gates the duel ----------------------------------
	# sword-only commands never move anyone (no dx in the §13 strike/block
	# chains), so the duel closes at exactly the start distance
	check(int(w1["dist"]) == PopGuard.START_DIST,
		"a sword-only duel ends at the start distance %d (sim characterization)" % PopGuard.START_DIST)
	var walk1: Array = ["advance"]
	for i: int in 60:
		walk1.append("idle")
	var m1 := PopGuard.duel(20261008, 0, walk1, 60)
	check("k:advance" in (m1["transcript"] as Array) and int(m1["dist"]) == 14,
		"the kid's fastadvance closes 20 → 14 (PARITY §20 fastadvance dx +6; dist %d)" % int(m1["dist"]))
	var m2 := PopGuard.duel(20261008, 0, walk1, 60)
	check((m1["transcript"] as Array) == (m2["transcript"] as Array) and int(m2["dist"]) == 14,
		"a movement duel is reproducible for the same seed (dist %d)" % int(m2["dist"]))
	var walk2: Array = ["retreat"]
	for i: int in 60:
		walk2.append("idle")
	var m3 := PopGuard.duel(20261008, 0, walk2, 60)
	check("k:retreat" in (m3["transcript"] as Array) and int(m3["dist"]) == 25,
		"the kid's retreat opens 20 → 25 (PARITY §20 retreat dx -5; dist %d)" % int(m3["dist"]))

	# --- trap deaths for both parties (PARITY §20) ---------------------------
	var ts: Array = []
	var tk := PopGuard.initial_kid()
	tk["frame"] = 10                                # a running frame
	PopGuard.trap_step(tk, "kid", {"kind": "spike", "harmful": 2}, 1, ts)
	check(int(tk["hp"]) == 0 and ts == ["kid:spiked"],
		"harm class 2 on a run frame spikes the kid (seg006.c:958-959)")
	ts = []
	var tk2 := PopGuard.initial_kid()
	tk2["frame"] = 10
	PopGuard.trap_step(tk2, "kid", {"kind": "spike", "harmful": 1}, 1, ts)
	check(int(tk2["hp"]) == PopTables.KID_HP_START and ts.is_empty(),
		"harm class 1 on a run frame is safe (seg006.c:959)")
	ts = []
	var tg := PopGuard.initial(0)
	tg["frame"] = 43                                # landing from a run-jump
	PopGuard.trap_step(tg, "guard", {"kind": "spike", "harmful": 1}, 1, ts)
	check(int(tg["hp"]) == 0 and ts == ["guard:spiked"],
		"harm class 1 on frame 43 spikes the guard (seg006.c:960)")
	ts = []
	var tg2 := PopGuard.initial(0)                  # en garde: f158 is outside both windows
	PopGuard.trap_step(tg2, "guard", {"kind": "spike", "harmful": 2}, 1, ts)
	check(int(tg2["hp"]) == PopGuard.guard_hp(0) and ts.is_empty(),
		"an en-garde guard is never spiked by the frame rule (seg006.c:958-960)")

	# a chomper kills on stored modifier 2 of the 15-frame cycle
	var ch_script: Array = []
	for i: int in 10:
		ch_script.append("idle")
	var ch1 := PopGuard.duel(99, 0, ch_script, 1, {"kid": [{"kind": "chomper"}]})
	check(String(ch1["winner"]) == "none" and int(ch1["kid_hp"]) == PopTables.KID_HP_START,
		"tick 1 of the chomper cycle is safe (stored frame 1)")
	var ch2 := PopGuard.duel(99, 0, ch_script, 10, {"kid": [{"kind": "chomper"}]})
	check("kid:chomped" in (ch2["transcript"] as Array) and String(ch2["winner"]) == "guard",
		"the chomper bites the kid at stored frame 2 (seg004.c:444; winner %s)" % String(ch2["winner"]))
	var ch3 := PopGuard.duel(99, 0, ch_script, 10, {"guard": [{"kind": "chomper"}]})
	check("guard:chomped" in (ch3["transcript"] as Array) and String(ch3["winner"]) == "kid",
		"the chomper bites the guard too (seg004.c:569-585; winner %s)" % String(ch3["winner"]))
	var ch4 := PopGuard.duel(99, 0, ch_script, 10, {"kid": [{"kind": "chomper"}]})
	check((ch2["transcript"] as Array) == (ch4["transcript"] as Array),
		"a chomper duel is reproducible for the same seed")
	var sp1 := PopGuard.duel(99, 0, ch_script, 400,
		{"kid": [{"kind": "spike", "harmful": 2}]})
	check(not str(sp1["transcript"]).contains(":spiked"),
		"a live spike hazard never spikes an en-garde fighter (seg006.c:958-960)")

	print("  MEAS duel(seed 20261008, skill 0, attack): winner=%s ticks=%d guard_hp=%d kid_hp=%d dist=%d transcript=%d events" % [
		String(w1["winner"]), int(w1["ticks"]), int(w1["guard_hp"]), int(w1["kid_hp"]),
		int(w1["dist"]), (w1["transcript"] as Array).size()])


# --- A5.1 parity harness (plan A5.1) ---------------------------------------

## A5.1 — one hand-built replica of an original room's GRAMMAR (not layout).
## Grammar source: the level-1 opening sequence in A1's study notes of SDLPoP
## level 1 (`study/level_00.txt`, untracked): a raised start floor you drop
## from, a ground floor with a gap to jump, a ledge you jump-grab and climb,
## and the level's plate->gate doorlink (room 1's doorlink). The row/column
## layout below is entirely our own. Driven by one input script; the four
## A5.1 invariants (jump distance, hang frame counts, spike survival, gate
## timing) are asserted against PARITY §4/§5/§6/§8/§9/§10 rows read at runtime.
func _a51_room() -> Dictionary:
	const F: int = PopTables.Tile.FLOOR
	const E: int = PopTables.Tile.EMPTY
	const SP: int = PopTables.Tile.SPIKES
	const BTN: int = PopTables.Tile.BUTTON_RAISE
	const GT: int = PopTables.Tile.GATE
	# row 0: start floor (0..4) | gap | ledge (13..18: plate at 16, gate at 18)
	# row 1: ground floor | spike pit (9) | ground floor to the right edge
	# row 2: spike floor under the pit plus one column of drift margin each
	#         side (fall frames carry dx +1/+2/−1/−2, `seqtbl.c:491-497`); see
	#         the A5.1 GAP list.
	var tiles: Array = [
		[F, F, F, F, F, E, E, E, E, E, E, E, E, F, F, F, BTN, F, GT, E, E, E, E, E],
		[F, F, F, F, F, F, F, F, F, E, F, F, F, F, F, F, F, F, F, F, F, F, F, F],
		[E, E, E, E, E, E, E, E, SP, SP, SP, E, E, E, E, E, E, E, E, E, E, E, E, E],
		[E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E, E],
	]
	return {
		"tiles": tiles,
		"mods": {"2,8": 3, "2,9": 3, "2,10": 3},
		"entities": {
			"gates": {"0,18": {"mod": PopTables.GATE_CLOSED, "type": -1}},
			"plates": {"0,16": 0},
			"links": [{"plate": "0,16", "gate": "0,18"}],
		},
	}


## A5.1: one fixed input script through the replica room, asserting the four
## plan-A5.1 invariants (jump distance, hang frame counts, spike survival,
## gate timing). Every expected value is read from a PARITY §4/§5/§6/§8/§9/§10
## row at runtime; behavior with no independent oracle is labelled
## "sim characterization, not parity evidence".
func _test_a51_harness(md: String) -> void:
	if md.is_empty():
		md = FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A5.1 cross-checks")
	if md.is_empty():
		return

	# --- expected values, read from PARITY rows (never from sim output) --
	var s4_head := _parity_row(md, "4", "frame")
	var s5_head := _parity_row(md, "5", "frame")
	var s4 := _expand_cells(s4_head, _parity_row(md, "4", "cum x"))
	var s5 := _expand_cells(s5_head, _parity_row(md, "5", "cum x"))
	var i27 := _frame_index(s4_head, 27)
	var i44 := _frame_index(s5_head, 44)
	var stand_land := int(s4[i27]) if i27 >= 0 and i27 < s4.size() else _MISSING_PARITY_VALUE
	var stand_total := int(s4[s4.size() - 1]) if s4.size() > 0 else _MISSING_PARITY_VALUE
	var run_land := int(s5[i44]) if i44 >= 0 and i44 < s5.size() else _MISSING_PARITY_VALUE
	var run_total := int(s5[s5.size() - 1]) if s5.size() > 0 else _MISSING_PARITY_VALUE
	var sway := _ints(_parity_cell(md, "6", "hang sway", 2))
	var sway_ticks: int = int(sway[0]) if sway.size() > 0 else _MISSING_PARITY_VALUE
	var climb := _ints(_parity_cell(md, "6", "climb up", 1))
	var climb_ticks: int = int(climb[climb.size() - 1]) if climb.size() > 0 else _MISSING_PARITY_VALUE
	var climb_dx: int = int(climb[3]) if climb.size() > 5 else _MISSING_PARITY_VALUE
	var climb_dy: int = int(climb[4]) if climb.size() > 5 else _MISSING_PARITY_VALUE
	var climb_row: int = int(climb[5]) if climb.size() > 5 else _MISSING_PARITY_VALUE
	var open_delta := _parity_int(md, "9", "opening / permanent")
	var close_delta := _parity_int(md, "9", "normal closing")
	var open_row := _ints(_parity_cell(md, "9", "open reached"))
	var plate_timer := _parity_int(md, "10", "press timer", 2)
	var spike_off := _parity_cell(md, "8", "disabled", 1)
	var spike_keys := ["2,8", "2,9", "2,10"]
	check(open_row.size() >= 2 and sway_ticks == 43 and climb_ticks == 18
			and stand_total == 39 and run_total == 67,
		"A5.1 reads the §4/§5/§6/§9 targets (39 / 67 / 43 / 18 / 188,238; got %d / %d / %d / %d / %s)" %
			[stand_total, run_total, sway_ticks, climb_ticks, str(open_row)])

	var bundle := _a51_room()
	var tiles: Array = bundle["tiles"]
	var mods: Dictionary = bundle["mods"]
	var entities: Dictionary = bundle["entities"]

	# --- P1: standing jump on the start floor (PARITY §4) ---------------
	var st: Dictionary = PopSim.initial_state(4242, tiles, mods, entities)
	var x0 := int(st["x"])
	var t := 0
	var x_at27 := -1
	while t < 40:
		st = PopSim.step(st, PopInput.make(1, -1))  # fwd+Up = standing jump (§4 trigger row)
		t += 1
		if x_at27 < 0 and int(st["frame"]) == 27:
			x_at27 = int(st["x"])
		if t > 3 and String(st["seq"]) == "stand":
			break
	check(x_at27 > 0 and x_at27 - x0 == stand_land,
		"A5.1 P1 landing distance at f27 = %d units (PARITY §4 cum x; got %d)" % [stand_land, x_at27 - x0])
	check(int(st["x"]) - x0 == stand_total,
		"A5.1 P1 standing-jump total travel = %d units (PARITY §4 cum x end; got %d)" % [stand_total, int(st["x"]) - x0])
	check(int(st["dead"]) == 0 and int(st["hp"]) == 3,
		"A5.1 P1 the standing jump leaves the kid alive at full HP (sim characterization, not parity evidence)")

	# --- P2: run off the start floor onto the ground floor (1-row drop) --
	var n2 := 0
	while n2 < 60:
		st = PopSim.step(st, PopInput.make(1, 0))
		n2 += 1
		if int(st["row"]) == 1 and String(st["seq"]) == "run_cycle":
			break
	check(int(st["row"]) == 1,
		"A5.1 P2 the run drops the kid to the ground floor (grammar; sim characterization, not parity evidence)")
	check(int(st["dead"]) == 0 and int(st["hp"]) == 3,
		"A5.1 P2 the 1-row drop lands soft — no HP lost (PARITY §7 soft land <22; got hp %d)" % int(st["hp"]))

	# --- P3a: run up to the take-off tile -------------------------------
	var n3 := 0
	while int(st["x"]) < 150 and n3 < 30:
		st = PopSim.step(st, PopInput.make(1, 0))
		n3 += 1

	# --- P3b: run jump over the spike pit (PARITY §5 + §8) --------------
	var x_takeoff := int(st["x"])
	var n4 := 0
	var x_at44 := -1
	while n4 < 40:
		st = PopSim.step(st, PopInput.make(1, -1))
		n4 += 1
		if x_at44 < 0 and int(st["frame"]) == 44:
			x_at44 = int(st["x"])
		if n4 > 3 and String(st["seq"]) == "run_cycle":
			break
	check(x_at44 > 0 and x_at44 - x_takeoff == run_land,
		"A5.1 P3b landing distance at f44 = %d units (PARITY §5 cum x; got %d)" % [run_land, x_at44 - x_takeoff])
	check(int(st["x"]) - x_takeoff == run_total,
		"A5.1 P3b run-jump total travel = %d units (PARITY §5 cum x end; got %d)" % [run_total, int(st["x"]) - x_takeoff])
	check(int(st["dead"]) == 0 and int(st["hp"]) == 3,
		"A5.1 P3b the run jump clears the spike pit (spike survival control; got dead=%d hp=%d)" % [int(st["dead"]), int(st["hp"])])
	var spikes_clear := true
	for key: String in spike_keys:
		if int((st["mods"] as Dictionary).get(key, 0)) != int(mods[key]):
			spikes_clear = false
	check(spikes_clear,
		"A5.1 P3b the pit spikes stay armed through the jump (PARITY §8: %s only on a kill; got %s)" % [spike_off, str(st["mods"])])

	# --- P4: stop the run, then walk to the grab position --------------
	# The grab window: det_col = col_of(x − 10) = 12 (x ∈ 236..249) makes the
	# reference probe (lane 1 of check_jump_up) see the ledge lip col 13
	# ahead-above (`seg005.c:682-685`); within that window the commit arithmetic
	# hangs the kid at x 248 whatever the exact stand x (see _grab_up_with_floor_behind).
	var n4b := 0
	while String(st["seq"]) != "stand" and n4b < 30:
		st = PopSim.step(st, PopInput.neutral())
		n4b += 1
	var n5 := 0
	while int(st["x"]) < 236 and n5 < 20:
		st = PopSim.step(st, PopInput.make(1, 0, 1))
		n5 += 1
	var n5b := 0
	while String(st["seq"]) != "stand" and n5b < 15:
		st = PopSim.step(st, PopInput.neutral())
		n5b += 1
	check(String(st["seq"]) == "stand" and int(st["row"]) == 1,
		"A5.1 P4 the kid stops and safe-steps to the ledge lip (grammar; got seq %s row %d)" % [String(st["seq"]), int(st["row"])])

	# --- P5: jump-grab the ledge (shift+Up) -----------------------------
	var hang_tick := -1
	var sway_start: Dictionary = {}
	var n6 := 0
	while n6 < 30:
		st = PopSim.step(st, PopInput.make(0, -1, 1))
		n6 += 1
		if String(st["seq"]) == "hang":
			hang_tick = int(st["tick"])
			sway_start = st.duplicate(true)
			break
	check(hang_tick > 0 and int(st["frame"]) == 91,
		"A5.1 P5 shift+Up grabs the ledge and enters the sway on f91 (PARITY §6 hang sway; got seq %s f%d)" % [String(st["seq"]), int(st["frame"])])

	# --- P6: climb onto the ledge (PARITY §6 climb up row) --------------
	var climb_tick := -1
	var x_climb := 0
	var y_climb := 0
	var row_climb := 0
	var x_f141 := -1
	var y_f141 := -1
	var row_f141 := -1
	var n7 := 0
	while n7 < 40:
		st = PopSim.step(st, PopInput.make(0, -1, 1))
		n7 += 1
		if climb_tick < 0 and String(st["seq"]) == "climb_up":
			climb_tick = int(st["tick"])
			x_climb = int(st["x"])
			y_climb = int(st["y"])
			row_climb = int(st["row"])
		if x_f141 < 0 and String(st["seq"]) == "climb_up" and int(st["frame"]) == 141:
			x_f141 = int(st["x"])
			y_f141 = int(st["y"])
			row_f141 = int(st["row"])
		if String(st["seq"]) == "stand":
			break
	check(climb_tick > 0 and String(st["seq"]) == "stand" and int(st["frame"]) == 15,
		"A5.1 P6 the climb ends on the stand opening frame f15 (PARITY §6 climb up row; got seq %s f%d)" % [String(st["seq"]), int(st["frame"])])
	# §6 counts inclusively: "stand (frame f15) on tick 18" — f135 plays on
	# the climb's first tick and f15 on its 18th, so the tick *difference*
	# stand − climb_start is 17.
	check(int(st["tick"]) - climb_tick + 1 == climb_ticks,
		"A5.1 P6 climb up reaches stand on climb-tick %d (PARITY §6 climb up row; got %d)" %
			[climb_ticks, int(st["tick"]) - climb_tick + 1])
	check(x_f141 > 0 and x_f141 - x_climb == climb_dx and y_f141 - y_climb == climb_dy and row_f141 - row_climb == climb_row,
		"A5.1 P6 f141 applies dx %+d, dy %+d, row %+d (PARITY §6 climb up row; got dx %+d, dy %+d, row %+d)" % [
			climb_dx, climb_dy, climb_row, x_f141 - x_climb, y_f141 - y_climb, row_f141 - row_climb])
	check(int(st["row"]) == 0 and int(st["y"]) == int(PopTables.Y_LAND[1]),
		"A5.1 P6 the climb-out stands on the ledge row at the row-0 floor y (PARITY §2 y_land; got row %d y %d)" % [int(st["row"]), int(st["y"])])
	var stand_col := PopSim._col_of(PopSim._foot_x(st))
	check(PopSim._is_floor(PopSim._tile(st, 0, stand_col)) and int(st["dead"]) == 0,
		"A5.1 P6 the climb-out lands on the ledge floor at column %d (grammar; sim characterization, not parity evidence)" % stand_col)

	# --- P7: run across the ledge onto the plate (PARITY §10) -----------
	var n8 := 0
	var press_tick := -1
	var plate_after := -1
	while n8 < 60:
		st = PopSim.step(st, PopInput.make(1, 0))
		n8 += 1
		var plate_now: int = int((st["plates"] as Dictionary).get("0,16", 0))
		if plate_now > 0 and press_tick < 0:
			press_tick = int(st["tick"])
			plate_after = plate_now
		if press_tick > 0 and int(st["x"]) >= 296:
			break
	check(press_tick > 0,
		"A5.1 P7 crossing the ledge steps on the plate (grammar; sim characterization, not parity evidence)")
	check(plate_after == plate_timer - 1,
		"A5.1 P7 the press sets the hold timer to %d then decrements once (PARITY §10 press-timer row; got %d)" % [plate_timer, plate_after])

	# --- P8: stop and watch the gate (PARITY §9) ------------------------
	st = PopSim.step(st, PopInput.neutral())
	var t_park := -1
	var t_zero := -1
	var n9 := 0
	while n9 < 500:
		st = PopSim.step(st, PopInput.neutral())
		n9 += 1
		var g: Dictionary = (st["gates"] as Dictionary)["0,18"]
		var m := int(g["mod"])
		if t_park < 0 and m >= int(open_row[1]):
			t_park = int(st["tick"])
		if t_park >= 0 and m == 0:
			t_zero = int(st["tick"])
			break
	var expected_open: int = int(open_row[0]) / open_delta    # 188 / 4
	var expected_close: int = int(open_row[1]) / abs(close_delta)  # 238 / 1
	check(t_park > 0 and abs((t_park - press_tick) - expected_open) <= 1,
		"A5.1 P8 the gate opens %d±1 ticks after the press (PARITY §9 open-reached + opening rows; got %d)" % [expected_open, t_park - press_tick])
	check(t_zero > 0 and abs((t_zero - t_park) - expected_close) <= 1,
		"A5.1 P8 the gate closes to 0 in %d±1 ticks (PARITY §9 normal-closing row; got %d)" % [expected_close, t_zero - t_park])
	check(int(((st["gates"] as Dictionary)["0,18"])["mod"]) == 0,
		"A5.1 P8 the gate ends fully closed (PARITY §9 close-reached row)")

	# --- C1: control — running into the spike pit kills (PARITY §8) -----
	var c1: Dictionary = PopSim.initial_state(4242, tiles, mods, entities)
	var nC := 0
	while nC < 120 and int(c1["dead"]) == 0:
		c1 = PopSim.step(c1, PopInput.make(1, 0))
		nC += 1
	check(int(c1["dead"]) == 1 and int(c1["hp"]) == 0,
		"A5.1 C1 running into the spike pit kills (spike survival control; got dead=%d hp=%d tick=%d)" % [int(c1["dead"]), int(c1["hp"]), int(c1["tick"])])
	check(String(c1["seq"]) == "impale",
		"A5.1 C1 the spike kill plays the impale sequence (sim characterization, not parity evidence; got %s)" % String(c1["seq"]))
	var spiked_key := ""
	for key: String in spike_keys:
		if int((c1["mods"] as Dictionary).get(key, 0)) == 255:
			spiked_key = key
	check(spiked_key != "" and spike_off.contains("0xFF"),
		"A5.1 C1 the impaled spike tile is disabled to %s (PARITY §8 disabled row; got tile %s)" % [spike_off, spiked_key])

	# --- C2: control — the hang sway auto-drops after the §6 count ------
	if hang_tick > 0:
		var c2: Dictionary = sway_start
		var drop_tick := -1
		var w := 0
		while w < sway_ticks + 40 and drop_tick < 0:
			c2 = PopSim.step(c2, PopInput.make(0, 0, 1))  # Shift held, no Up: no climb, no release
			w += 1
			if String(c2["seq"]) == "hang_drop":
				drop_tick = int(c2["tick"])
		check(drop_tick > 0 and drop_tick - hang_tick == sway_ticks,
			"A5.1 C2 the hang sway auto-drops after %d ticks (PARITY §6 hang sway; got %d)" % [sway_ticks, drop_tick - hang_tick])
		var c2n := 0
		while String(c2["seq"]) != "stand" and c2n < 10:
			c2 = PopSim.step(c2, PopInput.make(0, 0, 1))
			c2n += 1
		check(String(c2["seq"]) == "stand" and int(c2["dead"]) == 0 and int(c2["hp"]) == 3,
			"A5.1 C2 the auto-drop lands the kid on his feet below the ledge (sim characterization, not parity evidence; got seq %s hp %d)" % [String(c2["seq"]), int(c2["hp"])])
	else:
		check(false, "A5.1 C2 needs the P5 hang (skipped: the ledge grab never fired)")

	print("  GAP: A5.1 column probes use the plain left-edge column outside the hang/climb frames (pop_sim simplification list; the m7 migration is gate-2 work).")
	print("  GAP: pop_sim._m7_x subtracts 7 against the facing direction; get_tile_div_mod_m7 subtracts 7 unconditionally (`seg006.c:0690-0692`) — left-facing hangs still diverge (gate-2).")
	print("  GAP: A5.1 room layout is ours (grammar only); the spike floor pads the one-column fall drift that the reference m7 landing probe would absorb.")


# --- Plan B0.1: the sim path in the real game --------------------------------
#
# The default boot path runs the game on PopSim through SimWorld; the physics
# stack stays runnable behind --legacy-physics (verify.sh boots both). These
# checks hold the sim path's contract headlessly: the catalog level loads, the
# world steps the same deterministic PopSim, closed gates stop the kid, sim
# events reach EventBus, and respawn is a hard reset. What they cannot prove —
# feel, fairness, human completability — is the playtest's job.

func _b0_dup(bundle: Dictionary) -> Dictionary:
	return {"tiles": bundle["tiles"], "mods": bundle["mods"], "entities": bundle["entities"]}


func _b0_state_at(data: Dictionary, row: int, x: int, y: int) -> Dictionary:
	var s: Dictionary = PopSim.initial_state(
		int(data["seed"]), data["tiles"], data["mods"], data["entities"])
	s["row"] = row
	s["x"] = x
	s["y"] = y
	return s


func _test_b0_sim_path() -> void:
	check(GameManager.use_legacy_physics == false,
		"B0 the default boot path is the sim path (use_legacy_physics = false)")
	var data: Dictionary = LevelCatalog.get_sim_level(0)
	check(data.size() > 0 and String(data.get("id", "")) == "sim_gate",
		"B0 sim level 1 loads from the catalog")
	check(LevelCatalog.sim_count() == 3,
		"B0 the sim level list carries all three sim levels (S010 Hall of Echoes, S011 The Time Warden)")
	var bundle := _b0_dup({"tiles": data["tiles"], "mods": data["mods"], "entities": data["entities"]})
	var spawn_px: Vector2 = data["spawn"]
	var spawn_sim_x := int(spawn_px.x / SimWorld.PX_PER_UNIT)
	var right_byte := PopInput.make(1, 0).to_byte()
	var neutral_byte := PopInput.neutral().to_byte()

	# (1) The world runs the sim: the kid moves under scripted input, and two
	# identical runs hash equal — the determinism gate on the new path.
	var w1 := SimWorld.new()
	w1.setup(_b0_dup(bundle), int(data["seed"]), spawn_px, [])
	var w2 := SimWorld.new()
	w2.setup(_b0_dup(bundle), int(data["seed"]), spawn_px, [])
	w1.step_ticks(35, [right_byte])
	w2.step_ticks(35, [right_byte])
	check(int(w1.state["x"]) > spawn_sim_x + 40 and int(w1.state["dead"]) == 0,
		"B0 the kid runs right under the sim path (x %d -> %d, dead %d)" % [
			spawn_sim_x, int(w1.state["x"]), int(w1.state["dead"])])
	check(PopSim.hash_state(w1.state) == PopSim.hash_state(w2.state),
		"B0 two identical sim-path runs hash equal (determinism gate 1 holds on the new path)")
	w1.free()
	w2.free()

	# (1b) The 1-row drop off the start floor lands him on the ground floor,
	# alive and unharmed (PARITY §7 soft land), then he stands still.
	var w_drop := SimWorld.new()
	w_drop.setup(_b0_dup(bundle), int(data["seed"]), Vector2(420.0, 165.0), [])
	var stop_script: Array = []
	for _i: int in 20:
		stop_script.append(right_byte)
	for _i: int in 40:
		stop_script.append(neutral_byte)
	w_drop.step_ticks(60, stop_script)
	check(int(w_drop.state["row"]) == 1 and int(w_drop.state["dead"]) == 0
			and int(w_drop.state["hp"]) == PopTables.KID_HP_START,
		"B0 the drop off the start floor lands the kid on the ground floor, alive (row %d hp %d)" % [
			int(w_drop.state["row"]), int(w_drop.state["hp"])])
	w_drop.free()

	# (2) Closed gates stop the kid at the tile edge; a parked (open) gate is
	# passable — the reduced in_wall rule added with B0 (PARITY §9 threshold).
	var gate_left := 58 + PopTables.TILE_W * 19
	var g0 := _b0_state_at(data, 0, 300, int(PopTables.Y_LAND[1]))
	for _i: int in 60:
		g0 = PopSim.step(g0, PopInput.make(1, 0))
	check(int(g0["x"]) > 305 and int(g0["x"]) <= gate_left + 1,
		"B0 a closed gate stops the kid at the tile edge (x %d in (305, %d])" % [
			int(g0["x"]), gate_left + 1])
	var g1 := _b0_state_at(data, 0, 300, int(PopTables.Y_LAND[1]))
	(g1["gates"] as Dictionary)["0,19"]["mod"] = PopTables.GATE_PARKED
	for _i: int in 20:
		g1 = PopSim.step(g1, PopInput.make(1, 0))
	check(int(g1["x"]) > gate_left + PopTables.TILE_W,
		"B0 an open gate (parked, PARITY §9) is passable (x %d)" % int(g1["x"]))

	# (3) Sim events reach the console: every tick publishes player_moved, and
	# a spike death publishes player_died (spawn before the pit, run in).
	var w3 := SimWorld.new()
	w3.setup(_b0_dup(bundle), int(data["seed"]), Vector2(480.0, 354.0), [])
	var died := [false]
	var moved := [0]
	var on_died := func() -> void: died[0] = true
	var on_moved := func(_x: float, _y: float, _row: int, _dir: int) -> void:
		moved[0] = int(moved[0]) + 1
	EventBus.player_died.connect(on_died)
	EventBus.player_moved.connect(on_moved)
	w3.step_ticks(90, [right_byte])
	EventBus.player_died.disconnect(on_died)
	EventBus.player_moved.disconnect(on_moved)
	check(int(w3.state["dead"]) == 1 and died[0] == true,
		"B0 the spike death reaches EventBus.player_died (dead %d, signal %s)" % [
			int(w3.state["dead"]), str(died[0])])
	check(int(moved[0]) == 90, "B0 every sim tick publishes player_moved (%d/90)" % int(moved[0]))
	w3.free()

	# (4) Respawn is a hard reset at the checkpoint position.
	var w4 := SimWorld.new()
	w4.setup(_b0_dup(bundle), int(data["seed"]), spawn_px, [])
	w4.step_ticks(30, [right_byte])
	var away := int(w4.state["x"])
	w4.respawn_at(spawn_px)
	check(int(w4.state["x"]) == spawn_sim_x and int(w4.state["hp"]) == PopTables.KID_HP_START
			and int(w4.state["tick"]) == 0 and away != spawn_sim_x,
		"B0 respawn resets x/hp/tick at the position (was x %d, now %d)" % [
			away, int(w4.state["x"])])
	w4.free()

	# (5) Plan B0.1 step 3: the puzzle is driven by sim events. Crossing the
	# plate presses it (PARITY §10), the linked gate opens on the §9 schedule
	# (park at ~47 ticks) and every milestone reaches the framework.
	var w5 := SimWorld.new()
	var events: Array = []
	var park_mod := [-1]
	var on_ent := func(kind: StringName, key: String) -> void:
		events.append("%s:%s" % [String(kind), key])
		if String(kind) == "open":
			park_mod[0] = int(((w5.state["gates"] as Dictionary)[key] as Dictionary)["mod"])
	EventBus.sim_entity_event.connect(on_ent)
	w5.setup(_b0_dup(bundle), int(data["seed"]), Vector2(840.0, 165.0), [])
	w5.step_ticks(8, [right_byte])    # cross the plate at col 16 (x 282..295)
	w5.step_ticks(60, [neutral_byte]) # stand still while the gate runs §9
	EventBus.sim_entity_event.disconnect(on_ent)
	check(events.has("press:0,16"),
		"B0 stepping on the plate emits a press milestone (got %s)" % str(events))
	check(events.has("opening:0,19") and events.has("open:0,19"),
		"B0 the linked gate emits opening then open (parked) milestones (got %s)" % str(events))
	# §9 open-reached: the modifier snaps to 238 and reverses immediately, so
	# the park value is read AT the milestone tick, not afterwards.
	check(int(park_mod[0]) == PopTables.GATE_PARKED,
		"B0 the gate reaches the PARITY §9 park value at the open milestone (mod %d == %d)" % [
			int(park_mod[0]), PopTables.GATE_PARKED])
	w5.free()

	# (6) Plan B0.1 step 5: the level-complete flow runs end to end on the sim
	# path — load -> play -> complete -> menu teardown.
	GameManager.load_level(0)
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"B0 load_level(0) builds the sim path (state %s, player %s)" % [
			str(GameManager.state), str(GameManager.player)])
	GameManager.complete_level()
	check(GameManager.state == GameManager.State.LEVEL_COMPLETE,
		"B0 complete_level ends the level on the sim path (state %s)" % str(GameManager.state))
	GameManager.return_to_menu()
	check(GameManager.state == GameManager.State.MENU,
		"B0 return_to_menu tears the sim level down (state %s)" % str(GameManager.state))


# --- Plan B0.1 step 4: the Echo on the new path -----------------------------
#
# TemporalManager records input bytes per sim tick into the PopReplay ring;
# release spawns a second sim participant (SimEcho) that steps PopSim.step
# from the recorded bytes; the legacy signal surface (echo_created /
# echo_expired / echo_event_replayed) carries it unchanged. What this cannot
# prove: that an echo makes a puzzle solvable — that is B1.3.

func _test_b0_echo() -> void:
	var data: Dictionary = LevelCatalog.get_sim_level(0)
	var bundle := _b0_dup({"tiles": data["tiles"], "mods": data["mods"], "entities": data["entities"]})
	var right_byte := PopInput.make(1, 0).to_byte()
	var neutral_byte := PopInput.neutral().to_byte()

	var container := Node2D.new()
	_sandbox.add_child(container)

	# Stock rules with the two-echo tier so two participants can stand side
	# by side (the level-4 override key); stock config restored on the way out.
	TemporalManager.configure_for_level({"max_active_echoes": 2})
	TemporalManager.set_echo_container(container)
	TemporalManager.clear_echoes()
	TemporalManager.reset_energy()

	var created: Array = []
	var expired := [0]
	var on_created := func(echo: Node, dur: float) -> void:
		created.append({"echo": echo, "dur": dur})
	var on_expired := func(_e: Node) -> void: expired[0] = int(expired[0]) + 1
	EventBus.echo_created.connect(on_created)
	EventBus.echo_expired.connect(on_expired)

	# (1) A take records through the live world: one byte per logic tick into
	# the bounded ring; release spawns the echo participant and charges energy.
	var w := SimWorld.new()
	w.setup(_b0_dup(bundle), int(data["seed"]), Vector2(840.0, 165.0), [])
	TemporalManager.register_sim_world(w)
	var energy_before := TemporalManager.energy
	check(TemporalManager.start_recording(), "sim take starts when a sim world is registered")
	check(TemporalManager.is_sim_recording(), "the recorder reports the sim take")
	w.step_ticks(8, [right_byte])     # cross the plate at col 16 (spawn x 280)
	w.step_ticks(60, [neutral_byte])  # stand still while the gate runs §9
	check(TemporalManager.sim_take_size() == 68,
		"one byte per sim tick is recorded (68 ticks -> %d bytes)" % TemporalManager.sim_take_size())
	TemporalManager.stop_recording()
	check(not TemporalManager.is_sim_recording(), "release ends the sim take")
	check(created.size() == 1 and (created[0]["echo"] is SimEcho),
		"release spawns a SimEcho through the bytes variant (got %d echo_created)" % created.size())
	check(absf(TemporalManager.energy
			- (energy_before - TemporalManager.config.energy_cost_per_echo)) < 0.001,
		"spawning the sim echo charges the unchanged energy cost (%.2f)" % TemporalManager.energy)
	if created.is_empty():
		EventBus.echo_created.disconnect(on_created)
		EventBus.echo_expired.disconnect(on_expired)
		TemporalManager.register_sim_world(null)
		TemporalManager.configure_for_level({})
		TemporalManager.reset_energy()
		container.queue_free()
		w.free()
		return
	var echo := created[0]["echo"] as SimEcho

	# (2) Two echoes from the same input buffer, live at once — plan B1.2's
	# new test: identical plate-timing events, both through the signal
	# surface the levels consume (EventBus.echo_event_replayed).
	var second := TemporalManager.spawn_sim_echo(echo.take, echo.start_state)
	check(second != null and TemporalManager.echo_count() == 2,
		"a second echo replays the same take side by side (count %d)" % TemporalManager.echo_count())
	var seen1: Array = []
	var seen2: Array = []
	var on_ev1 := func(e: Node, id: StringName) -> void:
		if e == echo:
			seen1.append(String(id))
	var on_ev2 := func(e: Node, id: StringName) -> void:
		if e == second:
			seen2.append(String(id))
	EventBus.echo_event_replayed.connect(on_ev1)
	EventBus.echo_event_replayed.connect(on_ev2)
	w.step_ticks(68, [])  # world idles (neutral); each echo consumes its take
	EventBus.echo_event_replayed.disconnect(on_ev1)
	EventBus.echo_event_replayed.disconnect(on_ev2)
	check(seen1.has("press:0,16") and seen1.has("open:0,19"),
		"the echo's replay crosses the plate and parks the gate (events %s)" % str(seen1))
	check(seen1 == seen2,
		"two echoes from the same input buffer produce identical plate-timing events (%d vs %d)" % [
			seen1.size(), seen2.size()])

	# (3) The echo's state IS the live-sim replay of its take: hash-equal to a
	# manual PopSim.step loop from the recorded start state (plan B1.1's
	# "replays through a live sim"), and two participants hash-equal.
	var manual := _b0_state_at(data, 0, 280, 55)  # the take's start: spawn (840,165)
	for b: Variant in echo.take.bytes:
		manual = PopSim.step(manual, PopInput.from_byte(int(b)))
	check(PopSim.hash_state(echo.state) == PopSim.hash_state(manual),
		"the echo's state is the live-sim replay of its take (hash %08x)" % PopSim.hash_state(echo.state))
	check(PopSim.hash_state(echo.state) == PopSim.hash_state(second.state),
		"two echoes from the same take step to identical states")

	# (4) Final-pose hold (non-loop default): the take ran out, so more world
	# ticks leave the participants exactly where they stopped.
	var held_x := int(echo.state["x"])
	var held_tick := int(echo.state["tick"])
	w.step_ticks(30, [neutral_byte])
	check(int(echo.state["x"]) == held_x and int(echo.state["tick"]) == held_tick
			and is_instance_valid(echo),
		"the echo holds its final pose when the take runs out (x %d, tick %d)" % [
			held_x, int(echo.state["tick"])])

	# (5) The buffer cap is enforced, not advisory (plan B1.1): a long take
	# hard-stops at RING_CAPACITY and still produces an echo.
	var w2 := SimWorld.new()
	w2.setup(_b0_dup(bundle), int(data["seed"]), Vector2(840.0, 165.0), [])
	TemporalManager.register_sim_world(w2)
	check(TemporalManager.start_recording(), "a second take begins")
	w2.step_ticks(40, [right_byte])
	check(TemporalManager.sim_take_size() == 40,
		"mid-take the ring holds every tick (40 -> %d)" % TemporalManager.sim_take_size())
	w2.step_ticks(80, [right_byte])  # 120 total: the ring keeps the newest 96
	check(not TemporalManager.is_sim_recording(), "the take hard-stops at the ring cap")
	check(created.size() == 3, "the capped take still produced an echo (created %d)" % created.size())
	check(TemporalManager.echo_count() <= 2,
		"the active-echo cap is enforced (%d <= 2)" % TemporalManager.echo_count())
	if created.size() == 3:
		var capped := created[2]["echo"] as SimEcho
		check(capped != null and capped.take.size() == PopReplay.RING_CAPACITY,
			"the buffer is bounded at RING_CAPACITY bytes (%d)" % (
				capped.take.size() if capped != null else -1))

	# (6) The signal surface is unchanged: the retired echo surfaced
	# echo_expired, and clear_echoes removes every sim echo (its free-only
	# teardown behaviour is the pre-existing one, untouched).
	check(expired[0] >= 1, "retiring the oldest echo surfaced echo_expired (%d)" % int(expired[0]))
	TemporalManager.clear_echoes()
	check(TemporalManager.echo_count() == 0, "clear_echoes removes every sim echo")
	EventBus.echo_created.disconnect(on_created)
	EventBus.echo_expired.disconnect(on_expired)

	# Restore the stock state for the sections that follow.
	TemporalManager.cancel_recording("test_cleanup")
	TemporalManager.register_sim_world(null)
	TemporalManager.configure_for_level({})
	TemporalManager.reset_energy()
	container.queue_free()
	w.free()
	w2.free()


# --- Plan B1.3: an echo's stance presses the world's plates ----------------
#
# Session 010. The tutorial puzzle, solved through the echo path exactly as
# designed: record a take that ends standing on the plate, release the echo,
# step off — the memory's stance re-fires the world's gate (the press that
# matters comes from the ECHO, proven by the world-level event count) and
# holds it open while the kid walks through into the exit door. Level 1's
# route to the ledge is gate 5's proven ground; this test isolates the
# mechanic. The negative control (the level cannot be completed WITHOUT the
# echo) is level 2's mandatory-echo test, session 010 step 3d.
func _test_b13_echo_plate() -> void:
	var data: Dictionary = LevelCatalog.get_sim_level(0)
	var bundle := _b0_dup({"tiles": data["tiles"], "mods": data["mods"], "entities": data["entities"]})

	var container := Node2D.new()
	_sandbox.add_child(container)
	TemporalManager.configure_for_level({})
	TemporalManager.set_echo_container(container)
	TemporalManager.clear_echoes()
	TemporalManager.reset_energy()

	var w := SimWorld.new()
	w.setup(_b0_dup(bundle), int(data["seed"]), Vector2(195.0, 165.0), [])
	TemporalManager.register_sim_world(w)

	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var right_byte := right.to_byte()
	var neutral_byte := neutral.to_byte()

	var events: Array = []
	var on_ent := func(kind: StringName, key: String) -> void:
		events.append("%s:%s" % [String(kind), key])
	EventBus.sim_entity_event.connect(on_ent)
	var exit_hit := [false]
	var on_exit := func() -> void: exit_hit[0] = true
	w.exit_reached.connect(on_exit)

	# (1) Park the kid on the ledge at col 15 (gate 5 proves the route there;
	# this test starts him in place to isolate the echo-plate mechanic).
	w.state["x"] = 58 + 14 * 15 + 10
	var presses_before := 0

	# (2) Record a take: walk onto the plate at col 16 and STAND there, so
	# the take ends with the plate held and the released echo replays into
	# exactly that stance.
	check(TemporalManager.start_recording(), "B1.3 the take begins on the sim path")
	var g1 := 0
	while PopSim._col_of(PopSim._foot_x(w.state)) != 16 and int(w.state["dead"]) == 0 and g1 < 20:
		w.step_with(right)
		g1 += 1
	check(PopSim._col_of(PopSim._foot_x(w.state)) == 16,
		"B1.3 the kid walks onto the plate at col 16 (x %d, %d ticks)" % [int(w.state["x"]), g1])
	w.step_ticks(8, [neutral_byte])   # take ends standing on the plate
	TemporalManager.stop_recording()
	var echo_count_at_release := TemporalManager.echo_count()
	check(echo_count_at_release == 1 and TemporalManager.active_sim_echoes().size() == 1,
		"B1.3 release spawns one SimEcho (count %d)" % echo_count_at_release)

	# (3) Step off and walk toward the gate. The kid's own press fired the
	# plate once during the take; the press that re-fires it now must come
	# from the ECHO's stance.
	for e: String in events:
		if e == "press:0,16":
			presses_before += 1
	check(presses_before == 1,
		"B1.3 the kid's own press fired the plate once during the take (got %d)" % presses_before)
	var first_open := -1
	var closed_after_open := false
	var g2 := 0
	while not exit_hit[0] and int(w.state["dead"]) == 0 and g2 < 220:
		w.step_with(right)
		var mod := int((w.state["gates"]["0,19"] as Dictionary)["mod"])
		if first_open >= 0 and mod < PopTables.GATE_OPEN_THRESHOLD:
			closed_after_open = true
		if first_open < 0 and mod >= PopTables.GATE_OPEN_THRESHOLD:
			first_open = g2
		g2 += 1
	var presses_after := 0
	for e2: String in events:
		if e2 == "press:0,16":
			presses_after += 1
	check(presses_after >= 2,
		"B1.3 the echo's stance re-presses the WORLD's plate after the kid stepped off (%d presses, got %s)" % [
			presses_after, str(events)])
	check(not closed_after_open,
		"B1.3 once the gate reads open it never closes again while the echo holds (first open tick %d)" % first_open)
	check(exit_hit[0] and int(w.state["dead"]) == 0,
		"B1.3 the kid walks through the held gate into the exit door (dead %d, %d ticks)" % [
			int(w.state["dead"]), g2])
	var echo := TemporalManager.active_sim_echoes()[0] as SimEcho
	check(echo != null and echo.cursor() >= echo.take.size(),
		"B1.3 the echo is still standing on the plate when the kid exits (cursor %d / take %d)" % [
			echo.cursor() if echo != null else -1, echo.take.size() if echo != null else -1])

	EventBus.sim_entity_event.disconnect(on_ent)
	TemporalManager.cancel_recording("test_cleanup")
	TemporalManager.register_sim_world(null)
	TemporalManager.clear_echoes()
	TemporalManager.configure_for_level({})
	TemporalManager.reset_energy()
	container.queue_free()
	w.free()


# --- Session 010: the guard duel on the sim path (plan §4.7) ---------------
#
# The first Godot-side enemy that consumes sim events on the NEW path: the
# guard reads the world's per-tick snapshot + input byte (read-only) and
# REQUESTS damage through SimWorld, the single writer (SimGuard documents
# the boundary). Accept: the scripted duel runs deterministically across two
# runs, on the 10 fps fight tick, with kid damage landing in the sim state.
# Duel expectations come from PARITY §12/§13/§20 wherever a row exists; the
# driver (activation range, byte→command mapping, kid position source) is
# labelled sim characterization. FIGHT FEEL IS NOT VERIFIED — needs human
# playtest.
func _guard_arena() -> Dictionary:
	const T := PopTables.Tile
	var row0: Array = []
	var row1: Array = []
	var row2: Array = []
	for i: int in 30:
		row0.append(T.FLOOR)
		row1.append(T.FLOOR)
		row2.append(T.EMPTY)
	return {
		"tiles": [row0, row1, row2],
		"mods": {},
		"entities": {"gates": {}, "plates": {}, "links": [], "exit": {}},
	}


func _test_sim_guard_duel() -> void:
	var arena := _guard_arena()
	var strike_byte := PopInput.make(0, 0, 0, 1).to_byte()   # special bit 1 = strike
	var neutral_byte := PopInput.neutral().to_byte()
	# The A4.3 attack cadence (strike every 5th input), as sim-path bytes.
	var script: Array = []
	for i: int in 300:
		script.append(strike_byte if (i % 5) == 0 else neutral_byte)

	var run := func(seed_n: int, guard_x: int, script: Array) -> Dictionary:
		var w := SimWorld.new()
		w.setup(_b0_dup(arena), seed_n, Vector2(300.0, 165.0), [])   # x = 100 = START_X
		TemporalManager.register_sim_world(w)
		var g := SimGuard.new()
		_sandbox.add_child(g)
		g.setup(w, guard_x, 0, seed_n)
		var events: Array = []
		var on_ev := func(kind: StringName) -> void: events.append(String(kind))
		g.duel_event.connect(on_ev)
		w.step_ticks(300, script)
		var out := {
			"transcript": g.transcript.duplicate(),
			"fight": g.fight_count(),
			"active": g.active,
			"guard_hp": int(g.guard["hp"]),
			"guard_dead": int(g.guard["dead"]),
			"sim_hp": int(w.state["hp"]),
			"sim_dead": int(w.state["dead"]),
			"hash": PopSim.hash_state(w.state),
			"events": events.duplicate(),
		}
		g.duel_event.disconnect(on_ev)
		g.free()
		TemporalManager.register_sim_world(null)
		w.free()
		return out

	# (1) A nearby guard wakes and fights on the 10 fps fight tick driven by
	# the 12 fps sim clock: 300 logic ticks -> exactly 250 fight ticks.
	var a: Dictionary = run.call(777, 107, script)   # START_X + START_DIST - FRONT_OFFSET
	check(bool(a["active"]) and (a["transcript"] as Array).size() > 0,
		"sim guard a guard within range wakes and fights (transcript %d entries)" % (a["transcript"]).size())
	check((a["transcript"] as Array).has("k:strike"),
		"the kid's strike rides the input byte's special bit into the duel (got %s)" % str((a["transcript"] as Array).slice(0, 6)))
	check(int(a["fight"]) == 300 * PopTables.TICK_HZ_SWORD / PopTables.TICK_HZ_TRAVERSE,
		"the duel steps at the 10 fps fight tick off the 12 fps clock (got %d, want 250)" % int(a["fight"]))

	# (2) Every duel hit lands in the sim state — the guard's damage REQUEST
	# is applied by the single writer (hp 3 - hits, death included).
	var kid_hits := 0
	for line: String in a["transcript"]:
		if line == "kid:hit" or line == "kid:died":
			kid_hits += 1
	if int(a["sim_dead"]) != 0:
		check(int(a["sim_hp"]) == 0,
			"a lethal duel leaves the sim kid at 0 hp, dead (got %d)" % int(a["sim_hp"]))
	else:
		check(int(a["sim_hp"]) == PopTables.KID_HP_START - kid_hits,
			"every duel hit lands in the sim state (hp %d = %d - %d hits)" % [
				int(a["sim_hp"]), PopTables.KID_HP_START, kid_hits])
	if int(a["guard_dead"]) != 0:
		check((a["events"] as Array).has("defeated"),
			"the guard's death surfaces as a duel event (got %s)" % str(a["events"]))
	var tr: Array = a["transcript"]
	check(str(tr[tr.size() - 1]).begins_with("end:"),
		"the duel runs to a decision or the budget (last %s)" % str(tr[tr.size() - 1]))
	# Pinned outcome for this seed + script (deterministic; the skill-0
	# values behind it are PARITY §12 rows, the fight feel is characterization
	# and NOT VERIFIED — needs human playtest).
	check(str(tr[tr.size() - 1]) == "end:kid" and int(a["guard_dead"]) != 0
			and int(a["sim_dead"]) == 0,
		"seed 777 strike cadence: the kid wins the skill-0 duel (guard dead %d, kid dead %d, hp %d)" % [
			int(a["guard_dead"]), int(a["sim_dead"]), int(a["sim_hp"])])

	# (3) Plan §8 gate 3 on the sim path: same seed + same script -> identical
	# transcripts, outcomes and world hashes.
	var b: Dictionary = run.call(777, 107, script)
	check((a["transcript"] as Array) == (b["transcript"] as Array)
			and int(a["hash"]) == int(b["hash"])
			and int(a["sim_hp"]) == int(b["sim_hp"])
			and int(a["guard_hp"]) == int(b["guard_hp"]),
		"same seed → identical sim-path duel transcript, outcome and world hash")

	# (4) The seed is actually in play (PARITY §14 generator): with the A4.3
	# pacing cadence (block every 4th tick), the guard's strike frames land
	# against the kid's block/parry frames at seed-dependent alignments, so
	# the transcripts differ. (The strike script above resolves so fast it
	# pins determinism; a fully idle script would be seed-blind — failed
	# draws leave no transcript trace.)
	var block_byte := PopInput.make(0, 0, 0, 2).to_byte()   # special bit 2 = block
	var pacing: Array = []
	for i: int in 300:
		pacing.append(block_byte if (i % 4) != 3 else neutral_byte)
	var c1: Dictionary = run.call(777, 107, pacing)
	var c2: Dictionary = run.call(999, 107, pacing)
	check((c1["transcript"] as Array) != (c2["transcript"] as Array),
		"a different seed produces a different sim-path duel transcript (%d vs %d entries)" % [
			(c1["transcript"] as Array).size(), (c2["transcript"] as Array).size()])
	check(int(c1["sim_dead"]) != 0 and int(c2["sim_dead"]) != 0,
		"the pacing runs kill the undefended kid on both seeds (dead %d / %d)" % [
			int(c1["sim_dead"]), int(c2["sim_dead"])])

	# (5) A guard beyond the wake range sleeps: no draws, no transcript.
	var d: Dictionary = run.call(777, 400, script)   # 300 units from the kid > ACTIVATE_RANGE
	check(not bool(d["active"]) and (d["transcript"] as Array).is_empty(),
		"a guard beyond the wake range never fights (transcript %d entries)" % (d["transcript"]).size())


# --- Session 010 step 3d: level 2, Hall of Echoes (plan B1.3 + trim L2) ----
#
# The thesis level on the new path: record a take that ends standing on the
# plate, release the echo, then do the skill route (drop, pit jump, hang-
# climb, guard duel) while the memory holds the gate — the "cooperate with
# your past self" beat. Accept (session 010 brief): scripted playthrough
# completes level 2 (gate 5 extended); the echo puzzle is MANDATORY (the
# negative run proves the level cannot be completed without it); the duel
# outcome is deterministic (same seed, pinned); expected values are PARITY
# rows (§9 gate schedule, §12 skill-0 tables) where they exist, everything
# else labelled characterization. FAIRNESS AND DIFFICULTY ARE NOT VERIFIED
# — needs human playtest.
func _test_b13_level2() -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)
	var edge_walk := PopInput.make(1, 0, 1)
	var grab := PopInput.make(0, -1, 1)
	var strike := PopInput.make(0, 0, 0, 1)   # special bit 1 = duel strike

	# --- negative run first: SOLO, even the best line cannot finish -------
	# The kid presses the plate himself and holds it until the gate parks
	# (the optimal solo start), then runs the route. The §9 window after
	# stepping off is 50 ticks; the route needs ~200. Mandatory-echo proof.
	GameManager.load_level(1)
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"level 2 loads on the sim path through the real scene (state %s)" % str(GameManager.state))
	if not (GameManager.player is SimPlayer):
		GameManager.return_to_menu()
		return
	var solo_events: Array = []
	var on_ent_solo := func(kind: StringName, key: String) -> void:
		solo_events.append("%s:%s" % [String(kind), key])
	EventBus.sim_entity_event.connect(on_ent_solo)
	var solo_world: SimWorld = (GameManager.player as SimPlayer).world
	# walk onto the plate at col 3 with tap-steps: a full run's stop-skid
	# (~20 units) always overshoots a 14-unit tile, so the settle would land
	# off the plate (session 010: measured at x 119, foot col 4).
	var s1 := 0
	while PopSim._col_of(PopSim._foot_x(solo_world.state)) != 3 and s1 < 30:
		solo_world.step_with(right)
		solo_world.step_with(neutral)
		s1 += 1
	# hold it until the gate parks (optimal solo play), then run the route
	var s2 := 0
	while int((solo_world.state["gates"]["0,20"] as Dictionary)["mod"]) < PopTables.GATE_PARKED \
			and s2 < 100:
		solo_world.step_with(neutral)
		s2 += 1
	var solo_ticks := 0
	while GameManager.state == GameManager.State.PLAYING \
			and int(solo_world.state["dead"]) == 0 and solo_ticks < 900:
		# the same route the positive run takes, minus the echo: drop, pit,
		# grab, climb, duel (strike cadence in range), walk to the gate.
		var g: Dictionary = (solo_world.state["gates"]["0,20"] as Dictionary)
		if int(solo_world.state["row"]) == 0 \
				and PopSim._col_of(PopSim._foot_x(solo_world.state)) >= 14:
			# on the ledge: duel first (strike in reach), else walk right
			var guard := solo_world.get_parent().get_node_or_null("SimGuard") as SimGuard
			if guard != null and int(guard.guard["dead"]) == 0 \
					and absi(int(solo_world.state["x"]) - guard.guard_x) <= 40:
				solo_world.step_with(strike)
			else:
				solo_world.step_with(right)
		elif int(solo_world.state["row"]) == 1 and int(solo_world.state["x"]) >= 150 \
				and int(solo_world.state["x"]) <= 178 \
				and (String(solo_world.state["seq"]) == "startrun" \
					or String(solo_world.state["seq"]) == "run_cycle"):
			solo_world.step_with(jump)
		elif String(solo_world.state["seq"]) == "hang":
			solo_world.step_with(grab)
		elif int(solo_world.state["row"]) == 1 and int(solo_world.state["x"]) >= 250:
			solo_world.step_with(grab)   # in the window: Shift+Up grabs/climbs
		elif int(solo_world.state["row"]) == 1 and int(solo_world.state["x"]) >= 230:
			solo_world.step_with(edge_walk)
		else:
			solo_world.step_with(right)
		solo_ticks += 1
	var solo_gate_mod := int((solo_world.state["gates"]["0,20"] as Dictionary)["mod"])
	var solo_x := int(solo_world.state["x"])
	check(solo_events.has("press:0,3") and solo_events.has("open:0,20"),
		"level 2 solo the kid's own press opens the gate (got %s)" % str(solo_events))
	check(GameManager.state == GameManager.State.PLAYING and solo_gate_mod < PopTables.GATE_OPEN_THRESHOLD \
			and solo_x < 338,
		"level 2 is MANDATORY-echo: even the best solo line is pinned at the closed gate "
			+ "(x %d, gate mod %d, state %s, %d ticks) — the §9 window is 50 ticks, the route ~200" % [
				solo_x, solo_gate_mod, str(GameManager.state), solo_ticks])
	EventBus.sim_entity_event.disconnect(on_ent_solo)
	GameManager.return_to_menu()

	# --- positive run: record, release, route, duel, exit -----------------
	GameManager.load_level(1)
	var world: SimWorld = (GameManager.player as SimPlayer).world
	var events: Array = []
	var checkpoints: Array = []
	var completed := [false]
	var on_ent := func(kind: StringName, key: String) -> void:
		events.append("%s:%s" % [String(kind), key])
	var on_cp := func(id: StringName) -> void: checkpoints.append(String(id))
	var on_done := func(_id: StringName) -> void: completed[0] = true
	EventBus.sim_entity_event.connect(on_ent)
	EventBus.checkpoint_reached.connect(on_cp)
	EventBus.level_completed.connect(on_done)
	var guard := world.get_parent().get_node_or_null("SimGuard") as SimGuard
	check(guard != null and guard.skill == 0,
		"level 2 spawns the skill-0 guard from the level data (got %s)" % str(guard != null))

	# (1) Record the take: walk onto the plate at col 3, settle to a stand
	# ON it (the run-stop skid drifts a few units — the take must end with
	# the stance actually on the plate, or the released echo stops holding).
	check(TemporalManager.start_recording(), "level 2 the take begins at spawn")
	var p1 := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 3 and p1 < 30:
		world.step_with(right)
		world.step_with(neutral)   # tap-walk: keep the approach slow enough to stop on the tile
		p1 += 1
	var p1b := 0
	while String(world.state["seq"]) != "stand" and p1b < 15:
		world.step_with(neutral)
		p1b += 1
	var plate_foot := PopSim._col_of(PopSim._foot_x(world.state))
	check(plate_foot == 3,
		"level 2 the take settles standing ON the plate (foot col %d, x %d)" % [
			plate_foot, int(world.state["x"])])
	world.step_ticks(8, [neutral.to_byte()])
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"level 2 release spawns the echo that will hold the plate (count %d)" % TemporalManager.echo_count())

	# (2) The route: drop off the start floor, run-jump the pit, hang-climb
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
		"level 2 the jump clears the spike pit (x %d row %d dead %d)" % [
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
		"level 2 the climb-out stands on the ledge (row %d dead %d)" % [
			int(world.state["row"]), int(world.state["dead"])])

	# (3) The duel: walk into range, strike cadence until the guard falls.
	var guard_defeats := [0]
	var on_duel := func(kind: StringName) -> void:
		if kind == &"defeated":
			guard_defeats[0] = int(guard_defeats[0]) + 1
	if guard != null:
		guard.duel_event.connect(on_duel)
	var d1 := 0
	while guard != null and int(guard.guard["dead"]) == 0 and int(world.state["dead"]) == 0 and d1 < 400:
		if absi(int(world.state["x"]) - guard.guard_x) <= 40:
			world.step_with(strike)
		else:
			world.step_with(right)
		d1 += 1
	check(guard != null and int(guard.guard["dead"]) != 0 and guard_defeats[0] == 1,
		"level 2 the scripted duel beats the skill-0 guard deterministically (seed %d; dead %d after %d ticks)" % [
			5252 + 1, int(guard.guard["dead"]) if guard != null else -1, d1])
	check(int(world.state["hp"]) > 0 and int(world.state["dead"]) == 0,
		"level 2 the kid survives the duel (hp %d dead %d)" % [
			int(world.state["hp"]), int(world.state["dead"])])

	# (4) Walk through the held gate into the exit door — the loop ends when
	# the SCENE completes the level (exit_reached -> complete_level).
	var first_open := -1
	var closed_after_open := false
	var r8 := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and r8 < 300:
		world.step_with(right)
		var mod := int((world.state["gates"]["0,20"] as Dictionary)["mod"])
		if first_open >= 0 and mod < PopTables.GATE_OPEN_THRESHOLD:
			closed_after_open = true
		if first_open < 0 and mod >= PopTables.GATE_OPEN_THRESHOLD:
			first_open = r8
		r8 += 1
	if guard != null:
		guard.duel_event.disconnect(on_duel)

	var presses := 0
	for e: String in events:
		if e == "press:0,3":
			presses += 1
	check(presses >= 2,
		"level 2 the echo re-presses the world's plate while the kid crosses (presses %d)" % presses)
	check(not closed_after_open and first_open >= 0,
		"level 2 the gate never closes while the echo holds (first open tick %d, echoes %d, events %s)" % [
			first_open, TemporalManager.active_sim_echoes().size(), str(events)])
	check(checkpoints.has("ground") and checkpoints.has("ledge"),
		"level 2 both position triggers fire on the way (got %s)" % str(checkpoints))
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE \
			and int(world.state["dead"]) == 0,
		"level 2 the scripted run completes end to end with the echo + duel (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), r8])

	EventBus.sim_entity_event.disconnect(on_ent)
	EventBus.checkpoint_reached.disconnect(on_cp)
	EventBus.level_completed.disconnect(on_done)
	GameManager.return_to_menu()
	# FINISHABLE ≠ FAIR: the scripted runs prove completability and the
	# mandatory-echo property. Feel, fairness and difficulty are **not
	# verified, needs human playtest**.


# --- Session 011 step 4: level 3 boss, the Time Warden (plan B2.3/B3.1) -----
#
# The first boss on the sim path, built on the guard framework: high skill
# (the cited PARITY §12 profile), a design HP pool, and a SHIELD that drops
# only while an ECHO holds the arena plate (the kid's own press never
# counts). Accept (S011 brief): scripted completion WITH the echo; a negative
# run proving the boss cannot be beaten without it; determinism across two
# runs; the fight at most 3 minutes (1800 ticks of the 10 fps fight clock);
# no softlock on echo expiry (the re-record/respawn loop tested). Expected
# values are PARITY rows where they exist (§12 profile, the 10 fps fight
# tick); the pool size, cadence and seed are characterization. FAIRNESS AND
# DIFFICULTY ARE NOT VERIFIED — needs human playtest.
func _test_b23_level3_boss() -> void:
	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var strike := PopInput.make(0, 0, 0, 1)   # special bit 1 = duel strike
	var block := PopInput.make(0, 0, 0, 2)    # special bit 2 = duel block

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

	# --- (1) POSITIVE: record on the plate, release, fight, exit ---------
	var pos := _l3_positive_run()
	check(bool(pos["completed"]),
		"level 3 scripted completion WITH the echo (completed %s, kid hp %s, %s fight ticks)" % [
			str(pos["completed"]), str(pos["kid_hp"]), str(pos["fight"])])
	check(int(pos["boss_dead"]) != 0 and int(pos["boss_hp"]) == 0,
		"the Warden falls in the scripted fight (dead %s, hp %s)" % [str(pos["boss_dead"]), str(pos["boss_hp"])])
	check(int(pos["fight"]) <= 1800,
		"the fight fits the 3-minute budget (%s fight ticks of the 10 fps clock ≤ 1800)" % str(pos["fight"]))
	check(int(pos["fight"]) <= 1200,
		"a single take covers the fight (echo lifetime 120 s = 1200 fight ticks; fought %s)" % str(pos["fight"]))
	check(int(pos["kid_hp"]) > 0 and int(pos["kid_dead"]) == 0,
		"the kid survives the duel (hp %s, dead %s)" % [str(pos["kid_hp"]), str(pos["kid_dead"])])
	check(bool(pos["engaged"]) and int(pos["shield_events"]) >= 1,
		"the boss bar engages and the echo's stance drops the shield (engaged %s, shield transitions %s)" % [
			str(pos["engaged"]), str(pos["shield_events"])])
	
	# --- (2) NEGATIVE: without an echo the boss cannot be beaten ---------
	GameManager.load_level(2)
	var nworld: SimWorld = (GameManager.player as SimPlayer).world
	var nboss := nworld.get_parent().get_node_or_null("SimBoss") as SimBoss
	var n_completed := [false]
	var on_ndone := func(_id: StringName) -> void: n_completed[0] = true
	EventBus.level_completed.connect(on_ndone)
	# Walk into the arena and strike in range for the same budget — no take,
	# no echo: the kid's own plate press (walked over, col 4) never counts.
	var n1 := 0
	while int(nworld.state["dead"]) == 0 and n1 < 400 \
			and absi(int(nworld.state["x"]) - nboss.guard_x) > 15:
		nworld.step_with(right)
		n1 += 1
	var n2 := 0
	while int(nworld.state["dead"]) == 0 and n2 < 900 and int(nboss.guard["dead"]) == 0:
		# Fight at the duel's real engagement band: opp = abs + FRONT_OFFSET
		# (13, both facing), so strikes only connect at abs <= 15 (opp < 29 =
		# HIT_MAX). Striking from further out whiffs forever (measured: the
		# skill-4 guard parks at opp 32 and both fighters idle).
		nworld.step_with(_l3_cmd(nboss, nworld))
		n2 += 1
	var absorbed := 0
	for line: String in nboss.transcript:
		if String(line) == "boss:shield":
			absorbed += 1
	EventBus.level_completed.disconnect(on_ndone)
	check(int(nboss.guard["hp"]) == SimBoss.BOSS_HP and int(nboss.guard["dead"]) == 0,
		"WITHOUT an echo the Warden never loses a point (hp %d after %d fight ticks)" % [
			int(nboss.guard["hp"]), nboss.fight_count()])
	check(absorbed > 0,
		"the strikes really happened and were absorbed by the shield (%d boss:shield markers)" % absorbed)
	check(not n_completed[0] and int(nboss.guard["dead"]) == 0,
		"the level is not completable without the echo (completed %s, boss alive, state %s)" % [
			str(n_completed[0]), str(GameManager.state)])
	GameManager.return_to_menu()

	# --- (3) ECHO EXPIRY: no softlock — shield returns, re-record wins ---
	GameManager.load_level(2)
	var eworld: SimWorld = (GameManager.player as SimPlayer).world
	var eboss := eworld.get_parent().get_node_or_null("SimBoss") as SimBoss
	# take 1: settle on the plate, release — the kid is still safe here
	# (the plate sits outside the boss's 90-unit wake range).
	check(TemporalManager.start_recording(), "expiry flow: the take begins at spawn")
	var e1 := 0
	while PopSim._col_of(PopSim._foot_x(eworld.state)) != 4 and e1 < 40:
		eworld.step_with(right)
		eworld.step_with(neutral)
		e1 += 1
	var e1b := 0
	while String(eworld.state["seq"]) != "stand" and e1b < 15:
		eworld.step_with(neutral)
		e1b += 1
	_l3_ticks8(eworld)
	TemporalManager.stop_recording()
	# The echo replays the take from its start (the walk from spawn), so its
	# stance reaches the plate a beat after release - step until it does.
	var esh := 0
	while eboss.shielded and esh < 150:
		_l3_neutral(eworld)
		esh += 1
	check(TemporalManager.echo_count() == 1 and not eboss.shielded,
		"take 1 releases and the echo's stance drops the shield (echoes %d, shielded %s, %d ticks)" % [
			TemporalManager.echo_count(), str(eboss.shielded), esh])
	# Force the lifetime timer to elapse — the same field _physics_process
	# decrements, so the production expiry path runs (two physics frames).
	for echo: TemporalEcho in TemporalManager.active_sim_echoes():
		echo._life_left = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(TemporalManager.echo_count() == 0,
		"the echo expires on its lifetime (echoes %d)" % TemporalManager.echo_count())
	_l3_neutral(eworld)
	check(eboss.shielded, "expiry brings the shield back on the next logic tick")
	# walk in and fight shielded: the boss takes NOTHING (each hit absorbs).
	var hp_shielded := int(eboss.guard["hp"])
	var e3 := 0
	var e_absorbed := 0
	while int(eworld.state["dead"]) == 0 and e3 < 300 and e_absorbed == 0:
		eWorld_step_cmd(eworld, eboss)
		if not eboss.transcript.is_empty() \
				and String(eboss.transcript[eboss.transcript.size() - 1]) == "boss:shield":
			e_absorbed += 1
		e3 += 1
	check(int(eboss.guard["hp"]) == hp_shielded and e_absorbed > 0,
		"after expiry the shielded Warden takes no damage (hp %d -> %d, %d absorbs)" % [
			hp_shielded, int(eboss.guard["hp"]), e_absorbed])
	# Re-record from wherever the kid ended up — walk back to the plate with
	# a parry tap between steps (the chasing boss gets no free hits on the
	# retreat; measured: an uncovered retreat bled the kid dry before e5).
	var e4 := 0
	while PopSim._col_of(PopSim._foot_x(eworld.state)) != 4 and e4 < 200 \
			and int(eworld.state["dead"]) == 0:
		eworld.step_with(PopInput.make(-1, 0))
		eworld.step_with(PopInput.make(0, 0, 0, 2))   # parry tap
		e4 += 1
	var e4b := 0
	while String(eworld.state["seq"]) != "stand" and e4b < 15 \
			and int(eworld.state["dead"]) == 0:
		eworld.step_with(neutral)
		e4b += 1
	if int(eworld.state["dead"]) == 0:
		check(TemporalManager.start_recording(), "expiry flow: the second take begins")
		_l3_ticks8(eworld)
		TemporalManager.stop_recording()
		eworld.step_with(neutral)
	check(TemporalManager.echo_count() == 1 and not eboss.shielded,
		"the SECOND take drops the shield again — no softlock on expiry (echoes %d, shielded %s)" % [
			TemporalManager.echo_count(), str(eboss.shielded)])
	# Finish: fight to the fall, walk into the exit door.
	var e_completed := [false]
	var on_edone := func(_id: StringName) -> void: e_completed[0] = true
	EventBus.level_completed.connect(on_edone)
	var e5 := 0
	while int(eboss.guard["dead"]) == 0 and int(eworld.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and e5 < 1750:
		eWorld_step_cmd(eworld, eboss)
		e5 += 1
	var e6 := 0
	while GameManager.state == GameManager.State.PLAYING and int(eworld.state["dead"]) == 0 and e6 < 400:
		eworld.step_with(right)
		e6 += 1
	EventBus.level_completed.disconnect(on_edone)
	check(int(eboss.guard["dead"]) != 0 and e_completed[0],
		"after the re-record the run finishes end to end (boss dead %d, completed %s, kid hp %d)" % [
			int(eboss.guard["dead"]), str(e_completed[0]), int(eworld.state["hp"])])
	GameManager.return_to_menu()

	# --- (4) DETERMINISM: two positive runs, identical duel records -------
	var d1 := _l3_positive_run()
	var d2 := _l3_positive_run()
	check((d1["transcript"] as Array) == (d2["transcript"] as Array)
			and int(d1["boss_hp"]) == int(d2["boss_hp"])
			and int(d1["kid_hp"]) == int(d2["kid_hp"])
			and bool(d1["completed"]) == bool(d2["completed"]),
		"same seed, same script -> identical Warden transcript and outcome (%d transcript entries, kid hp %s/%s)" % [
			(d1["transcript"] as Array).size(), str(d1["kid_hp"]), str(d2["kid_hp"])])
	check(bool(d1["completed"]) and bool(d2["completed"]),
		"both deterministic runs complete the level")
	# FINISHABLE ≠ FAIR: completability, the mandatory-echo property, the
	# 3-minute budget and determinism are proven headlessly. Feel, fairness
	# and difficulty are **not verified, needs human playtest**.


## The positive flow for one fresh level-3 run: record on the plate at col
## 4, release the take, walk into the arena, fight the Warden (strike with a
## block beat), walk into the exit door. Returns the metrics the acceptance
## checks assert on.
func _l3_positive_run() -> Dictionary:
	var out := {
		"ok": false, "completed": false, "transcript": [],
		"fight": 0, "boss_hp": -1, "boss_dead": -1,
		"kid_hp": -1, "kid_dead": -1,
		"engaged": false, "shield_events": 0,
	}
	GameManager.load_level(2)
	if not (GameManager.player is SimPlayer):
		GameManager.return_to_menu()
		return out
	var world: SimWorld = (GameManager.player as SimPlayer).world
	var boss := world.get_parent().get_node_or_null("SimBoss") as SimBoss
	if boss == null:
		GameManager.return_to_menu()
		return out
	var engaged := [false]
	var shield_events := [0]
	var on_engaged := func(_n: String, _c: int, _m: int) -> void: engaged[0] = true
	var on_shield := func(_s: bool) -> void: shield_events[0] = int(shield_events[0]) + 1
	EventBus.boss_engaged.connect(on_engaged)
	EventBus.boss_shield_changed.connect(on_shield)
	var completed := [false]
	var on_done := func(_id: StringName) -> void: completed[0] = true
	EventBus.level_completed.connect(on_done)

	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var strike := PopInput.make(0, 0, 0, 1)
	var block := PopInput.make(0, 0, 0, 2)

	# Record the take: tap-walk onto the plate at col 4, settle to a stand
	# ON it, hold a few ticks, release (same discipline as level 2).
	if not TemporalManager.start_recording():
		EventBus.boss_engaged.disconnect(on_engaged)
		EventBus.boss_shield_changed.disconnect(on_shield)
		EventBus.level_completed.disconnect(on_done)
		GameManager.return_to_menu()
		return out
	var p1 := 0
	while PopSim._col_of(PopSim._foot_x(world.state)) != 4 and p1 < 40:
		world.step_with(right)
		world.step_with(neutral)
		p1 += 1
	var p1b := 0
	while String(world.state["seq"]) != "stand" and p1b < 15:
		world.step_with(neutral)
		p1b += 1
	check(PopSim._col_of(PopSim._foot_x(world.state)) == 4,
		"L3 the take settles standing ON the arena plate (foot col %d)" %
			PopSim._col_of(PopSim._foot_x(world.state)))
	world.step_ticks(8, [neutral.to_byte()])
	TemporalManager.stop_recording()
	check(TemporalManager.echo_count() == 1,
		"L3 release spawns the echo that holds the plate (count %d)" % TemporalManager.echo_count())

	# The shield reacts on the next logic tick — the echo replays the take
	# from its start (the walk from spawn), so its stance reaches the plate
	# a beat after release; step until it does.
	var sh := 0
	while boss.shielded and sh < 150:
		world.step_with(neutral)
		sh += 1
	check(not boss.shielded, "L3 the echo's stance drops the Warden's shield (after %d ticks)" % sh)

	# Walk into range and fight with the adaptive cadence (chase → counter on
	# committed chains / hurt refractory → parry otherwise; engagement band
	# abs <= 15, see the negative run's opp_dist note).
	var fight := 0
	while int(boss.guard["dead"]) == 0 and int(world.state["dead"]) == 0 \
			and GameManager.state == GameManager.State.PLAYING and fight < 1750:
		world.step_with(_l3_cmd(boss, world))
		fight += 1

	# Walk into the open exit door.
	var ex := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and ex < 400:
		world.step_with(right)
		ex += 1

	out["completed"] = completed[0]
	out["transcript"] = (boss.transcript as Array).duplicate()
	out["fight"] = fight
	out["boss_hp"] = int(boss.guard["hp"])
	out["boss_dead"] = int(boss.guard["dead"])
	out["kid_hp"] = int(world.state["hp"])
	out["kid_dead"] = int(world.state["dead"])
	out["engaged"] = engaged[0]
	out["shield_events"] = shield_events[0]
	out["ok"] = true
	EventBus.boss_engaged.disconnect(on_engaged)
	EventBus.boss_shield_changed.disconnect(on_shield)
	EventBus.level_completed.disconnect(on_done)
	GameManager.return_to_menu()
	return out


## Adaptive fight command (characterization): chase the Warden to the duel
## band (abs <= 15 — opp = abs + FRONT_OFFSET must be < HIT_MAX 29), block
## only his committed swings (the kid's parry frames eat them) and counter
## everything else. Cadence D from the session-011 fight matrix: at the
## pinned duel seed this lands 5 hits before the kid's third incoming — the
## only tested configuration that beats hp 5 while surviving. Returning a
## WALK input while apart keeps the kid from walking PAST the boss toward
## the exit (measured: an abs-only script overshoots).
func _l3_cmd(boss: SimBoss, world: SimWorld) -> PopInput:
	var kx := int(world.state["x"])
	if absi(kx - boss.guard_x) > 15:
		return PopInput.make(1, 0) if boss.guard_x > kx else PopInput.make(-1, 0)
	if String(boss.guard["seq"]).contains("strike"):
		return PopInput.make(0, 0, 0, 2)   # parry the committed swing
	return PopInput.make(0, 0, 0, 1)      # counter everything else


## 8 neutral ticks while recording (the same hold level 2 uses).
func _l3_ticks8(w: SimWorld) -> void:
	w.step_ticks(8, [PopInput.neutral().to_byte()])


## One adaptive-fight step (see [method _l3_cmd]).
func eWorld_step_cmd(w: SimWorld, boss: SimBoss) -> void:
	w.step_with(_l3_cmd(boss, w))


## One neutral logic tick (keeps the shield/duel ticking without moving).
func _l3_neutral(w: SimWorld) -> void:
	w.step_with(PopInput.neutral())


# --- Session 010 step 4: the SoundEvent hook points -------------------------
#
# Every named SFX id fires in its own scenario, on the Godot side, with no
# audio files involved: the sim publishes the same diffs/milestones it
# always did and the hook layer names them. docs/AUDIO_BRIEF.md is the
# hand-off table (id -> where it fires -> suggested duration -> the
# ASSET_LICENSES.md rule for the eventual files).
func _sound_row(segments: Array) -> Array:
	var row: Array = []
	for i: int in 21:
		row.append(PopTables.Tile.EMPTY)
	for seg: Array in segments:
		for c: int in range(int(seg[0]), int(seg[1]) + 1):
			row[c] = int(seg[2])
	return row


func _test_sound_events() -> void:
	const T := PopTables.Tile
	var right_byte := PopInput.make(1, 0).to_byte()
	var seen: Array = []
	var on_sfx := func(id: StringName, _pos: Vector2) -> void: seen.append(String(id))
	SoundEvents.sfx.connect(on_sfx)

	# One world-runner per scenario: fresh world, scripted steps, teardown.
	# Returns the guard's duel transcript (empty when no guard participated).
	var run_arena := func(tiles: Array, mods: Dictionary, ticks: int,
			guard_skill: int = -1, spawn_px: Vector2 = Vector2(237.0, 165.0)) -> Array:
		var w := SimWorld.new()
		w.setup({"tiles": tiles, "mods": mods,
			"entities": {"gates": {}, "plates": {}, "links": [], "exit": {}}},
			777, spawn_px, [])
		TemporalManager.register_sim_world(w)
		var g: SimGuard = null
		if guard_skill >= 0:
			g = SimGuard.new()
			_sandbox.add_child(g)
			g.setup(w, 107, guard_skill, 777 if guard_skill == 0 else 4242)
		var strike_byte := PopInput.make(0, 0, 0, 1).to_byte()
		for i: int in ticks:
			var packed := right_byte
			if g != null:
				packed = strike_byte if (i % 5) == 0 else PopInput.neutral().to_byte()
			w.step_with(PopInput.from_byte(packed))
		var out: Array = g.transcript.duplicate() if g != null else []
		if g != null:
			g.free()
		TemporalManager.register_sim_world(null)
		w.free()
		return out

	# (1) The three landing windows (PARITY §7) + the fall-out death.
	run_arena.call([_sound_row([[0, 4, T.FLOOR]]), _sound_row([[0, 20, T.FLOOR]]),
		_sound_row([])], {}, 40)
	check(seen.has("land_soft"), "land_soft fires on a 1-row drop (got %s)" % str(seen))
	seen.clear()
	run_arena.call([_sound_row([[0, 4, T.FLOOR]]), _sound_row([]),
		_sound_row([[0, 20, T.FLOOR]])], {}, 40)
	check(seen.has("land_medium"), "land_medium fires on a 2-row drop (got %s)" % str(seen))
	seen.clear()
	run_arena.call([_sound_row([[0, 4, T.FLOOR]]), _sound_row([]), _sound_row([])], {}, 40)
	check(seen.has("land_hard") and seen.has("death"),
		"land_hard + death fire on a fall out of the world (got %s)" % str(seen))
	seen.clear()

	# (2) The spike impale (PARITY §8) — and the death it causes.
	run_arena.call([_sound_row([[0, 4, T.FLOOR]]), _sound_row([]),
		_sound_row([[0, 20, T.SPIKES]])], {"2,5": 3, "2,6": 3, "2,7": 3}, 40)
	check(seen.has("spike") and seen.has("death"),
		"spike (+ death) fires when the kid lands on spikes (got %s)" % str(seen))
	seen.clear()

	# (3) Plate press, gate open (park) and gate close (PARITY §9/§10).
	# The kid walks through the gate and STOPS before the world's edge (the
	# sim's entity stage is gated on the kid being alive — session 010 noted
	# that as a parity question for later — so a dead kid would freeze the
	# gate mid-close and the close milestone would never fire).
	var gt := PopLevel.small_test_level()
	var gw := SimWorld.new()
	gw.setup({"tiles": gt["tiles"], "mods": gt["mods"], "entities": gt["entities"]},
		4242, Vector2(300.0, 165.0), [])
	TemporalManager.register_sim_world(gw)
	for _i: int in 400:
		var packed := right_byte if int(gw.state["x"]) < 300 else PopInput.neutral().to_byte()
		gw.step_with(PopInput.from_byte(packed))
	check(int(gw.state["dead"]) == 0,
		"the gate-close scenario keeps the kid alive (dead %d)" % int(gw.state["dead"]))
	TemporalManager.register_sim_world(null)
	gw.free()
	check(seen.has("plate") and seen.has("gate_open") and seen.has("gate_close"),
		"plate / gate_open / gate_close fire through the §9-§10 milestones (got %s)" % str(seen))
	seen.clear()

	# (4) The sword ids through the live duel: the pinned skill-0 fight
	# (kid at START_X 100, guard at 107, seed 777 — the unit-test geometry)
	# gives strike, hurt (the kid's one hit taken) and the guard's death; a
	# skill-1 guard (block odds 150, PARITY §12) parries, which gives the
	# clash.
	var flat := [_sound_row([[0, 20, T.FLOOR]]), _sound_row([[0, 20, T.FLOOR]]),
		_sound_row([])]
	var tr0: Array = run_arena.call(flat, {}, 300, 0, Vector2(300.0, 165.0))
	check(seen.has("sword_strike") and seen.has("guard_death") and seen.has("sword_hurt"),
		"sword_strike / sword_hurt / guard_death fire in the skill-0 duel (got %s; duel %s)" % [
			str(seen), str(tr0.slice(0, 8))])
	seen.clear()
	var tr1: Array = run_arena.call(flat, {}, 300, 1, Vector2(300.0, 165.0))
	check(seen.has("sword_clash"),
		"sword_clash fires when the skill-1 guard parries (got %s; duel %s)" % [
			str(seen), str(tr1.slice(0, 8))])
	seen.clear()

	# (5) The echo ids through the real record/release path.
	var ew := SimWorld.new()
	ew.setup({"tiles": [_sound_row([[0, 20, T.FLOOR]]), _sound_row([[0, 20, T.FLOOR]]),
		_sound_row([])], "mods": {},
		"entities": {"gates": {}, "plates": {}, "links": [], "exit": {}}},
		777, Vector2(237.0, 165.0), [])
	TemporalManager.register_sim_world(ew)
	var container := Node2D.new()
	_sandbox.add_child(container)
	TemporalManager.configure_for_level({})
	TemporalManager.set_echo_container(container)
	TemporalManager.clear_echoes()
	TemporalManager.reset_energy()
	check(TemporalManager.start_recording(), "echo_record: the take begins")
	ew.step_ticks(10, [right_byte])
	TemporalManager.stop_recording()
	check(seen.has("echo_record") and seen.has("echo_release"),
		"echo_record / echo_release fire on the real record path (got %s)" % str(seen))
	TemporalManager.register_sim_world(null)
	TemporalManager.clear_echoes()
	TemporalManager.configure_for_level({})
	TemporalManager.reset_energy()
	container.queue_free()
	ew.free()
	seen.clear()

	SoundEvents.sfx.disconnect(on_sfx)


# --- Session 013 step 1: SfxPlayer wiring (plan B4.3) -----------------------
#
# Every id the sim emits must resolve to ITS OWN committed wav, played with
# its table volume through the pool, and the echo pair must take the B4.3
# treatment (rise/resolve pitch ramp, hollow EchoSFX bus). No audio device
# is involved: the assertions read the sfx_play_requested decision signal
# and the stream table, never audible output.
func _test_sfx_player() -> void:
	const IDS := ["land_soft", "land_medium", "land_hard", "spike", "death",
		"plate", "gate_open", "gate_close", "sword_clash", "sword_strike",
		"sword_hurt", "guard_death", "echo_record", "echo_release"]
	var seen: Array = []
	var on_play := func(id: StringName, path: String, volume_db: float,
			bus: StringName, treatment: StringName, pitch: float) -> void:
		seen.append({"id": String(id), "path": path, "volume_db": volume_db,
			"bus": String(bus), "treatment": String(treatment), "pitch": pitch})
	SfxPlayer.sfx_play_requested.connect(on_play)

	# (1) Table completeness: every AUDIO_BRIEF id has an entry, and the table
	# carries no stray ids the sim never emits.
	var table_ids: Array = []
	for id: StringName in SfxPlayer.EVENTS:
		table_ids.append(String(id))
	for id: String in IDS:
		check(SfxPlayer.EVENTS.has(StringName(id)),
			"SfxPlayer table covers '%s'" % id)
	check(table_ids.size() == IDS.size(),
		"SfxPlayer table has exactly the 14 brief ids (got %d)" % table_ids.size())

	# (2) Each id requests playback of ITS OWN stream, with its table volume.
	for id: String in IDS:
		seen.clear()
		check(SfxPlayer.play_id(StringName(id)),
			"play_id('%s') succeeds" % id)
		check(seen.size() == 1,
			"'%s' requests exactly one playback (got %d)" % [id, seen.size()])
		if seen.is_empty():
			continue
		var req: Dictionary = seen[0]
		check(req["path"] == "res://audio/sfx/%s.wav" % id,
			"'%s' requests its own stream (%s)" % [id, req["path"]])
		check(is_equal_approx(float(req["volume_db"]),
				float(SfxPlayer.EVENTS[StringName(id)]["volume_db"])),
			"'%s' plays at its table volume (%s dB)" % [id, str(req["volume_db"])])
		var stream: AudioStream = load(String(req["path"]))
		check(stream is AudioStreamWAV,
			"'%s' stream imports as AudioStreamWAV" % id)

	# (3) Pitch jitter stays small (documented ±5% + the treatment's 0.8/1.2
	# start offsets) — assert the resting pitch for plain sounds.
	seen.clear()
	SfxPlayer.play_id(&"land_soft")
	if not seen.is_empty():
		var pitch := float(seen[0]["pitch"])
		check(absf(pitch - 1.0) <= SfxPlayer.PITCH_JITTER + 0.0001,
			"plain sounds play within the jitter band (pitch %.3f)" % pitch)

	# (4) The B4.3 echo treatment: record RISES from 0.8, release RESOLVES
		# from 1.2, both on the hollow EchoSFX bus; everything else stays on SFX.
	seen.clear()
	SfxPlayer.play_id(&"echo_record")
	check(not seen.is_empty() and is_equal_approx(float(seen[0]["pitch"]), 0.8)
			and String(seen[0]["treatment"]) == "rise"
			and String(seen[0]["bus"]) == "EchoSFX",
		"echo_record rises from 0.8 on the EchoSFX bus (%s)" % str(seen))
	seen.clear()
	SfxPlayer.play_id(&"echo_release")
	var release_pitch: float = 0.0
	if not seen.is_empty():
		release_pitch = float(seen[0]["pitch"])
	check(release_pitch > 1.1 and release_pitch < 1.3
			and String(seen[0]["treatment"]) == "resolve"
			and String(seen[0]["bus"]) == "EchoSFX",
		"echo_release resolves from ~1.2 on the EchoSFX bus (%s)" % str(seen))
	seen.clear()
	SfxPlayer.play_id(&"plate")
	check(not seen.is_empty() and String(seen[0]["bus"]) == "SFX"
			and String(seen[0]["treatment"]) == "",
		"plain sounds bypass the echo treatment (%s)" % str(seen))

	# (5) The pool: bounded voices, and the bus consumer fires for a bare
	# SoundEvents emission (the wiring gameplay actually uses).
	check(SfxPlayer.get_child_count() >= SfxPlayer.POOL_SIZE,
		"the pool holds at least %d voices (got %d)" % [
			SfxPlayer.POOL_SIZE, SfxPlayer.get_child_count()])
	seen.clear()
	SoundEvents.emit_sfx(&"spike", Vector2(120.0, 60.0))
	check(seen.size() == 1 and String(seen[0]["id"]) == "spike",
		"a bare SoundEvents emission reaches the player (got %s)" % str(seen))

	# (6) Unknown ids refuse safely: no request, no crash.
	seen.clear()
	check(not SfxPlayer.play_id(&"not_a_sound"),
		"an unknown id is refused")
	check(seen.is_empty(),
		"an unknown id requests no playback")

	# (7) Master volume + mute drive bus 0 (what the pause menu shows).
	var db0_before := AudioServer.get_bus_volume_db(0)
	SfxPlayer.set_volume_step(1)
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.75)),
		"volume step 1 sets the master bus to 75%% (%.2f dB)" % AudioServer.get_bus_volume_db(0))
	check(SfxPlayer.volume_percent() == 75,
		"the pause-menu volume label reads 75")
	SfxPlayer.set_volume_step(0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), db0_before),
		"volume step 0 restores the master bus")
	SfxPlayer.toggle_mute()
	check(SfxPlayer.is_muted() and AudioServer.is_bus_mute(0),
		"mute toggles the master bus")
	SfxPlayer.toggle_mute()
	check(not SfxPlayer.is_muted() and not AudioServer.is_bus_mute(0),
		"unmuting restores the master bus")

	SfxPlayer.sfx_play_requested.disconnect(on_play)


# --- Plan 8 gate 5: the level completability smoke --------------------------
#
# "Scripted input plays the shipped level to its exit event headless."
# The script below is exactly what a player's hands do, segment by segment:
# run off the start floor, land on the ground floor, run up to the pit and
# jump it, stop, edge-safe-walk into the grab window, Shift+Up to hang,
# Shift+Up to climb onto the ledge, then hold right — pressing the plate,
# waiting out the §9 gate schedule pinned against it — and walk into the
# open exit door. It runs through the REAL scene (GameManager.load_level →
# SimWorld → SimPlayer), so exit_reached → complete_level is exercised
# end to end, not called directly.
#
# What this gate proves: the level is FINISHABLE by a human today. What it
# deliberately does not prove: that it is fun, fair or readable — **not
# verified, needs human playtest** (D14's acceptance half).

func _test_b0_completability() -> void:
	GameManager.load_level(0)
	check(GameManager.state == GameManager.State.PLAYING and GameManager.player is SimPlayer,
		"gate 5 loads sim level 1 through the real scene (state %s)" % str(GameManager.state))
	if not (GameManager.player is SimPlayer):
		GameManager.return_to_menu()
		return
	var world: SimWorld = (GameManager.player as SimPlayer).world

	var events: Array = []
	var checkpoints: Array = []
	var completed := [false]
	var on_ent := func(kind: StringName, key: String) -> void:
		events.append("%s:%s" % [String(kind), key])
	var on_cp := func(id: StringName) -> void: checkpoints.append(String(id))
	var on_done := func(_id: StringName) -> void: completed[0] = true
	EventBus.sim_entity_event.connect(on_ent)
	EventBus.checkpoint_reached.connect(on_cp)
	EventBus.level_completed.connect(on_done)

	var right := PopInput.make(1, 0)
	var neutral := PopInput.neutral()
	var jump := PopInput.make(1, -1)     # fwd+Up: the jump the player holds
	var edge_walk := PopInput.make(1, 0, 1)  # Shift+fwd: slow, edge-safe walk
	var grab := PopInput.make(0, -1, 1)  # Shift+Up: hang, then climb

	# (1) Run off the start floor and land on the ground floor (1-row, soft).
	var g := 0
	while int(world.state["row"]) != 1 and int(world.state["dead"]) == 0 and g < 90:
		world.step_with(right)
		g += 1
	check(int(world.state["row"]) == 1 and int(world.state["dead"]) == 0,
		"gate 5 the kid drops to the ground floor alive (row %d dead %d x %d, %d ticks)" % [
			int(world.state["row"]), int(world.state["dead"]), int(world.state["x"]), g])

	# (2) Land the drop (step_fall → soft_land → stand_up) and reach a
	# launchable run state on the ground floor. The take-off window for the
	# col-10 pit (mouth x 198, far lip 212) is x ∈ [150, 178]: run_jump's
	# ground roll-in f34-38 covers +19 (must stay below the mouth) and the
	# airborne arc lands at f44 (+62, must reach past 212). startrun enters
	# at x 167 — inside the window — so the loop exits there, BEFORE x
	# reaches 181 (where run_cycle begins and the window has closed).
	var g2 := 0
	while int(world.state["dead"]) == 0 and g2 < 60 and not (
			int(world.state["row"]) == 1
			and (String(world.state["seq"]) == "startrun" or String(world.state["seq"]) == "run_cycle")
			and int(world.state["x"]) >= 150 and int(world.state["x"]) <= 178):
		world.step_with(right)
		g2 += 1
	var takeoff := int(world.state["x"])

	# (3) fwd+Up from the run-up starts run_jump: roll in on the ground,
	# arc the pit, land past the far lip. Held input is swallowed by the
	# locked sequence, so keep holding through launch and flight.
	var g3 := 0
	while String(world.state["seq"]) != "run_jump" and int(world.state["dead"]) == 0 and g3 < 8:
		world.step_with(jump)
		g3 += 1
	while String(world.state["seq"]) == "run_jump" and int(world.state["dead"]) == 0 and g3 < 40:
		world.step_with(jump)
		g3 += 1
	check(int(world.state["row"]) == 1 and int(world.state["dead"]) == 0 and int(world.state["x"]) > 198,
		"gate 5 the jump clears the spike pit (takeoff %d -> x %d, row %d dead %d)" % [
			takeoff, int(world.state["x"]), int(world.state["row"]), int(world.state["dead"])])

	# (4) Stop, then edge-safe-walk into the grab window (det_col = lip-1:
	# x ∈ 250..263 makes the check_jump_up probe see the ledge lip col 14).
	var g4 := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and g4 < 30:
		world.step_with(neutral)
		g4 += 1
	var g5 := 0
	while int(world.state["x"]) < 250 and int(world.state["row"]) == 1 \
			and int(world.state["dead"]) == 0 and g5 < 40:
		world.step_with(edge_walk)
		g5 += 1
	var g5b := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and g5b < 15:
		world.step_with(neutral)
		g5b += 1
	check(String(world.state["seq"]) == "stand" and int(world.state["row"]) == 1
			and int(world.state["x"]) >= 250 and int(world.state["x"]) <= 263,
		"gate 5 the kid stands in the grab window (x %d row %d seq %s)" % [
			int(world.state["x"]), int(world.state["row"]), String(world.state["seq"])])

	# (5) Shift+Up: grab the ledge lip and hang.
	var g6 := 0
	while String(world.state["seq"]) != "hang" and int(world.state["dead"]) == 0 and g6 < 30:
		world.step_with(grab)
		g6 += 1
	check(String(world.state["seq"]) == "hang",
		"gate 5 Shift+Up grabs the ledge (seq %s after %d ticks)" % [
			String(world.state["seq"]), g6])

	# (6) Keep Shift+Up: climb onto the ledge.
	var g7 := 0
	while String(world.state["seq"]) != "stand" and int(world.state["dead"]) == 0 and g7 < 40:
		world.step_with(grab)
		g7 += 1
	var stand_col := PopSim._col_of(PopSim._foot_x(world.state))
	check(String(world.state["seq"]) == "stand" and int(world.state["row"]) == 0
			and PopSim._is_floor(PopSim._tile(world.state, 0, stand_col)),
		"gate 5 the climb-out stands on the ledge (seq %s row %d col %d)" % [
			String(world.state["seq"]), int(world.state["row"]), stand_col])

	# (7) Hold right: cross the plate, get pinned on the closed gate, watch it
	# run the §9 schedule, walk through, and step into the open exit door.
	# The loop ends when the SCENE completes the level (exit_reached →
	# GameManager.complete_level) — the end-to-end flow, never called here.
	var g8 := 0
	while GameManager.state == GameManager.State.PLAYING and int(world.state["dead"]) == 0 and g8 < 300:
		world.step_with(right)
		g8 += 1

	EventBus.sim_entity_event.disconnect(on_ent)
	EventBus.checkpoint_reached.disconnect(on_cp)
	EventBus.level_completed.disconnect(on_done)

	check(events.has("press:0,16"),
		"gate 5 crossing the ledge presses the plate (got %s)" % str(events))
	check(events.has("open:0,19"),
		"gate 5 the linked gate parks open while the kid waits (got %s)" % str(events))
	check(checkpoints.has("ground") and checkpoints.has("ledge"),
		"gate 5 both position triggers fire on the way (got %s)" % str(checkpoints))
	check(int(world.state["dead"]) == 0 and int(world.state["hp"]) == PopTables.KID_HP_START,
		"gate 5 the run takes no damage (dead %d hp %d)" % [
			int(world.state["dead"]), int(world.state["hp"])])
	check(completed[0] and GameManager.state == GameManager.State.LEVEL_COMPLETE,
		"gate 5 walking into the exit door completes the level end to end (completed %s, state %s, x %d, %d ticks)" % [
			str(completed[0]), str(GameManager.state), int(world.state["x"]), g8])

	GameManager.return_to_menu()
	check(GameManager.state == GameManager.State.MENU,
		"gate 5 teardown returns to the menu (state %s)" % str(GameManager.state))
	# FINISHABLE ≠ FUN: this smoke proves the level can be completed by a
	# human today; feel, fairness and readability are **not verified, needs
	# human playtest** (D14 acceptance half, hand-off checklist).


# --- Session 011 step 2: view tests (presentation only — NOT parity) --------
#
# These pin the RENDERING contract the screenshot review asked for: ONE
# world-to-screen mapping with separate x/y scales, an object in row r drawn
# within row r and above the floor line, and the prince sized as a documented
# fraction of a row. They assert geometry only — no sim behavior, no PARITY
# value — and the completability smoke above/below proves the sim did not
# change. Every message is prefixed "VIEW:" for that reason.
func _test_view_mapping() -> void:
	# (1) Tile cell aspect: 14x63 sim units at the cited 32 px : 63 px display
	# ratio (`types.h:1405`/`types.h:1408`, PARITY §2) -> h/w = 63/32 =
	# 1.96875 (~2:1 as measured from the original), never the old isotropic
	# ×3's 189/42 = 4.5:1.
	var cell := SimLevelView.tile_rect(2, 1)
	check(is_equal_approx(cell.size.x, 14.0 * SimWorld.PX_PER_UNIT),
		"VIEW: tile cell width = 14 units at the x scale (got %f)" % cell.size.x)
	check(is_equal_approx(cell.size.y, 63.0 * SimWorld.PX_PER_UNIT_Y),
		"VIEW: tile cell height = 63 units at the y scale (got %f)" % cell.size.y)
	check(absf(cell.size.y / cell.size.x - 63.0 / 32.0) < 0.001,
		"VIEW: cell aspect = the cited 63/32 (~2:1), got %.3f:1" % (cell.size.y / cell.size.x))

	# (2) The ground block sits directly BELOW row r's feet line: its top edge
	# is floor_y(r) = Y_LAND[r+1] (PARITY §2) — tiles stand on nothing above
	# that line, so the kid never draws buried in the floor.
	for r: int in 3:
		var t := SimLevelView.tile_rect(0, r)
		check(is_equal_approx(t.position.y,
				float(PopTables.Y_LAND[r + 1]) * SimWorld.PX_PER_UNIT_Y),
			"VIEW: tile row %d's block starts at the floor line Y_LAND[%d] (got %f)" % [
				r, r + 1, t.position.y])

	# (3) An object in row r is drawn WITHIN row r's walkable cell and ABOVE
	# the floor line: bottom edge ON the line, top edge one row up. This is
	# the fix for the screenshot's "one row too low" — view, not level data.
	for r: int in 3:
		var o := SimLevelView.object_rect(3, r)
		var floor_px := float(PopTables.Y_LAND[r + 1]) * SimWorld.PX_PER_UNIT_Y
		var top_px := float(PopTables.Y_LAND[r]) * SimWorld.PX_PER_UNIT_Y
		check(is_equal_approx(o.end.y, floor_px),
			"VIEW: row %d object's bottom edge stands ON the floor line (got %f, want %f)" % [
				r, o.end.y, floor_px])
		check(is_equal_approx(o.position.y, top_px) and o.position.y < floor_px,
			"VIEW: row %d object fills the space above the floor line inside its row (top %f)" % [
				r, o.position.y])
	# The plate is a lip ON that line, never sunk into the floor block.
	var p := SimLevelView.plate_rect(5, 1)
	check(is_equal_approx(p.end.y, float(PopTables.Y_LAND[2]) * SimWorld.PX_PER_UNIT_Y)
			and p.size.y <= 0.25 * 63.0 * SimWorld.PX_PER_UNIT_Y,
		"VIEW: plate lip sits on the floor line and is under a quarter-row tall (%f px)" % p.size.y)
	# The gate slab hangs from the cell top: closed fills the cell standing on
	# the line, half-open has risen off it, fully open clears the walkway
	# (visual counterpart of PARITY §9's mod schedule — geometry only here).
	var g_closed := SimLevelView.gate_slab_rect(4, 0, 0.0)
	var g_half := SimLevelView.gate_slab_rect(4, 0, 0.5)
	var g_open := SimLevelView.gate_slab_rect(4, 0, 1.0)
	check(is_equal_approx(g_closed.end.y, float(PopTables.Y_LAND[1]) * SimWorld.PX_PER_UNIT_Y)
			and is_equal_approx(g_closed.position.y, float(PopTables.Y_LAND[0]) * SimWorld.PX_PER_UNIT_Y),
		"VIEW: a closed gate slab fills its row standing on the floor line")
	check(is_equal_approx(g_half.position.y, g_closed.position.y)
			and g_half.end.y < g_closed.end.y and g_half.end.y > g_closed.position.y,
		"VIEW: a half-open gate hangs from the cell top with its bottom risen off the floor")
	check(is_equal_approx(g_open.size.y, 0.0),
		"VIEW: a fully open gate leaves the walkway clear")

	# (4) The prince: height as a documented fraction of a row (0.79 = 50/63
	# sim units — the reference prince fills most of a row; placeholder
	# proportions, NOT parity evidence), width from the sim's kid x-footprint
	# (10 units, matching the grab probe / edge nudges), bottom edge on the
	# sim's foot point so he stands on the floor line, not in it.
	var prince := SimPlayer.prince_rect_local()
	var row_px := 63.0 * SimWorld.PX_PER_UNIT_Y
	var frac := prince.size.y / row_px
	check(frac >= 0.7 and frac <= 0.9,
		"VIEW: prince height is a documented fraction of a row (0.70..0.90, got %.2f)" % frac)
	check(is_equal_approx(prince.size.x, 10.0 * SimWorld.PX_PER_UNIT),
		"VIEW: prince width = 10 sim units at the x scale (got %f)" % prince.size.x)
	check(is_equal_approx(prince.end.y, 0.0) and prince.position.y < 0.0,
		"VIEW: the prince rect hangs upward from the sim's foot point (bottom edge = foot y)")
