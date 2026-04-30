class_name SteeringInput
extends RefCounted

var debug_axis: float = 0.0

## Last sensor readings exposed for debug overlay (read-only).
var gyro_raw := Vector3.ZERO
var accel_raw := Vector3.ZERO


func set_debug_axis(value: float) -> void:
	debug_axis = clampf(value, -1.0, 1.0)


func get_steering_axis() -> float:
	var total := 0.0

	gyro_raw = Input.get_gyroscope()
	if gyro_raw.length() > 0.01:
		total += -gyro_raw.y

	accel_raw = Input.get_accelerometer()
	if accel_raw.length() > 0.01:
		total += -accel_raw.x / 4.5

	var keyboard_axis := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	total += keyboard_axis + debug_axis

	return clampf(total, -1.0, 1.0)
