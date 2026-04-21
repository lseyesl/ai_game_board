extends RefCounted

const IslandScript = preload("res://scripts/islands/island.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const RunModelScript = preload("res://scripts/core/run_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var island = IslandScript.new()
	island.safe_radius = 6.0
	island.current_radius = 13.0
	island.current_push_strength = 8.5

	var safe_push := island.calculate_current_push(Vector3(4.0, 0.0, 0.0), 1.0)
	if safe_push != Vector3.ZERO:
		failures.append("island current should not push ships inside the safe core")

	var ring_push := island.calculate_current_push(Vector3(9.0, 0.0, 0.0), 1.0)
	if ring_push.x <= 0.0:
		failures.append("island current should push ships outward on the ring")
	if not is_equal_approx(ring_push.z, 0.0):
		failures.append("island current should push radially away from the island center")

	var outside_push := island.calculate_current_push(Vector3(20.0, 0.0, 0.0), 1.0)
	if outside_push != Vector3.ZERO:
		failures.append("island current should stop affecting ships beyond the outer ring")

	var ship = ShipControllerScript.new()
	ship.run_model = RunModelScript.new()
	ship.forward_speed = 0.0
	ship.base_y = 0.0
	ship.apply_environment_push(Vector3(3.0, 0.0, 0.0))
	ship.simulate_tick(1.0, 0.0)
	if ship.position.x <= 0.0:
		failures.append("environment push should move the ship laterally")

	ship.free()
	return failures
