extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var model = RunModelScript.new()
	var applied_damage := model.add_damage(150.0)
	if not is_equal_approx(model.damage, 100.0):
		failures.append("damage should cap at 100")
	if not is_equal_approx(applied_damage, 100.0):
		failures.append("add_damage should return actual applied damage")

	model.invulnerable = true
	if not is_equal_approx(model.add_damage(10.0), 0.0):
		failures.append("invulnerable damage should report zero applied damage")
	model.invulnerable = false

	model.damage = 30.0
	model.repair(50.0)
	if not is_equal_approx(model.damage, 0.0):
		failures.append("repair should stop at zero")

	model.advance_distance(12.5)
	if not is_equal_approx(model.distance, 12.5):
		failures.append("distance should advance by the supplied amount")
	if not is_equal_approx(model.get_best_distance(), 12.5):
		failures.append("best distance should track the farthest run distance")

	return failures
