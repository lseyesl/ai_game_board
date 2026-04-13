extends RefCounted

const MainScript = preload("res://scripts/main/main.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var main = MainScript.new()

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_LEFT
	key_event.pressed = true
	if main._is_restart_event(key_event):
		failures.append("holding a steering key should not count as restart input")

	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	if not main._is_restart_event(touch_event):
		failures.append("screen touch should count as restart input")

	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	if not main._is_restart_event(accept_event):
		failures.append("ui_accept should count as restart input")

	main.free()
	return failures
