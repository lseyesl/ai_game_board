extends RefCounted

const WaveSpawnerScript = preload("res://scripts/waves/wave_spawner.gd")
const WaveZoneScript = preload("res://scripts/waves/wave_zone.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	var spawner = WaveSpawnerScript.new()
	spawner.spawn_distance_ahead = 100.0
	spawner.min_spacing = 14.0
	spawner.max_spacing = 22.0
	spawner.lane_width = 12.0

	if not spawner.has_method("acquire_wave"):
		failures.append("wave spawner should expose acquire_wave for pool reuse")
	if not spawner.has_method("release_wave_to_pool"):
		failures.append("wave spawner should expose release_wave_to_pool for pool reuse")
	if not spawner.has_method("get_inactive_pool_size"):
		failures.append("wave spawner should expose get_inactive_pool_size so pool reuse can be verified")

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		failures.append("wave spawner pool test requires the live SceneTree from the test harness")
		return failures

	var parent = Node3D.new()
	parent.position = Vector3.ZERO
	scene_tree.root.add_child(parent)
	parent.add_child(spawner)

	var ship = Node3D.new()
	ship.position = Vector3.ZERO
	parent.add_child(ship)
	spawner.ship = ship

	# Test: acquire creates a new wave when pool is empty
	var wave_a := spawner.acquire_wave()
	if wave_a == null:
		failures.append("acquire_wave should return a wave zone when the pool is empty")
	else:
		if wave_a.spawner != spawner:
			failures.append("acquired waves should reference their spawner")
		if spawner.get_inactive_pool_size() != 0:
			failures.append("acquiring a new wave should not change the inactive pool size")

	# Test: release moves wave into pool
	spawner.add_child(wave_a)
	spawner.release_wave_to_pool(wave_a)
	if spawner.get_inactive_pool_size() != 1:
		failures.append("released waves should move into the inactive pool instead of being discarded")

	# Test: acquire reuses pooled wave
	var wave_b := spawner.acquire_wave()
	if wave_b != wave_a:
		failures.append("spawner should reuse a pooled wave before instantiating a new one")
	if spawner.get_inactive_pool_size() != 0:
		failures.append("acquiring a pooled wave should remove it from the inactive pool")

	# Test: double release does not duplicate
	spawner.add_child(wave_b)
	spawner.release_wave_to_pool(wave_b)
	spawner.release_wave_to_pool(wave_b)
	if spawner.get_inactive_pool_size() != 1:
		failures.append("releasing the same wave twice should not duplicate it in the inactive pool")

	# Test: reset_for_spawn resets consumed and configures profile
	var wave_c := spawner.acquire_wave()
	var profile = WaveProfileScript.large(0.8)
	profile.lift_force = 5.0
	profile.damage_risk = 7.0
	wave_c.reset_for_spawn(Vector3(3.0, 0.0, -20.0), profile)
	if wave_c.consumed:
		failures.append("reset_for_spawn should reset consumed to false")
	if not is_equal_approx(wave_c.turn_push, profile.turn_push):
		failures.append("reset_for_spawn should configure turn_push from profile")
	if not is_equal_approx(wave_c.lift_force, profile.lift_force):
		failures.append("reset_for_spawn should configure lift_force from profile")
	if not is_equal_approx(wave_c.damage_risk, profile.damage_risk):
		failures.append("reset_for_spawn should configure damage_risk from profile")
	if wave_c.is_large != profile.is_large:
		failures.append("reset_for_spawn should configure is_large from profile")

	# Test: cleanup-driven reuse during _process
	# Ship faces -Z (default), so "behind" = positive Z direction.
	# Place a wave at z=+64 which is well behind the ship (cleanup_distance_behind=25).
	var cleanup_spawner = WaveSpawnerScript.new()
	cleanup_spawner.spawn_distance_ahead = 100.0
	cleanup_spawner.cleanup_distance_behind = 25.0
	cleanup_spawner.min_spacing = 14.0
	cleanup_spawner.max_spacing = 22.0
	cleanup_spawner.lane_width = 12.0
	cleanup_spawner.large_wave_chance = 0.0
	parent.add_child(cleanup_spawner)

	var cleanup_ship = Node3D.new()
	cleanup_ship.position = Vector3.ZERO
	# Ensure ship faces -Z (default forward), so +Z is behind
	cleanup_ship.rotation = Vector3.ZERO
	parent.add_child(cleanup_ship)
	cleanup_spawner.ship = cleanup_ship

	var pooled_wave := cleanup_spawner.acquire_wave()
	# Place wave at +Z = behind ship, beyond cleanup distance
	pooled_wave.position = Vector3(0.0, 0.0, 64.0)
	pooled_wave.configure(WaveProfileScript.small(0.5))
	pooled_wave.consumed = false
	cleanup_spawner.add_child(pooled_wave)

	seed(4242)
	cleanup_spawner._process(0.0)
	# Wave at z=+64 is behind the ship (forward dot offset > cleanup_distance_behind),
	# so it should be released to pool then reused for one of the new spawns.
	if not cleanup_spawner.get_children().has(pooled_wave):
		failures.append("spawner should reuse a cleaned-up wave when replacing far waves during process")

	# Test: direction-aware spawn — waves should appear ahead of the ship along its forward direction
	var dir_spawner = WaveSpawnerScript.new()
	dir_spawner.spawn_distance_ahead = 60.0
	dir_spawner.cleanup_distance_behind = 25.0
	dir_spawner.min_spacing = 18.0
	dir_spawner.max_spacing = 20.0
	dir_spawner.lane_width = 6.0
	dir_spawner.large_wave_chance = 0.0
	parent.add_child(dir_spawner)

	var dir_ship = Node3D.new()
	# Rotate ship 90 degrees so it faces -X instead of -Z
	dir_ship.position = Vector3.ZERO
	dir_ship.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	parent.add_child(dir_ship)
	dir_spawner.ship = dir_ship

	seed(7777)
	dir_spawner._process(0.0)

	var spawned_children := dir_spawner.get_children()
	if spawned_children.is_empty():
		failures.append("direction-aware spawner should spawn waves when ship faces -X")
	else:
		var all_ahead := true
		var forward := dir_spawner._ship_forward()
		for child in spawned_children:
			var offset: Vector3 = child.global_position - dir_ship.global_position
			var forward_dist: float = offset.dot(forward)
			# Waves ahead of the ship have positive forward_dist (along forward direction)
			if forward_dist < 0.0:
				all_ahead = false
		if not all_ahead:
			failures.append("spawned waves should appear ahead of the ship along its forward direction, not behind it")

	# Test: deactivate_to_pool disables monitoring
	var wave_d := spawner.acquire_wave()
	wave_d.deactivate_to_pool()
	if not wave_d.consumed:
		failures.append("deactivate_to_pool should set consumed to true")
	if wave_d.monitoring:
		failures.append("deactivate_to_pool should disable monitoring")

	# Test: drift_velocity is applied during _process
	var drift_wave := spawner.acquire_wave()
	var drift_profile = WaveProfileScript.small(0.5)
	drift_profile.drift_speed = 2.0
	drift_wave.reset_for_spawn(Vector3.ZERO, drift_profile)
	drift_wave.configure_drift(Vector3(1.0, 0.0, 0.0) * drift_profile.drift_speed)
	spawner.add_child(drift_wave)

	var pos_before := drift_wave.position.x
	drift_wave._process(1.0)
	if drift_wave.position.x <= pos_before:
		failures.append("wave should move laterally when drift_velocity is set and _process is called")

	# Test: deactivate_to_pool zeroes drift_velocity and stops processing
	drift_wave.deactivate_to_pool()
	if drift_wave.drift_velocity != Vector3.ZERO:
		failures.append("deactivate_to_pool should zero drift_velocity")
	if drift_wave.is_processing():
		failures.append("deactivate_to_pool should stop processing")

	parent.queue_free()

	return failures
