extends RefCounted

const IslandSpawnerScript = preload("res://scripts/islands/island_spawner.gd")


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

	var saw_left := false
	var saw_right := false
	var saw_front := false
	var saw_back := false

	for _index in range(240):
		var offset: Vector3 = spawner.generate_spawn_offset()
		if not spawner.is_in_spawn_band(offset):
			failures.append("generated island offset should stay inside the outer ring around the board")
			break
		if offset.x <= -spawner.spawn_inner_half_width:
			saw_left = true
		if offset.x >= spawner.spawn_inner_half_width:
			saw_right = true
		if offset.z <= -spawner.spawn_inner_half_depth:
			saw_front = true
		if offset.z >= spawner.spawn_inner_half_depth:
			saw_back = true

	if not saw_left:
		failures.append("island spawner should place islands on the left side of the board")
	if not saw_right:
		failures.append("island spawner should place islands on the right side of the board")
	if not saw_front:
		failures.append("island spawner should place islands in front of the board")
	if not saw_back:
		failures.append("island spawner should place islands behind the board")

	seed(24680)
	var spaced_spawn_position = spawner.generate_validated_spawn_position(
		Vector3.ZERO,
		[Vector3.ZERO]
	)
	if spaced_spawn_position == null:
		failures.append("island spawner should find a spawn point that satisfies the minimum island spacing when room exists")
	else:
		var spaced_spawn_offset: Vector3 = spaced_spawn_position - Vector3.ZERO
		if not spawner.is_in_spawn_band(spaced_spawn_offset):
			failures.append("validated island spawns should stay inside the existing spawn band")
		if spaced_spawn_position.distance_to(Vector3.ZERO) < spawner.minimum_island_spacing:
			failures.append("validated island spawns should keep at least the configured minimum spacing from existing islands")

	spawner.minimum_island_spacing = 1000.0
	spawner.spawn_retry_limit = 3
	seed(13579)
	var blocked_spawn_position = spawner.generate_validated_spawn_position(
		Vector3.ZERO,
		[Vector3.ZERO]
	)
	if blocked_spawn_position != null:
		failures.append("island spawner should return null after the retry limit when no spawn point satisfies spacing")

	var saw_extended_spawn := false
	spawner.preview_visible_distance = 64.0
	spawner.minimum_island_spacing = 0.0
	spawner.spawn_retry_limit = 24
	seed(97531)
	for _extended_index in range(240):
		var extended_offset: Vector3 = spawner.generate_spawn_offset()
		if not spawner.is_in_spawn_band(extended_offset):
			failures.append("preview-distance island offsets should stay inside the expanded spawn band")
			break
		if absf(extended_offset.x) > 28.0 or absf(extended_offset.z) > 42.0:
			saw_extended_spawn = true
	if not saw_extended_spawn:
		failures.append("island spawner should generate farther preview islands beyond the old near-only band")
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
	var expected_world_spawn_position = transformed_spawner.generate_validated_spawn_position(ship.global_position, [])
	seed(424242)
	transformed_spawner._spawn_next_island()

	var spawned_island = transformed_spawner.get_child(0)
	if spawned_island.global_position.distance_to(expected_world_spawn_position) > 0.001:
		failures.append("spawned islands should use the validated world-space spawn position even when the spawner has a parent transform")

	var reveal_spawner = IslandSpawnerScript.new()
	reveal_spawner.target_island_count = 0
	reveal_spawner.preview_visible_distance = 72.0
	reveal_spawner.active_distance = 24.0
	parent.add_child(reveal_spawner)

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

	parent.queue_free()

	return failures
