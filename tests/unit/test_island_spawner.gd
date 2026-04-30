extends RefCounted

const IslandSpawnerScript = preload("res://scripts/islands/island_spawner.gd")


class TestLifecycleIsland:
	extends Island

	var deactivate_call_count := 0
	var reset_call_count := 0
	var last_reset_position := Vector3.INF
	var last_reset_repair_rate := -1.0

	func deactivate_to_pool() -> void:
		deactivate_call_count += 1

	func reset_for_spawn(spawn_position: Vector3, next_repair_rate: float = repair_rate) -> void:
		reset_call_count += 1
		last_reset_position = spawn_position
		last_reset_repair_rate = next_repair_rate
		position = spawn_position
		repair_rate = next_repair_rate
		is_preview = false
		reveal_ratio = 1.0


class TestRevealIsland:
	extends Area3D

	var preview_history: Array[bool] = []
	var reveal_history: Array[Array] = []
	var is_preview: bool = false

	func set_preview_state(value: bool) -> void:
		is_preview = value
		preview_history.append(value)

	func update_reveal_from_distance(distance: float, reveal_distance: float) -> void:
		reveal_history.append([distance, reveal_distance])


func run() -> Array[String]:
	var failures: Array[String] = []
	var spawner = IslandSpawnerScript.new()
	spawner.spawn_outer_half_width = 28.0
	spawner.spawn_outer_half_depth = 42.0
	spawner.spawn_inner_half_width = 10.0
	spawner.spawn_inner_half_depth = 16.0
	spawner.preview_visible_distance = 0.0
	spawner.minimum_island_spacing = 12.0
	spawner.spawn_retry_limit = 24

	seed(12345)

	var saw_front_left := false
	var saw_front_center := false
	var saw_front_right := false

	for _index in range(240):
		var offset: Vector3 = spawner.generate_spawn_offset()
		if absf(offset.x) > spawner.spawn_outer_half_width:
			failures.append("generated island offsets should stay within the configured lateral spawn width")
			break
		if offset.z < -spawner.spawn_outer_half_depth:
			failures.append("generated island offsets should stay within the configured forward spawn depth")
			break
		if offset.z > -spawner.spawn_inner_half_depth:
			failures.append("island spawner should not place islands in the excluded near or behind zone")
			break
		if offset.x <= -spawner.spawn_inner_half_width:
			saw_front_left = true
		elif offset.x >= spawner.spawn_inner_half_width:
			saw_front_right = true
		else:
			saw_front_center = true

	if not saw_front_left:
		failures.append("island spawner should place islands in the front-left spawn region")
	if not saw_front_center:
		failures.append("island spawner should place islands in the front-center spawn region")
	if not saw_front_right:
		failures.append("island spawner should place islands in the front-right spawn region")

	seed(24680)
	var spaced_spawn_position = spawner.generate_validated_spawn_position(
		Vector3.ZERO,
		[Vector3.ZERO]
	)
	if spaced_spawn_position == null:
		failures.append("island spawner should find a spawn point that satisfies the minimum island spacing when room exists")
	else:
		var spaced_spawn_offset: Vector3 = spaced_spawn_position - Vector3.ZERO
		if absf(spaced_spawn_offset.x) > spawner.spawn_outer_half_width:
			failures.append("validated island spawns should stay within the configured lateral spawn width")
		if spaced_spawn_offset.z < -spawner.spawn_outer_half_depth:
			failures.append("validated island spawns should stay within the configured forward spawn depth")
		if spaced_spawn_offset.z > -spawner.spawn_inner_half_depth:
			failures.append("validated island spawns should stay outside the excluded near and behind zone")
		if spaced_spawn_position.distance_to(Vector3.ZERO) < spawner.minimum_island_spacing:
			failures.append("validated island spawns should keep at least the configured minimum spacing from existing islands")

	if spawner.is_in_spawn_band(Vector3(0.0, 0.0, -15.0)):
		failures.append("spawn band should reject offsets inside the excluded near-forward zone")
	if spawner.is_in_spawn_band(Vector3(0.0, 0.0, 1.0)):
		failures.append("spawn band should reject offsets behind the boat")
	if not spawner.is_in_spawn_band(Vector3(0.0, 0.0, -16.0)):
		failures.append("spawn band should include offsets on the forward inner boundary")
	if not spawner.is_in_spawn_band(Vector3(0.0, 0.0, 16.0), Vector3.BACK):
		failures.append("spawn band should include forward offsets after a 180-degree turn")
	var right_side_spawn_offset := Vector3.LEFT * 20.0 + Vector3.FORWARD * 12.0
	if not spawner.is_in_spawn_band(right_side_spawn_offset, Vector3.LEFT):
		failures.append("spawn band should project rotated offsets into the ship-relative right-side spawn region")

	spawner.minimum_island_spacing = 1000.0
	spawner.spawn_retry_limit = 3
	seed(13579)
	var blocked_spawn_position = spawner.generate_validated_spawn_position(
		Vector3.ZERO,
		[Vector3.ZERO]
	)
	if blocked_spawn_position != null:
		failures.append("island spawner should return null after the retry limit when no spawn point satisfies spacing")

	var saw_farther_forward_spawn := false
	var reported_preview_width_overflow := false
	spawner.preview_visible_distance = 64.0
	spawner.minimum_island_spacing = 0.0
	spawner.spawn_retry_limit = 24
	seed(97531)
	for _extended_index in range(240):
		var extended_offset: Vector3 = spawner.generate_spawn_offset()
		if absf(extended_offset.x) > spawner.spawn_outer_half_width and not reported_preview_width_overflow:
			failures.append("preview-distance island offsets should keep the configured lateral spawn width")
			reported_preview_width_overflow = true
		if extended_offset.z < -spawner.preview_visible_distance:
			failures.append("preview-distance island offsets should stay within the expanded forward depth")
		if extended_offset.z > -spawner.spawn_inner_half_depth:
			failures.append("preview-distance island offsets should stay outside the excluded near and behind zone")
		if extended_offset.z < -42.0:
			saw_farther_forward_spawn = true
	if not saw_farther_forward_spawn:
		failures.append("island spawner should generate farther preview islands beyond the old forward-only band")
	spawner.free()

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		failures.append("island spawner transform regression test requires the live SceneTree from the test harness")
		return failures
	var parent = Node3D.new()
	parent.position = Vector3(17.0, 0.0, 31.0)
	parent.rotation = Vector3(0.0, deg_to_rad(33.0), 0.0)
	scene_tree.root.add_child(parent)

	var transformed_spawner = IslandSpawnerScript.new()
	transformed_spawner.spawn_outer_half_width = 28.0
	transformed_spawner.spawn_outer_half_depth = 42.0
	transformed_spawner.spawn_inner_half_width = 10.0
	transformed_spawner.spawn_inner_half_depth = 16.0
	transformed_spawner.minimum_island_spacing = 0.0
	transformed_spawner.spawn_retry_limit = 1
	transformed_spawner.position = Vector3(53.0, 0.0, -29.0)
	transformed_spawner.rotation = Vector3(0.0, deg_to_rad(-21.0), 0.0)
	parent.add_child(transformed_spawner)

	var ship = Node3D.new()
	ship.position = Vector3(7.0, 0.0, 11.0)
	parent.add_child(ship)
	transformed_spawner.ship = ship

	seed(424242)
	var expected_world_spawn_position = transformed_spawner.generate_validated_spawn_position(ship.global_position, [], -ship.global_transform.basis.z)
	seed(424242)
	transformed_spawner._spawn_next_island()

	var spawned_island = transformed_spawner.get_child(0)
	if spawned_island.global_position.distance_to(expected_world_spawn_position) > 0.001:
		failures.append("spawned islands should use the validated world-space spawn position even when the spawner has a parent transform")

	var turn_parent = Node3D.new()
	scene_tree.root.add_child(turn_parent)

	var turned_spawner = IslandSpawnerScript.new()
	turned_spawner.spawn_outer_half_width = 28.0
	turned_spawner.spawn_outer_half_depth = 42.0
	turned_spawner.spawn_inner_half_width = 10.0
	turned_spawner.spawn_inner_half_depth = 16.0
	turned_spawner.preview_visible_distance = 0.0
	turned_spawner.minimum_island_spacing = 0.0
	turned_spawner.spawn_retry_limit = 1
	turn_parent.add_child(turned_spawner)

	var turned_ship = Node3D.new()
	turned_ship.position = Vector3.ZERO
	turned_ship.rotation = Vector3(0.0, PI, 0.0)
	turn_parent.add_child(turned_ship)
	turned_spawner.ship = turned_ship

	seed(123456)
	if not turned_spawner._spawn_next_island():
		failures.append("island spawner should spawn an island after the ship turns 180 degrees")
	else:
		var turned_island = turned_spawner.get_child(0)
		var turned_offset: Vector3 = turned_island.global_position - turned_ship.global_position
		var turned_forward: Vector3 = -turned_ship.global_transform.basis.z.normalized()
		var turned_right: Vector3 = turned_forward.cross(Vector3.UP).normalized()
		var forward_distance := turned_offset.dot(turned_forward)
		var lateral_distance := absf(turned_offset.dot(turned_right))
		if forward_distance < turned_spawner.spawn_inner_half_depth or forward_distance > turned_spawner.spawn_outer_half_depth:
			failures.append("islands spawned after a 180-degree turn should stay in the ship-relative forward spawn band")
		if lateral_distance > turned_spawner.spawn_outer_half_width:
			failures.append("islands spawned after a 180-degree turn should stay within the ship-relative lateral spawn width")

	var reveal_spawner = IslandSpawnerScript.new()
	reveal_spawner.target_island_count = 0
	reveal_spawner.preview_visible_distance = 72.0
	reveal_spawner.active_distance = 24.0
	parent.add_child(reveal_spawner)

	if not reveal_spawner.has_method("release_island_to_pool"):
		failures.append("island spawner should expose release_island_to_pool for inactive island reuse")
	elif not reveal_spawner.has_method("acquire_island"):
		failures.append("island spawner should expose acquire_island for inactive island reuse")
	elif not reveal_spawner.has_method("get_inactive_pool_size"):
		failures.append("island spawner should expose get_inactive_pool_size so pool reuse can be verified")
	else:
		var pooled_island = reveal_spawner.acquire_island()
		reveal_spawner.add_child(pooled_island)
		reveal_spawner.release_island_to_pool(pooled_island)
		if reveal_spawner.get_inactive_pool_size() != 1:
			failures.append("released islands should move into the inactive pool instead of being discarded")
		var reused_island = reveal_spawner.acquire_island()
		if reused_island != pooled_island:
			failures.append("spawner should reuse a pooled island before instantiating a new one")
		if reveal_spawner.get_inactive_pool_size() != 0:
			failures.append("acquiring a pooled island should remove it from the inactive pool")
		reveal_spawner.release_island_to_pool(reused_island)
		reveal_spawner.release_island_to_pool(reused_island)
		if reveal_spawner.get_inactive_pool_size() != 1:
			failures.append("releasing the same island twice should not duplicate it in the inactive pool")

	var lifecycle_spawner = IslandSpawnerScript.new()
	lifecycle_spawner.target_island_count = 1
	lifecycle_spawner.spawn_retry_limit = 1
	lifecycle_spawner.spawn_outer_half_width = 28.0
	lifecycle_spawner.spawn_outer_half_depth = 42.0
	lifecycle_spawner.spawn_inner_half_width = 10.0
	lifecycle_spawner.spawn_inner_half_depth = 16.0
	parent.add_child(lifecycle_spawner)

	var lifecycle_ship = Node3D.new()
	lifecycle_ship.position = Vector3.ZERO
	parent.add_child(lifecycle_ship)
	lifecycle_spawner.ship = lifecycle_ship

	var lifecycle_island := TestLifecycleIsland.new()
	lifecycle_spawner.add_child(lifecycle_island)
	lifecycle_spawner.release_island_to_pool(lifecycle_island)
	if lifecycle_island.deactivate_call_count != 1:
		failures.append("release_island_to_pool should delegate island cleanup to deactivate_to_pool")
	if lifecycle_spawner.get_inactive_pool_size() != 1:
		failures.append("release_island_to_pool should still move the island into the inactive pool after deactivation")

	seed(11111)
	var expected_reused_spawn_position = lifecycle_spawner.generate_validated_spawn_position(lifecycle_ship.global_position, [], -lifecycle_ship.global_transform.basis.z)
	seed(11111)
	if not lifecycle_spawner._spawn_next_island():
		failures.append("pooled lifecycle integration test should be able to spawn a reused island")
	elif lifecycle_island.reset_call_count != 1:
		failures.append("_spawn_next_island should reset pooled islands through reset_for_spawn")
	else:
		if lifecycle_island.last_reset_position.distance_to(lifecycle_island.position) > 0.001:
			failures.append("reset_for_spawn should receive the local spawn position used for the reused island")
		if lifecycle_island.last_reset_position.distance_to(lifecycle_spawner.to_local(expected_reused_spawn_position)) > 0.001:
			failures.append("reset_for_spawn should receive the validated local spawn position for reused islands")
		if is_equal_approx(lifecycle_island.last_reset_repair_rate, -1.0):
			failures.append("reset_for_spawn should receive the new repair rate for reused islands")

	var cleanup_spawner = IslandSpawnerScript.new()
	cleanup_spawner.target_island_count = 1
	cleanup_spawner.cleanup_radius = 20.0
	cleanup_spawner.preview_visible_distance = 72.0
	cleanup_spawner.active_distance = 24.0
	cleanup_spawner.spawn_retry_limit = 1
	cleanup_spawner.spawn_outer_half_width = 28.0
	cleanup_spawner.spawn_outer_half_depth = 42.0
	cleanup_spawner.spawn_inner_half_width = 10.0
	cleanup_spawner.spawn_inner_half_depth = 16.0
	parent.add_child(cleanup_spawner)

	var cleanup_ship = Node3D.new()
	cleanup_ship.position = Vector3.ZERO
	parent.add_child(cleanup_ship)
	cleanup_spawner.ship = cleanup_ship

	var pooled_runtime_island = cleanup_spawner.acquire_island()
	pooled_runtime_island.position = Vector3(0.0, 0.0, 64.0)
	cleanup_spawner.add_child(pooled_runtime_island)

	seed(4242)
	cleanup_spawner._process(0.0)
	if cleanup_spawner.get_inactive_pool_size() != 0:
		failures.append("cleanup-driven reuse should consume the pooled island when spawning a replacement")
	elif cleanup_spawner.get_child_count() != 1:
		failures.append("cleanup-driven reuse should keep exactly one active island child")
	else:
		var reused_runtime_island = cleanup_spawner.get_child(0)
		if reused_runtime_island != pooled_runtime_island:
			failures.append("spawner should reuse a cleaned-up island when replacing far islands during process")

	var turning_cleanup_spawner = IslandSpawnerScript.new()
	turning_cleanup_spawner.target_island_count = 0
	turning_cleanup_spawner.cleanup_radius = 20.0
	parent.add_child(turning_cleanup_spawner)

	var turning_cleanup_ship = Node3D.new()
	turning_cleanup_ship.position = Vector3.ZERO
	turning_cleanup_ship.rotation = Vector3(0.0, PI, 0.0)
	parent.add_child(turning_cleanup_ship)
	turning_cleanup_spawner.ship = turning_cleanup_ship

	var nearby_passed_island = turning_cleanup_spawner.acquire_island()
	nearby_passed_island.position = Vector3(0.0, 0.0, -30.0)
	turning_cleanup_spawner.add_child(nearby_passed_island)

	turning_cleanup_spawner._process(0.0)
	if not turning_cleanup_spawner.get_children().has(nearby_passed_island):
		failures.append("nearby islands should survive cleanup during sharp turns after the ship passes them")
	if turning_cleanup_spawner.get_inactive_pool_size() != 0:
		failures.append("nearby islands should not be moved into the inactive pool during sharp turns")

	var reveal_ship = Node3D.new()
	reveal_ship.position = Vector3.ZERO
	parent.add_child(reveal_ship)
	reveal_spawner.ship = reveal_ship

	var far_island = TestRevealIsland.new()
	far_island.position = Vector3(48.0, 0.0, 0.0)
	reveal_spawner.add_child(far_island)

	var near_island = TestRevealIsland.new()
	near_island.position = Vector3(12.0, 0.0, 0.0)
	reveal_spawner.add_child(near_island)

	reveal_spawner._process(0.0)
	if not far_island.is_preview:
		failures.append("islands beyond the active distance should stay preview-only")
	if near_island.is_preview:
		failures.append("islands inside the active distance should become active")
	if far_island.reveal_history.is_empty():
		failures.append("spawner should update reveal values for far islands each process tick")
	if near_island.reveal_history.is_empty():
		failures.append("spawner should update reveal values for near islands each process tick")

	near_island.position = Vector3(42.0, 0.0, 0.0)
	reveal_spawner._process(0.0)
	if not near_island.is_preview:
		failures.append("islands should switch back to preview-only when they move outside the active distance")
	if near_island.reveal_history.size() < 2:
		failures.append("spawner should recalculate reveal state on later process ticks")

	turn_parent.queue_free()
	parent.queue_free()

	return failures
