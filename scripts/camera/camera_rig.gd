class_name CameraRig
extends Node3D

var target: Node3D = null
var follow_smoothing: float = 4.0
var follow_offset: Vector3 = Vector3(0.0, 8.0, 14.0)
var look_ahead_distance: float = 4.0
var impact_strength: float = 0.0
var camera: Camera3D


func _ready() -> void:
	if not has_node("Camera3D"):
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		add_child(camera)
	else:
		camera = $Camera3D


func _process(delta: float) -> void:
	update_follow(delta)


func update_follow(delta: float) -> void:
	if target == null:
		return

	var forward := _get_horizontal_forward()
	var desired_position := target.global_position - forward * follow_offset.z
	desired_position.y = target.global_position.y + follow_offset.y + impact_strength
	global_position = global_position.lerp(desired_position, clampf(delta * follow_smoothing, 0.0, 1.0))
	look_at(target.global_position + Vector3.UP + forward * look_ahead_distance, Vector3.UP)
	impact_strength = move_toward(impact_strength, 0.0, delta * 3.5)


func request_bump(intensity: float) -> void:
	impact_strength = max(impact_strength, intensity)


func _get_horizontal_forward() -> Vector3:
	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()
