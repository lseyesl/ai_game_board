class_name IslandSpawner
extends Node3D

const IslandScript = preload("res://scripts/islands/island.gd")

@export var spawn_distance_ahead: float = 140.0
@export var cleanup_distance_behind: float = 35.0
@export var min_spacing: float = 40.0
@export var max_spacing: float = 56.0
@export var lane_width: float = 9.0

var ship = null
var run_model = null
var last_spawn_z: float = -30.0


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	while ship.global_position.z - last_spawn_z < spawn_distance_ahead:
		_spawn_next_island()

	for child in get_children():
		if child is Area3D and child.global_position.z > ship.global_position.z + cleanup_distance_behind:
			child.queue_free()


func get_next_spawn_z(current_z: float) -> float:
	return current_z - min_spacing


func _spawn_next_island() -> void:
	last_spawn_z -= randf_range(min_spacing, max_spacing)
	var island = IslandScript.new()
	island.position = Vector3(randf_range(-lane_width, lane_width), 0.0, last_spawn_z)
	island.repair_rate = randf_range(10.0, 16.0)
	add_child(island)
