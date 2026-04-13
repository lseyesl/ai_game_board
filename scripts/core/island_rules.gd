class_name IslandRules
extends RefCounted


static func apply_repair(model, repair_rate: float, delta: float) -> void:
	if model == null:
		return
	model.repair(repair_rate * delta)


static func enter_island(_current_state: bool) -> bool:
	return true


static func exit_island(_current_state: bool) -> bool:
	return false
