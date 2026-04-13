extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var model = RunModelScript.new()
	model.add_damage(100.0)
	if not model.is_game_over():
		failures.append("run should end when damage reaches 100")

	return failures
