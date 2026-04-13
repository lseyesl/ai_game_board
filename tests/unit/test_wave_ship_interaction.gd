extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")
const ShipRulesScript = preload("res://scripts/core/ship_rules.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const SteeringInputScript = preload("res://scripts/input/steering_input.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var model = RunModelScript.new()
	var wave = WaveProfileScript.large()
	ShipRulesScript.apply_wave(model, wave, 1.0)
	if model.damage <= 0.0:
		failures.append("large waves should add damage when applied")

	var ship = ShipControllerScript.new()
	ship.run_model = RunModelScript.new()
	ship.input_adapter = SteeringInputScript.new()
	ship.forward_speed = 10.0
	ship.base_y = 0.0
	ship.simulate_tick(1.0, 0.0)
	if ship.position_delta.z >= 0.0:
		failures.append("ship should move forward along negative z")
	ship.free()

	return failures
