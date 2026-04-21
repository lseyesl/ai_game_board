class_name IslandSpawner
extends Node3D

const IslandScene = preload("res://scenes/islands/Island.tscn")

@export var target_island_count: int = 8
@export var cleanup_radius: float = 85.0
@export var spawn_outer_half_width: float = 28.0
@export var spawn_outer_half_depth: float = 42.0
@export var spawn_inner_half_width: float = 10.0
@export var spawn_inner_half_depth: float = 16.0

var ship = null
var run_model = null


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	while _active_island_count() < target_island_count:
		_spawn_next_island()

	for child in get_children():
		if child is Area3D and child.global_position.distance_to(ship.global_position) > cleanup_radius:
			child.queue_free()


func generate_spawn_offset() -> Vector3:
	var side := randi_range(0, 3)
	match side:
		0:
			return Vector3(
				randf_range(-spawn_outer_half_width, -spawn_inner_half_width),
				0.0,
				randf_range(-spawn_outer_half_depth, spawn_outer_half_depth)
			)
		1:
			return Vector3(
				randf_range(spawn_inner_half_width, spawn_outer_half_width),
				0.0,
				randf_range(-spawn_outer_half_depth, spawn_outer_half_depth)
			)
		2:
			return Vector3(
				randf_range(-spawn_outer_half_width, spawn_outer_half_width),
				0.0,
				randf_range(-spawn_outer_half_depth, -spawn_inner_half_depth)
			)
		_:
			return Vector3(
				randf_range(-spawn_outer_half_width, spawn_outer_half_width),
				0.0,
				randf_range(spawn_inner_half_depth, spawn_outer_half_depth)
			)


func is_in_spawn_band(offset: Vector3) -> bool:
	if absf(offset.x) > spawn_outer_half_width or absf(offset.z) > spawn_outer_half_depth:
		return false
	return absf(offset.x) >= spawn_inner_half_width or absf(offset.z) >= spawn_inner_half_depth


func _active_island_count() -> int:
	var island_count := 0
	for child in get_children():
		if child is Area3D:
			island_count += 1
	return island_count


func _spawn_next_island() -> void:
	var island: Island = IslandScene.instantiate()
	island.position = ship.global_position + generate_spawn_offset()
	island.repair_rate = randf_range(10.0, 16.0)
	add_child(island)
