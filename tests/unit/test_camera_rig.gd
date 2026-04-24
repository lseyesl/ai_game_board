extends RefCounted

const CameraRigScript = preload("res://scripts/camera/camera_rig.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	_test_camera_rig_ignores_target_pitch_and_roll(failures)
	_test_camera_rig_keeps_world_up_orientation_when_target_tilts(failures)
	_test_camera_rig_follows_target_yaw(failures)
	_test_camera_rig_smooths_follow_position(failures)
	_test_camera_rig_damage_bump_adds_temporary_vertical_offset(failures)
	_test_camera_rig_damage_bump_decays(failures)

	return failures


func _test_camera_rig_ignores_target_pitch_and_roll(failures: Array[String]) -> void:
	var flat_position := _camera_position_for_rotation(Vector3(0.0, 35.0, 0.0), failures)
	var tilted_position := _camera_position_for_rotation(Vector3(25.0, 35.0, -20.0), failures)
	_assert_vector_close(tilted_position, flat_position, 0.01, "camera follow should ignore target pitch and roll", failures)


func _test_camera_rig_follows_target_yaw(failures: Array[String]) -> void:
	var forward_position := _camera_position_for_rotation(Vector3.ZERO, failures)
	var turned_position := _camera_position_for_rotation(Vector3(0.0, 90.0, 0.0), failures)
	if forward_position.distance_to(turned_position) <= 10.0:
		failures.append("camera follow should change with target yaw")


func _test_camera_rig_keeps_world_up_orientation_when_target_tilts(failures: Array[String]) -> void:
	var setup := _create_camera_setup(failures)
	if setup.is_empty():
		return
	var parent: Node3D = setup["parent"]
	var target: Node3D = setup["target"]
	var rig = setup["rig"]

	target.rotation_degrees = Vector3(25.0, 35.0, -20.0)
	rig.call("update_follow", 1.0)

	var forward: Vector3 = -target.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var expected_look_direction: Vector3 = (target.global_position + Vector3.UP + forward * rig.look_ahead_distance - rig.global_position).normalized()
	var actual_look_direction: Vector3 = -rig.global_transform.basis.z.normalized()
	_assert_vector_close(actual_look_direction, expected_look_direction, 0.01, "camera rig should look at the stable ahead target", failures)

	if absf(rig.global_transform.basis.x.normalized().dot(Vector3.UP)) > 0.01:
		failures.append("camera rig horizon should stay level when target pitches or rolls")

	parent.queue_free()


func _test_camera_rig_smooths_follow_position(failures: Array[String]) -> void:
	var setup := _create_camera_setup(failures)
	if setup.is_empty():
		return
	var parent: Node3D = setup["parent"]
	var target: Node3D = setup["target"]
	var rig = setup["rig"]

	rig.global_position = Vector3.ZERO
	rig.call("update_follow", 0.1)
	var desired_position: Vector3 = target.global_position + Vector3(0.0, rig.follow_offset.y, rig.follow_offset.z)
	if rig.global_position.distance_to(Vector3.ZERO) <= 0.01:
		failures.append("camera rig should move toward the desired position when smoothing")
	if rig.global_position.distance_to(desired_position) <= 0.01:
		failures.append("camera rig should not snap to desired position for small deltas")

	parent.queue_free()


func _test_camera_rig_damage_bump_adds_temporary_vertical_offset(failures: Array[String]) -> void:
	var setup := _create_camera_setup(failures)
	if setup.is_empty():
		return
	var parent: Node3D = setup["parent"]
	var rig = setup["rig"]

	rig.request_bump(0.5)
	rig.call("update_follow", 1.0)
	if rig.global_position.y <= 8.0:
		failures.append("damage bump should lift camera target position temporarily")

	parent.queue_free()


func _test_camera_rig_damage_bump_decays(failures: Array[String]) -> void:
	var setup := _create_camera_setup(failures)
	if setup.is_empty():
		return
	var parent: Node3D = setup["parent"]
	var rig = setup["rig"]

	rig.request_bump(0.5)
	rig.call("update_follow", 0.1)
	if rig.impact_strength >= 0.5:
		failures.append("damage bump should decay after a follow update")
	if rig.impact_strength <= 0.0:
		failures.append("damage bump should decay gradually instead of disappearing for small deltas")

	parent.queue_free()


func _camera_position_for_rotation(rotation_degrees: Vector3, failures: Array[String]) -> Vector3:
	var setup := _create_camera_setup(failures)
	if setup.is_empty():
		return Vector3.ZERO
	var parent: Node3D = setup["parent"]
	var target: Node3D = setup["target"]
	var rig = setup["rig"]

	target.rotation_degrees = rotation_degrees
	rig.call("update_follow", 1.0)
	var result: Vector3 = rig.global_position
	parent.queue_free()
	return result


func _create_camera_setup(failures: Array[String]) -> Dictionary:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		failures.append("camera rig test requires the live SceneTree from the test harness")
		return {}

	var parent := Node3D.new()
	var target := Node3D.new()
	var rig = CameraRigScript.new()
	rig.target = target
	scene_tree.root.add_child(parent)
	parent.add_child(target)
	parent.add_child(rig)

	if not rig.has_method("update_follow"):
		failures.append("camera rig should expose update_follow so follow math can be tested directly")
		parent.queue_free()
		return {}

	return {
		"parent": parent,
		"target": target,
		"rig": rig,
	}


func _assert_vector_close(actual: Vector3, expected: Vector3, tolerance: float, message: String, failures: Array[String]) -> void:
	if actual.distance_to(expected) > tolerance:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])
