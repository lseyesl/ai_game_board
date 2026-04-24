extends SceneTree

const CameraRigTestScript = preload("res://tests/unit/test_camera_rig.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_instance = CameraRigTestScript.new()
	var failures: Array[String] = test_instance.run()
	if failures.is_empty():
		print("PASS res://tests/unit/test_camera_rig.gd")
		print("ALL CAMERA RIG TESTS PASSED")
		quit(0)
		return

	push_error("CAMERA RIG TEST FAILURES")
	for failure in failures:
		push_error(failure)
	quit(1)
