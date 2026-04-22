class_name IslandSpawner
extends Node3D

const IslandScene = preload("res://scenes/islands/Island.tscn")

@export var target_island_count: int = 8
@export var cleanup_radius: float = 85.0
@export var spawn_outer_half_width: float = 28.0
@export var spawn_outer_half_depth: float = 42.0
@export var spawn_inner_half_width: float = 10.0
@export var spawn_inner_half_depth: float = 16.0
@export var preview_visible_distance: float = 72.0
@export var active_distance: float = 24.0
@export var minimum_island_spacing: float = 0.0
@export var spawn_retry_limit: int = 8

var ship = null
var run_model = null
var inactive_islands: Array[Island] = []


func _exit_tree() -> void:
	for island in inactive_islands:
		if is_instance_valid(island):
			island.free()
	inactive_islands.clear()


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	var islands_to_release: Array[Island] = []
	for child in get_children():
		if child is Island and child.global_position.distance_to(ship.global_position) > cleanup_radius:
			islands_to_release.append(child)

	for island in islands_to_release:
		release_island_to_pool(island)

	while _active_island_count() < target_island_count:
		if not _spawn_next_island():
			break

	_update_island_reveal_states()


func _effective_spawn_outer_half_width() -> float:
	return spawn_outer_half_width


func _effective_spawn_outer_half_depth() -> float:
	return maxf(spawn_outer_half_depth, preview_visible_distance)


func generate_spawn_offset() -> Vector3:
	var outer_half_width := _effective_spawn_outer_half_width()
	var outer_half_depth := _effective_spawn_outer_half_depth()
	var region := randi_range(0, 2)
	match region:
		0:
			return Vector3(
				randf_range(-outer_half_width, -spawn_inner_half_width),
				0.0,
				randf_range(-outer_half_depth, -spawn_inner_half_depth)
			)
		1:
			return Vector3(
				randf_range(-spawn_inner_half_width, spawn_inner_half_width),
				0.0,
				randf_range(-outer_half_depth, -spawn_inner_half_depth)
			)
		_:
			return Vector3(
				randf_range(spawn_inner_half_width, outer_half_width),
				0.0,
				randf_range(-outer_half_depth, -spawn_inner_half_depth)
			)


func is_in_spawn_band(offset: Vector3) -> bool:
	if absf(offset.x) > _effective_spawn_outer_half_width():
		return false
	return offset.z >= -_effective_spawn_outer_half_depth() and offset.z <= -spawn_inner_half_depth


func generate_validated_spawn_position(ship_position: Vector3, existing_positions: Array[Vector3]) -> Variant:
	for _attempt in range(spawn_retry_limit):
		var spawn_position := ship_position + generate_spawn_offset()
		if _is_position_valid(spawn_position, existing_positions):
			return spawn_position
	return null


func _active_island_count() -> int:
	var island_count := 0
	for child in get_children():
		if child is Area3D:
			island_count += 1
	return island_count


func acquire_island() -> Island:
	if not inactive_islands.is_empty():
		var island: Island = inactive_islands.pop_back()
		return island
	return IslandScene.instantiate()


func release_island_to_pool(island: Island) -> void:
	if island == null:
		return
	if inactive_islands.has(island):
		return
	if island.get_parent() == self:
		remove_child(island)
	elif island.get_parent() != null:
		return
	island.deactivate_to_pool()
	inactive_islands.append(island)


func get_inactive_pool_size() -> int:
	return inactive_islands.size()


func _is_position_valid(spawn_position: Vector3, existing_positions: Array[Vector3]) -> bool:
	for existing_position in existing_positions:
		if spawn_position.distance_to(existing_position) < minimum_island_spacing:
			return false
	return true


func _get_node_position(node: Node3D) -> Vector3:
	if node.is_inside_tree():
		return node.global_position
	return node.position


func _to_local_spawn_position(spawn_position: Vector3) -> Vector3:
	if is_inside_tree():
		return to_local(spawn_position)
	return transform.affine_inverse() * spawn_position


func _update_island_reveal_states() -> void:
	for child in get_children():
		if not child is Area3D:
			continue
		if not child.has_method("set_preview_state") or not child.has_method("update_reveal_from_distance"):
			continue
		var island_position := _get_node_position(child)
		var distance_to_ship := island_position.distance_to(_get_node_position(ship))
		child.set_preview_state(distance_to_ship > active_distance)
		child.update_reveal_from_distance(distance_to_ship, preview_visible_distance)


func _spawn_next_island() -> bool:
	var existing_positions: Array[Vector3] = []
	for child in get_children():
		if child is Area3D:
			existing_positions.append(_get_node_position(child))

	var spawn_position = generate_validated_spawn_position(_get_node_position(ship), existing_positions)
	if spawn_position == null:
		return false

	var island := acquire_island()
	var local_spawn_position := _to_local_spawn_position(spawn_position)
	var repair_rate := randf_range(10.0, 16.0)
	island.reset_for_spawn(local_spawn_position, repair_rate)
	add_child(island)
	return true
