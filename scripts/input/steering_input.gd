class_name SteeringInput
extends RefCounted

var debug_axis: float = 0.0


func set_debug_axis(value: float) -> void:
	debug_axis = clampf(value, -1.0, 1.0)


func get_steering_axis() -> float:
	var accel := Input.get_accelerometer()
	if accel.length() > 0.001:
		return clampf(-accel.x / 4.5, -1.0, 1.0)

	var gyro := Input.get_gyroscope()
	if gyro.length() > 0.001:
		return clampf(-gyro.z / 3.0, -1.0, 1.0)

	var keyboard_axis := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	return clampf(keyboard_axis + debug_axis, -1.0, 1.0)
