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
	check(_int_array_equal(_ints(_parity_cell(md, "2", "Floor y per row")), PopTables.Y_LAND),
		"Y_LAND matches PARITY §2")
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

	check(_int_array_equal(_ints(_parity_cell(md, "2", "Non-floor tiles")), PopTables.NON_FLOOR_TILES),
		"NON_FLOOR_TILES matches PARITY §2")
	nums = _ints(_parity_row(md, "8", "extend")[3] if _parity_row(md, "8", "extend").size() > 3 else "")
	check(nums.size() >= 2 and nums[1] == PopTables.SPIKE_EXTEND_MAX,
		"SPIKE_EXTEND_MAX matches PARITY §8 extend row")

	# pop_sim's measured replacements must equal the table values they cite.
	check(PopSim.TURN_TICKS == PopTables.TURN_TICKS, "pop_sim TURN_TICKS uses PopTables.TURN_TICKS")
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


func _test_a22_acceptance() -> void:
	var md := FileAccess.get_file_as_string("res://docs/PARITY.md")
	check(md.length() > 0, "docs/PARITY.md is readable for the A2.2 cross-checks")
	if md.is_empty():
		return
	var level := _flat_level()

	# --- (a) determinism double-run hash equality ------------------------
	var script: Array = _fixed_input_script(400)
	var run1 := PopSim.run(777, script, level)
	var run2 := PopSim.run(777, script, level)
	check(PopSim.hash_state(run1) == PopSim.hash_state(run2),
		"double-run of the 400-tick script hashes equal (A2.2 determinism)")
	# Measurement, not a gate: where does the script leave him on a flat floor?
	print("  MEAS 400-tick flat-floor run ends: x=%d hp=%d dead=%d row=%d seq=%s" % [
		int(run1["x"]), int(run1["hp"]), int(run1["dead"]),
		int(run1["row"]), String(run1["seq"])])

	# --- (b1) standing jump: 1-tile gap, cross-checked vs PARITY §4 -----
	var st: Dictionary = PopSim.initial_state(4242, level)
	var x0 := int(st["x"])
	var land_dx := -1
	var total_dx := -1
	var t := 0
	while t < 60:
		st = PopSim.step(st, PopInput.make(0, -1))  # hold jump from stand
		t += 1
		if int(st["frame"]) == 27 and land_dx < 0:  # landing frame, PARITY §4
			land_dx = int(st["x"]) - x0
		if String(st["seq"]) == "stand":
			total_dx = int(st["x"]) - x0
			break
	check(String(st["seq"]) == "stand" and total_dx >= 0,
		"standing jump plays out and returns to stand in %d ticks" % t)
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

	# --- (b2) run jump: 2-tile gap, cross-checked vs PARITY §5 -----------
	st = PopSim.initial_state(5150, level)
	var start_x := int(st["x"])
	t = 0
	while t < 40 and String(st["seq"]) != "run_cycle":
		st = PopSim.step(st, PopInput.make(1))
		t += 1
	check(String(st["seq"]) == "run_cycle" and int(st["x"]) > start_x,
		"the kid runs forward and reaches the run cycle (x %d → %d in %d ticks)" % [start_x, int(st["x"]), t])
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
		"run jump lands and rejoins the run cycle (x back at +%d)" % back_dx)
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
				"fall 1 row lands soft: impact %d < %d, no HP lost (hp %d, y %d)" % [
					impact, PopTables.SOFT_LAND_MAX, int(fs["hp"]), int(fs["y"])])
		elif landing_row == 2:
			check(String(fs["seq"]) == "med_land"
				and int(fs["hp"]) == PopTables.KID_HP_START - 1
				and int(fs["dead"]) == 0,
				"fall 2 rows costs exactly 1 HP: impact %d in [%d,%d), hp %d → %d" % [
					impact, PopTables.MEDIUM_LAND_MIN, PopTables.MEDIUM_LAND_MAX,
					PopTables.KID_HP_START, int(fs["hp"])])
		else:
			# y distinguishes a real touchdown on the row-3 floor (y_land 244,
			# hard_land's opening dy −2 → 242) from an off-bottom fell_out
			# (`seg006.c:1321-1326`), which otherwise looks identical.
			check(int(fs["dead"]) == 1 and int(fs["hp"]) == 0
				and String(fs["seq"]) == "hard_land"
				and int(fs["y"]) == int(PopTables.Y_LAND[4]) - 2,
				"fall 3 rows kills: impact %d >= %d, hp 0, on row 3 (y %d, seq %s)" % [
					impact, PopTables.DEATH_SPEED, int(fs["y"]), String(fs["seq"])])

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
		"spike contact plays impale frame 177 (seq %s, frame %d)" % [String(ss["seq"]), int(ss["frame"])])
	check(int(ss["y"]) == int(PopTables.Y_LAND[1]),
		"impale snaps y to the row floor (y %d == y_land %d)" % [int(ss["y"]), int(PopTables.Y_LAND[1])])
	check(int((ss["mods"] as Dictionary).get("0,3", 0)) == 0xFF,
		"the spiked tile is disabled to 0xFF (got 0x%02X)" % int((ss["mods"] as Dictionary).get("0,3", 0)))
	check(int(smods["0,3"]) == 2,
		"the caller's mods dict is untouched — a run cannot leak state")
	# Control: retracted spikes (mod 0xFF reads back as class 0) must let the
	# same kid run past the same tile alive.
	var hs: Dictionary = PopSim.initial_state(7, slevel, {"0,3": 0xFF})
	ht = 0
	while ht < 60 and int(hs["x"]) <= 124 and int(hs["dead"]) == 0:
		hs = PopSim.step(hs, PopInput.make(1))
		ht += 1
	check(int(hs["dead"]) == 0 and int(hs["hp"]) == PopTables.KID_HP_START and int(hs["x"]) > 124,
		"retracted spikes (0xFF) let the kid run past safely (x %d, hp %d)" % [int(hs["x"]), int(hs["hp"])])

	# --- floor-edge snap on landing (seg005.c:128-132) -------------------
	# Case 1: no floor within 3 units ahead of the foot → pulled back 3
	# (then soft_land's opening dx +1 moves him again — the net is −3).
	var elevel := _flat_level()
	elevel[1][6] = PopTables.Tile.EMPTY
	var snapped := _crafted_landing(elevel, 141)  # foot 139 → 2 units from edge
	check(int(snapped["x"]) == 141 - 3 + 1,
		"edge landing with no floor ahead pulls back 3 units (x 141 → %d)" % int(snapped["x"]))
	check(int(snapped["y"]) == int(PopTables.Y_LAND[2]) and String(snapped["seq"]) == "soft_land",
		"landing snaps y to y_land and plays soft land (y %d, seq %s)" % [int(snapped["y"]), String(snapped["seq"])])
	# Case 2: same hole, but 6 units from the edge → no pull-back.
	var loose := _crafted_landing(elevel, 137)
	check(int(loose["x"]) == 137 + 1,
		"a landing 6 units from the edge is not pulled back (x 137 → %d)" % int(loose["x"]))
	# Case 3: floor continues past the edge → the second operand fails, no pull-back.
	var guarded := _crafted_landing(level, 141)
	check(int(guarded["x"]) == 141 + 1,
		"floor continuing past the edge disables the pull-back (x 141 → %d)" % int(guarded["x"]))
