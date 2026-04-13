class_name WaveSpawner
extends Node3D

const WaveZoneScript = preload("res://scripts/waves/wave_zone.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")

@export var spawn_distance_ahead: float = 100.0
@export var cleanup_distance_behind: float = 25.0
@export var min_spacing: float = 14.0
@export var max_spacing: float = 22.0
@export var lane_width: float = 12.0
@export var large_wave_chance: float = 0.28

var ship = null
var run_model = null
var last_spawn_z: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	while ship.global_position.z - last_spawn_z < spawn_distance_ahead:
		_spawn_next_wave()

	for child in get_children():
		if child is Area3D and child.global_position.z > ship.global_position.z + cleanup_distance_behind:
			child.queue_free()


func get_next_spawn_z(current_z: float) -> float:
	return current_z - min_spacing


func _spawn_next_wave() -> void:
	last_spawn_z -= randf_range(min_spacing, max_spacing)
	var wave = WaveZoneScript.new()
	var push_direction := randf_range(0.35, 0.95)
	push_direction *= -1.0 if randf() < 0.5 else 1.0
	var profile = WaveProfileScript.large(push_direction) if randf() < large_wave_chance else WaveProfileScript.small(push_direction)
	wave.configure(profile)
	wave.position = Vector3(randf_range(-lane_width, lane_width), 0.0, last_spawn_z)
	add_child(wave)
