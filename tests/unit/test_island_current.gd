extends RefCounted

const IslandScene = preload("res://scenes/islands/Island.tscn")
const IslandScript = preload("res://scripts/islands/island.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const RunModelScript = preload("res://scripts/core/run_model.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var island = IslandScript.new()
	island.safe_radius = 6.0
	island.current_radius = 13.0
	island.current_push_strength = 8.5

	if not island.has_method("set_preview_state"):
		failures.append("island should expose a preview state API")
	else:
		island.set_preview_state(true)
		var preview_push := island.calculate_current_push(Vector3(9.0, 0.0, 0.0), 1.0)
		if preview_push != Vector3.ZERO:
			failures.append("preview islands should not push ships with current effects")

		var preview_ship = ShipControllerScript.new()
		preview_ship.run_model = RunModelScript.new()
		preview_ship.run_model.damage = 20.0
		island._on_body_entered(preview_ship)
		preview_ship.simulate_tick(1.0, 0.0)
		if not is_equal_approx(preview_ship.run_model.damage, 20.0):
			failures.append("preview islands should not repair ships in the safe zone")
		if preview_ship.run_model.invulnerable:
			failures.append("preview islands should not grant safe-zone invulnerability")
		if preview_ship.run_model.repairing:
			failures.append("preview islands should not mark ships as repairing")
		preview_ship.free()

		island.set_preview_state(false)

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

	var active_ship = ShipControllerScript.new()
	active_ship.run_model = RunModelScript.new()
	active_ship.run_model.damage = 20.0
	island._on_body_entered(active_ship)
	active_ship.simulate_tick(1.0, 0.0)
	if active_ship.run_model.damage >= 20.0:
		failures.append("active islands should keep repairing ships in the safe zone")
	if not active_ship.run_model.invulnerable:
		failures.append("active islands should still grant safe-zone invulnerability")
	if not active_ship.run_model.repairing:
		failures.append("active islands should still mark ships as repairing")

	var ship = ShipControllerScript.new()
	ship.run_model = RunModelScript.new()
	ship.forward_speed = 0.0
	ship.base_y = 0.0
	ship.apply_environment_push(Vector3(3.0, 0.0, 0.0))
	ship.simulate_tick(1.0, 0.0)
	if ship.position.x <= 0.0:
		failures.append("environment push should move the ship laterally")

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		failures.append("island visual reveal test requires the live SceneTree from the test harness")
	else:
		var visual_island = IslandScene.instantiate()
		scene_tree.root.add_child(visual_island)
		visual_island.set_preview_state(true)
		visual_island.update_reveal_state(0.0)
		var island_model: Node3D = visual_island.get_node("IslandModel")
		if island_model.scale.x <= 1.0:
			failures.append("preview islands should start slightly oversized before becoming fully active")
		var shore_mesh: MeshInstance3D = visual_island.get_node("ShoreMesh")
		var shore_material := shore_mesh.get_active_material(0) as StandardMaterial3D
		if shore_material == null or shore_material.albedo_color.a >= 0.45:
			failures.append("preview islands should fade the shore mesh while distant")
		visual_island.queue_free()

	active_ship.free()
	ship.free()
	island.free()
	return failures
