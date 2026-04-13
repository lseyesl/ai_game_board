extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")
const IslandRulesScript = preload("res://scripts/core/island_rules.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var model = RunModelScript.new()
	model.damage = 40.0
	IslandRulesScript.apply_repair(model, 5.0, 2.0)
	if not is_equal_approx(model.damage, 30.0):
		failures.append("island repair should reduce damage over time")

	if not IslandRulesScript.enter_island(false):
		failures.append("enter_island should enable safe state")

	return failures
