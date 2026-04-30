class_name WaveSpawner
extends Node3D

const WaveZoneScript = preload("res://scripts/waves/wave_zone.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")

@export var spawn_distance_ahead: float = 100.0
@export var cleanup_distance_behind: float = 25.0
@export var cleanup_protection_radius: float = 45.0
@export var min_spacing: float = 14.0
@export var max_spacing: float = 22.0
@export var lane_width: float = 12.0
@export var large_wave_chance: float = 0.28
@export var max_large_wave_chance: float = 0.45
@export var full_difficulty_distance: float = 800.0

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
	var right := forward.cross(Vector3.UP).normalized()

	# Cleanup: release waves behind the ship
	var waves_to_release: Array[WaveZone] = []
	for child in get_children():
		if child is Area3D:
			var offset: Vector3 = child.global_position - ship_position
			var forward_dist: float = offset.dot(forward)
			if offset.length() > cleanup_protection_radius and forward_dist < -cleanup_distance_behind:
				waves_to_release.append(child)

	for wave in waves_to_release:
		release_wave_to_pool(wave)

	# Measure how far ahead the furthest active wave is
	var max_ahead := -INF
	for child in get_children():
		if child is Area3D:
			var offset: Vector3 = child.global_position - ship_position
			var forward_dist: float = offset.dot(forward)
			var lateral_dist: float = absf(offset.dot(right))
			if forward_dist > 0.0 and lateral_dist <= lane_width and forward_dist > max_ahead:
				max_ahead = forward_dist
	_furthest_ahead_distance = max_ahead if max_ahead > -INF else 0.0

	# Spawn waves ahead until coverage reaches spawn_distance_ahead
	while _furthest_ahead_distance < spawn_distance_ahead:
		_spawn_next_wave(forward)


func get_next_spawn_z(current_z: float) -> float:
	return current_z - min_spacing


func get_difficulty_factor() -> float:
	if run_model == null or full_difficulty_distance <= 0.0:
		return 0.0
	return clampf(run_model.distance / full_difficulty_distance, 0.0, 1.0)


func get_large_wave_chance() -> float:
	return lerpf(large_wave_chance, max_large_wave_chance, get_difficulty_factor())


func _build_wave_profile(push_direction: float, is_large_wave: bool) -> WaveProfile:
	var profile = WaveProfileScript.large(push_direction) if is_large_wave else WaveProfileScript.small(push_direction)
	if not is_large_wave:
		return profile
	var difficulty := get_difficulty_factor()
	profile.turn_push *= lerpf(1.0, 1.25, difficulty)
	profile.lateral_force = lerpf(7.0, 10.5, difficulty)
	profile.damage_per_second = lerpf(5.0, 8.5, difficulty)
	return profile


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
	var profile = _build_wave_profile(push_direction, randf() < get_large_wave_chance())
	if profile.is_large:
		var difficulty := get_difficulty_factor()
		var lateral_multiplier := lerpf(1.0, 1.22, difficulty)
		var damage_multiplier := lerpf(1.0, 1.375, difficulty)
		profile.lateral_force = randf_range(5.0, 9.0) * lateral_multiplier
		profile.speed_multiplier = randf_range(0.5, 0.7)
		profile.damage_per_second = randf_range(4.0, 8.0) * damage_multiplier
	wave.reset_for_spawn(spawn_position, profile)
	var drift_sign := -1.0 if randf() < 0.5 else 1.0
	wave.configure_drift(right * drift_sign * profile.drift_speed)
	add_child(wave)
