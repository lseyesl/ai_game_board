extends RefCounted

const SteeringInputScript = preload("res://scripts/input/steering_input.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var input_adapter = SteeringInputScript.new()
	input_adapter.set_debug_axis(-1.0)
	if not is_equal_approx(input_adapter.get_steering_axis(), -1.0):
		failures.append("debug steering axis should return negative left input")

	input_adapter.set_debug_axis(2.5)
	if not is_equal_approx(input_adapter.get_steering_axis(), 1.0):
		failures.append("debug steering axis should clamp to 1.0")

	return failures
