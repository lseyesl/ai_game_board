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


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	while _active_island_count() < target_island_count:
		if not _spawn_next_island():
			break

	for child in get_children():
		if child is Area3D and child.global_position.distance_to(ship.global_position) > cleanup_radius:
			child.queue_free()

	_update_island_reveal_states()


func _effective_spawn_outer_half_width() -> float:
	return maxf(spawn_outer_half_width, preview_visible_distance)


func _effective_spawn_outer_half_depth() -> float:
	return maxf(spawn_outer_half_depth, preview_visible_distance)


func generate_spawn_offset() -> Vector3:
	var outer_half_width := _effective_spawn_outer_half_width()
	var outer_half_depth := _effective_spawn_outer_half_depth()
	var side := randi_range(0, 3)
	match side:
		0:
			return Vector3(
				randf_range(-outer_half_width, -spawn_inner_half_width),
				0.0,
				randf_range(-outer_half_depth, outer_half_depth)
			)
		1:
			return Vector3(
				randf_range(spawn_inner_half_width, outer_half_width),
				0.0,
				randf_range(-outer_half_depth, outer_half_depth)
			)
		2:
			return Vector3(
				randf_range(-outer_half_width, outer_half_width),
				0.0,
				randf_range(-outer_half_depth, -spawn_inner_half_depth)
			)
		_:
			return Vector3(
				randf_range(-outer_half_width, outer_half_width),
				0.0,
				randf_range(spawn_inner_half_depth, outer_half_depth)
			)


func is_in_spawn_band(offset: Vector3) -> bool:
	if absf(offset.x) > _effective_spawn_outer_half_width() or absf(offset.z) > _effective_spawn_outer_half_depth():
		return false
	return absf(offset.x) >= spawn_inner_half_width or absf(offset.z) >= spawn_inner_half_depth


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

	var island: Island = IslandScene.instantiate()
	island.position = _to_local_spawn_position(spawn_position)
	island.repair_rate = randf_range(10.0, 16.0)
	add_child(island)
	return true
