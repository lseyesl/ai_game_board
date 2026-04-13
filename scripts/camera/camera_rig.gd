class_name CameraRig
extends Node3D

var target: Node3D = null
var follow_smoothing: float = 4.0
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
	if target == null:
		return

	var desired_position := target.global_position + target.transform.basis * Vector3(0.0, 8.0, 14.0)
	desired_position += Vector3(0.0, impact_strength, 0.0)
	global_position = global_position.lerp(desired_position, clampf(delta * follow_smoothing, 0.0, 1.0))
	look_at(target.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	impact_strength = move_toward(impact_strength, 0.0, delta * 3.5)


func request_bump(intensity: float) -> void:
	impact_strength = max(impact_strength, intensity)
