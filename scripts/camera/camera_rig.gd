class_name CameraRig
extends Node3D

var target: Node3D = null
var follow_smoothing: float = 4.0
var follow_offset: Vector3 = Vector3(0.0, 8.0, 14.0)
var look_ahead_distance: float = 4.0
var impact_strength: float = 0.0
var camera: Camera3D

var _prev_physics_position: Vector3 = Vector3.ZERO
var _curr_physics_position: Vector3 = Vector3.ZERO
var _curr_look_target: Vector3 = Vector3.ZERO
var _prev_look_target: Vector3 = Vector3.ZERO
var _physics_frame_valid: bool = false
var _last_physics_msec: float = 0.0


func _ready() -> void:
	if not has_node("Camera3D"):
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		add_child(camera)
	else:
		camera = $Camera3D


func _physics_process(delta: float) -> void:
	if target == null:
		return
	update_follow(delta)


func update_follow(delta: float) -> void:
	if target == null:
		return

	var forward := _get_horizontal_forward()
	var desired_position := target.global_position - forward * follow_offset.z
	desired_position.y = target.global_position.y + follow_offset.y + impact_strength

	if not _physics_frame_valid:
		_prev_physics_position = global_position
		_curr_physics_position = global_position
		_prev_look_target = target.global_position + Vector3.UP + forward * look_ahead_distance
		_curr_look_target = _prev_look_target
		_physics_frame_valid = true
	else:
		_prev_physics_position = _curr_physics_position
		_prev_look_target = _curr_look_target

	_curr_physics_position = _curr_physics_position.lerp(desired_position, clampf(delta * follow_smoothing, 0.0, 1.0))
	_curr_look_target = target.global_position + Vector3.UP + forward * look_ahead_distance
	impact_strength = move_toward(impact_strength, 0.0, delta * 3.5)
	_last_physics_msec = Time.get_ticks_msec()

	global_position = _curr_physics_position
	look_at(_curr_look_target, Vector3.UP)


func _process(_delta: float) -> void:
	if target == null or not _physics_frame_valid:
		return

	var now_msec := Time.get_ticks_msec()
	var physics_step_msec := 1000.0 / Engine.get_physics_ticks_per_second()
	var elapsed := now_msec - _last_physics_msec
	var fraction := clampf(elapsed / physics_step_msec, 0.0, 1.0)
	var interp_position := _prev_physics_position.lerp(_curr_physics_position, fraction)
	global_position = interp_position
	look_at(_curr_look_target, Vector3.UP)


func request_bump(intensity: float) -> void:
	impact_strength = max(impact_strength, intensity)


func _get_horizontal_forward() -> Vector3:
	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()
