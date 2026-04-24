class_name WaveDebugCamera
extends Node3D

var move_speed: float = 20.0
var look_speed: float = 0.003
var camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = -0.5
var _captured := false
var _target: Node3D = null
var follow_mode := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	add_child(camera)
	_reset_orientation()


func _reset_orientation() -> void:
	_yaw = 0.0
	_pitch = -0.5
	_update_rotation()


func _update_rotation() -> void:
	rotation = Vector3.ZERO
	rotate_y(_yaw)
	rotate_object_local(Vector3.RIGHT, _pitch)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_captured = true
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				_captured = false

	if event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * look_speed
		_pitch -= event.relative.y * look_speed
		_pitch = clampf(_pitch, -PI / 2.0 + 0.05, PI / 2.0 - 0.05)
		_update_rotation()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			follow_mode = not follow_mode


func _process(delta: float) -> void:
	if follow_mode and _target != null:
		global_position = _target.global_position + Vector3(0.0, 30.0, 0.0)
		look_at(_target.global_position, Vector3.UP)
		return

	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1.0

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 3.0

	var direction := (transform.basis * input_dir).normalized()
	position += direction * speed * delta
