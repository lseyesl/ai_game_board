extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")
const ShipRulesScript = preload("res://scripts/core/ship_rules.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const SteeringInputScript = preload("res://scripts/input/steering_input.gd")
const SeaScript = preload("res://scripts/world/sea.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var model = RunModelScript.new()
	var wave = WaveProfileScript.large()
	ShipRulesScript.apply_wave(model, wave, 1.6)
	if model.damage <= 0.0:
		failures.append("large waves should add damage when the threshold is exceeded")

	var safe_model = RunModelScript.new()
	ShipRulesScript.apply_wave(safe_model, wave, 1.0)
	if safe_model.damage > 0.0:
		failures.append("large waves should not always deal damage below the threshold")

	var ship = ShipControllerScript.new()
	ship.run_model = RunModelScript.new()
	ship.input_adapter = SteeringInputScript.new()
	ship.forward_speed = 10.0
	ship.base_y = 0.0
	ship._build_visuals()
	if ship.get_node_or_null("BoatModel") == null:
		failures.append("ship should load the board.glb boat model")
	ship.simulate_tick(1.0, 0.0)
	if ship.position_delta.z >= 0.0:
		failures.append("ship should move forward along negative z")

	var sea = SeaScript.new()
	sea.target = ship
	ship.position = Vector3(12.0, 0.0, -18.0)
	if not sea.has_method("_physics_process"):
		failures.append("sea should follow the ship on physics ticks")
	else:
		sea._physics_process(1.0)
	if not is_equal_approx(sea.position.x, ship.position.x):
		failures.append("sea should follow the ship x position on physics ticks")
	if not is_equal_approx(sea.position.z, ship.position.z - 40.0):
		failures.append("sea should follow behind the ship on physics ticks")
	sea.free()
	ship.free()

	return failures
