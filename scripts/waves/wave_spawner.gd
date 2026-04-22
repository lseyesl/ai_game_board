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
var _furthest_ahead_distance: float = 0.0
var inactive_waves: Array[WaveZone] = []


func _exit_tree() -> void:
	for wave in inactive_waves:
		if is_instance_valid(wave):
			wave.free()
	inactive_waves.clear()


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if ship == null:
		return
	if run_model != null and run_model.is_game_over():
		return

	var ship_position := ship.global_position as Vector3
	var forward := _ship_forward()

	# Cleanup: release waves behind the ship
	var waves_to_release: Array[WaveZone] = []
	for child in get_children():
		if child is Area3D:
			var offset: Vector3 = child.global_position - ship_position
			var forward_dist: float = offset.dot(forward)
			if forward_dist < -cleanup_distance_behind:
				waves_to_release.append(child)

	for wave in waves_to_release:
		release_wave_to_pool(wave)

	# Measure how far ahead the furthest active wave is
	var max_ahead := -INF
	for child in get_children():
		if child is Area3D:
			var forward_dist: float = (child.global_position as Vector3 - ship_position).dot(forward)
			if forward_dist > 0.0 and forward_dist > max_ahead:
				max_ahead = forward_dist
	_furthest_ahead_distance = max_ahead if max_ahead > -INF else 0.0

	# Spawn waves ahead until coverage reaches spawn_distance_ahead
	while _furthest_ahead_distance < spawn_distance_ahead:
		_spawn_next_wave(forward)


func get_next_spawn_z(current_z: float) -> float:
	return current_z - min_spacing


func _ship_forward() -> Vector3:
	if ship != null and ship is Node3D:
		var fwd: Vector3 = -ship.global_transform.basis.z.normalized()
		fwd.y = 0.0
		return fwd.normalized()
	return Vector3.FORWARD


func acquire_wave() -> WaveZone:
	if not inactive_waves.is_empty():
		var wave: WaveZone = inactive_waves.pop_back()
		return wave
	var wave = WaveZoneScript.new()
	wave.spawner = self
	return wave


func release_wave_to_pool(wave: WaveZone) -> void:
	if wave == null:
		return
	if inactive_waves.has(wave):
		return
	if wave.get_parent() == self:
		remove_child(wave)
	elif wave.get_parent() != null:
		return
	wave.deactivate_to_pool()
	inactive_waves.append(wave)


func get_inactive_pool_size() -> int:
	return inactive_waves.size()


func _spawn_next_wave(forward: Vector3) -> void:
	var ship_position := ship.global_position as Vector3
	var right := forward.cross(Vector3.UP).normalized()
	var spacing := randf_range(min_spacing, max_spacing)
	_furthest_ahead_distance += spacing
	var spawn_position := ship_position + forward * _furthest_ahead_distance + right * randf_range(-lane_width, lane_width)
	var wave := acquire_wave()
	wave.spawner = self
	var push_direction := randf_range(0.35, 0.95)
	push_direction *= -1.0 if randf() < 0.5 else 1.0
	var profile = WaveProfileScript.large(push_direction) if randf() < large_wave_chance else WaveProfileScript.small(push_direction)
	if profile.is_large:
		profile.lift_force = randf_range(4.0, 8.0)
		profile.damage_risk = randf_range(6.0, 10.0)
	wave.reset_for_spawn(spawn_position, profile)
	add_child(wave)
