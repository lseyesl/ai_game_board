extends SceneTree

const TEST_FILES := [
	"res://tests/unit/test_run_model.gd",
	"res://tests/unit/test_steering_input.gd",
	"res://tests/unit/test_wave_profile.gd",
	"res://tests/unit/test_wave_ship_interaction.gd",
	"res://tests/unit/test_island_rules.gd",
	"res://tests/unit/test_game_over_rules.gd",
	"res://tests/unit/test_restart_rules.gd",
]


func _init() -> void:
	var failures: Array[String] = []
	for test_path in TEST_FILES:
		var script_resource = load(test_path)
		if script_resource == null:
			failures.append("%s: failed to load script" % test_path)
			continue
		if not script_resource is GDScript:
			failures.append("%s: loaded resource is not a GDScript" % test_path)
			continue
		var test_instance = script_resource.new()
		if test_instance == null:
			failures.append("%s: failed to instantiate test" % test_path)
			continue
		var test_failures: Array[String] = test_instance.run()
		if test_failures.is_empty():
			print("PASS %s" % test_path)
		else:
			for failure in test_failures:
				failures.append("%s: %s" % [test_path, failure])

	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
		return

	push_error("TEST FAILURES")
	for failure in failures:
		push_error(failure)
	quit(1)
