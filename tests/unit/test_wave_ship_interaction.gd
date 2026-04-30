extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")
const WaveZoneScript = preload("res://scripts/waves/wave_zone.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const SteeringInputScript = preload("res://scripts/input/steering_input.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	# --- RunModel damage still works ---
	var model = RunModelScript.new()
	model.add_damage(5.0)
	if model.damage < 5.0:
		failures.append("RunModel.add_damage should increase damage")

	# --- Large wave profile has damage_per_second ---
	var large_wave = WaveProfileScript.large()
	if large_wave.damage_per_second <= 0.0:
		failures.append("large wave profile should have positive damage_per_second")

	# --- Small wave profile has no damage ---
	var small_wave = WaveProfileScript.small()
	if small_wave.damage_per_second > 0.0:
		failures.append("small wave profile should have zero damage_per_second")

	# --- Ship moves forward along negative Z ---
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

	# --- Ship respects speed_multiplier from waves ---
	ship.simulate_tick_with_waves(1.0, 0.0, [_make_wave(Vector3.ZERO, 0.0, 0.5, 0.0, 0.0)])
	var expected_speed: float = 10.0 * 0.5
	var actual_forward: float = -ship.position_delta.z
	if not is_equal_approx(actual_forward, expected_speed):
		failures.append("ship forward speed should be reduced by wave_speed_multiplier, expected %f got %f" % [expected_speed, actual_forward])

	# --- Wave lateral velocity is applied ---
	ship.simulate_tick_with_waves(1.0, 0.0, [_make_wave(Vector3(1.0, 0.0, 0.0), 5.0, 1.0, 0.0, 0.0)])
	if ship.position_delta.x <= 0.0:
		failures.append("ship should be pushed laterally by wave_lateral_velocity")

	# --- Lateral velocity decays when no waves push ---
	ship.wave_lateral_velocity = Vector3(10.0, 0.0, 0.0)
	ship.simulate_tick(1.0, 0.0)  # no overlapping waves, so it should decay
	if ship.wave_lateral_velocity.length() >= 10.0:
		failures.append("wave_lateral_velocity should decay when no overlapping waves")

	# --- Leaving waves resets speed before the next movement step ---
	ship.wave_speed_multiplier = 0.5
	ship.simulate_tick(1.0, 0.0)
	actual_forward = -ship.position_delta.z
	if not is_equal_approx(actual_forward, 10.0):
		failures.append("ship speed should return to normal immediately when no waves overlap")

	# --- Overlapping waves visibly amplify boat pitch and roll ---
	var calm_ship = ShipControllerScript.new()
	calm_ship.run_model = RunModelScript.new()
	calm_ship.input_adapter = SteeringInputScript.new()
	calm_ship._build_visuals()
	calm_ship.simulate_tick_with_waves(0.0, 0.0, [])
	var calm_boat_model := calm_ship.get_node_or_null("BoatModel") as Node3D
	var calm_pitch := absf(calm_boat_model.rotation_degrees.x)
	var calm_roll := absf(calm_boat_model.rotation_degrees.z)

	var wave_ship = ShipControllerScript.new()
	wave_ship.run_model = RunModelScript.new()
	wave_ship.input_adapter = SteeringInputScript.new()
	wave_ship._build_visuals()
	wave_ship.simulate_tick_with_waves(0.0, 0.0, [_make_wave(Vector3(1.0, 0.0, 0.0), 7.0, 0.6, 8.0, 0.5)])
	var wave_boat_model := wave_ship.get_node_or_null("BoatModel") as Node3D
	if absf(wave_boat_model.rotation_degrees.x) <= calm_pitch:
		failures.append("overlapping waves should amplify boat pitch to show rougher water")
	if absf(wave_boat_model.rotation_degrees.z) <= calm_roll:
		failures.append("overlapping waves should amplify boat roll to show rougher water")
	calm_ship.free()
	wave_ship.free()

	# --- Stale lateral velocity decays when overlapping waves have no net lateral direction ---
	ship.wave_lateral_velocity = Vector3(9.0, 0.0, 0.0)
	ship.simulate_wave_effects([_make_wave(Vector3.ZERO, 4.0, 0.75, 0.0, 0.0)], 1.0)
	if ship.wave_lateral_velocity.length() >= 9.0:
		failures.append("wave_lateral_velocity should decay when overlapping waves have zero drift_direction")

	# --- Continuous turn push remains bounded across repeated overlap ticks ---
	ship.wave_turn_velocity = 0.0
	var turn_wave := _make_wave(Vector3(1.0, 0.0, 0.0), 2.0, 0.8, 0.0, 0.4)
	ship.simulate_wave_effects([turn_wave], 0.5)
	var first_turn: float = ship.wave_turn_velocity
	ship.simulate_wave_effects([turn_wave], 0.5)
	if ship.wave_turn_velocity > first_turn + 0.001:
		failures.append("continuous wave turn push should stay bounded instead of accumulating every frame")

	# --- WaveSensor exists to provide real Area3D overlap data in physics ticks ---
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		failures.append("wave sensor test requires the live SceneTree from the test harness")
	else:
		var parent := Node3D.new()
		scene_tree.root.add_child(parent)
		var overlap_ship = ShipControllerScript.new()
		overlap_ship.run_model = RunModelScript.new()
		overlap_ship.input_adapter = SteeringInputScript.new()
		overlap_ship.forward_speed = 10.0
		parent.add_child(overlap_ship)
		overlap_ship._build_visuals()
		var wave_sensor := overlap_ship.get_node_or_null("WaveSensor") as Area3D
		if wave_sensor == null:
			failures.append("ship should build a WaveSensor Area3D for wave overlap queries")
		elif not wave_sensor.monitoring:
			failures.append("WaveSensor should monitor overlapping wave areas")
		var overlap_wave = _make_wave(Vector3(1.0, 0.0, 0.0), 6.0, 0.5, 8.0, 0.2)
		overlap_wave.position = Vector3.ZERO
		parent.add_child(overlap_wave)
		overlap_wave._build_visuals()
		overlap_wave.monitoring = true
		overlap_wave.monitorable = true
		overlap_ship.simulate_tick_with_waves(1.0, 0.0, [overlap_wave])
		if overlap_ship.position_delta.x <= 0.0:
			failures.append("wave overlap data should apply lateral wave push")
		if -overlap_ship.position_delta.z >= 10.0:
			failures.append("wave overlap data should slow forward movement")
		if overlap_ship.run_model.damage <= 0.0:
			failures.append("wave overlap data should apply continuous wave damage")
		parent.queue_free()

	ship.free()

	return failures


func _make_wave(drift_direction: Vector3, lateral_force: float, speed_multiplier: float, damage_per_second: float, turn_push: float) -> WaveZone:
	var wave = WaveZoneScript.new()
	wave.drift_direction = drift_direction.normalized() if drift_direction.length() > 0.001 else Vector3.ZERO
	wave.lateral_force = lateral_force
	wave.speed_multiplier = speed_multiplier
	wave.damage_per_second = damage_per_second
	wave.turn_push = turn_push
	wave.is_large = damage_per_second > 0.0
	return wave
