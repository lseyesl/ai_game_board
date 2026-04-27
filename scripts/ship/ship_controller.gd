class_name ShipController
extends CharacterBody3D

const SteeringInputScript = preload("res://scripts/input/steering_input.gd")
const IslandRulesScript = preload("res://scripts/core/island_rules.gd")

signal damage_taken(amount: float)
signal safe_zone_changed(in_safe_zone: bool)

@export var forward_speed: float = 18.0
@export var turn_speed: float = 1.7
@export var steering_smoothing: float = 5.0
@export var bob_strength: float = 0.4
@export var pitch_strength: float = 2.5
@export var roll_strength: float = 1.8
@export var gravity: float = 18.0

var input_adapter = null
var run_model = null
var steering_axis_smoothed: float = 0.0
var position_delta: Vector3 = Vector3.ZERO
var wave_turn_velocity: float = 0.0
var wave_turn_damping: float = 2.8
var wave_lateral_velocity: Vector3 = Vector3.ZERO
var wave_lateral_damping: float = 3.0
var wave_speed_multiplier: float = 1.0
var current_push_velocity: Vector3 = Vector3.ZERO
var base_y: float = 0.0
var current_repair_rate: float = 0.0
var safe_zone_count: int = 0


func _ready() -> void:
	if input_adapter == null:
		input_adapter = SteeringInputScript.new()
	base_y = position.y
	_build_visuals()


func _physics_process(delta: float) -> void:
	if input_adapter == null:
		input_adapter = SteeringInputScript.new()
	simulate_tick(delta, input_adapter.get_steering_axis())


func simulate_tick(delta: float, steering_input: float) -> void:
	simulate_tick_with_waves(delta, steering_input, get_overlapping_areas())


func simulate_tick_with_waves(delta: float, steering_input: float, overlapping: Array) -> void:
	if run_model != null and run_model.is_game_over():
		position_delta = Vector3.ZERO
		return

	simulate_wave_effects(overlapping, delta)

	steering_axis_smoothed = lerpf(steering_axis_smoothed, steering_input, clampf(delta * steering_smoothing, 0.0, 1.0))
	rotate_y(-(steering_axis_smoothed + wave_turn_velocity) * turn_speed * delta)
	wave_turn_velocity = move_toward(wave_turn_velocity, 0.0, wave_turn_damping * delta)

	var t := Time.get_ticks_msec() / 1000.0
	var speed_factor := clampf(forward_speed / 18.0, 0.3, 1.5)
	var bob_offset := (sin(t * 2.0) + sin(t * 3.7) * 0.3 + sin(t * 0.8) * 0.5) * bob_strength * speed_factor
	var bob_y := base_y + bob_offset
	position.y = bob_y

	var pitch := sin(t * 2.0 + 0.5) * pitch_strength * speed_factor
	var roll := sin(t * 1.3 + 1.0) * roll_strength * speed_factor
	_apply_boat_tilt(pitch, roll)

	var forward_delta := -transform.basis.z.normalized() * forward_speed * wave_speed_multiplier * delta
	var lateral_delta := (wave_lateral_velocity + current_push_velocity) * delta
	position_delta = forward_delta + lateral_delta
	position += position_delta
	current_push_velocity = current_push_velocity.lerp(
		Vector3.ZERO,
		clampf(delta * wave_lateral_damping, 0.0, 1.0)
	)

	if run_model != null:
		run_model.advance_distance(position_delta.length())
		if safe_zone_count > 0:
			run_model.invulnerable = true
			run_model.repairing = true
			IslandRulesScript.apply_repair(run_model, current_repair_rate, delta)
		else:
			run_model.invulnerable = false
			run_model.repairing = false


func simulate_wave_effects(overlapping: Array, delta: float) -> void:
	var net_lateral := Vector3.ZERO
	var min_speed_multiplier := 1.0
	var total_damage := 0.0
	var total_turn_push := 0.0
	var has_wave_overlap := false

	for area in overlapping:
		if area is WaveZone:
			var wave: WaveZone = area
			has_wave_overlap = true
			if wave.drift_direction.length() > 0.001:
				net_lateral += wave.drift_direction * wave.lateral_force
			min_speed_multiplier = minf(min_speed_multiplier, wave.speed_multiplier)
			total_damage += wave.damage_per_second * delta
			total_turn_push += wave.turn_push

	wave_speed_multiplier = min_speed_multiplier if has_wave_overlap else 1.0
	wave_turn_velocity = total_turn_push

	if net_lateral.length() > 0.001:
		wave_lateral_velocity = net_lateral
	else:
		wave_lateral_velocity = wave_lateral_velocity.lerp(
			Vector3.ZERO,
			clampf(delta * wave_lateral_damping, 0.0, 1.0)
		)

	if total_damage > 0.0 and run_model != null and not run_model.invulnerable:
		var applied: float = run_model.add_damage(total_damage)
		if applied > 0.0:
			damage_taken.emit(applied)


func get_overlapping_areas() -> Array[Area3D]:
	var wave_sensor := get_node_or_null("WaveSensor") as Area3D
	if wave_sensor == null:
		return []
	return wave_sensor.get_overlapping_areas()


func apply_environment_push(push_velocity: Vector3) -> void:
	current_push_velocity += push_velocity


func _apply_boat_tilt(pitch_deg: float, roll_deg: float) -> void:
	var boat_model := get_node_or_null("BoatModel")
	if boat_model == null:
		return
	boat_model.rotation_degrees.x = pitch_deg
	boat_model.rotation_degrees.z = roll_deg


func enter_safe_zone(repair_rate: float) -> void:
	safe_zone_count += 1
	current_repair_rate = max(current_repair_rate, repair_rate)
	if run_model != null:
		run_model.invulnerable = IslandRulesScript.enter_island(run_model.invulnerable)
		run_model.repairing = true
		safe_zone_changed.emit(true)


func exit_safe_zone(_repair_rate: float) -> void:
	safe_zone_count = max(0, safe_zone_count - 1)
	if safe_zone_count == 0:
		current_repair_rate = 0.0
		if run_model != null:
			run_model.invulnerable = IslandRulesScript.exit_island(run_model.invulnerable)
			run_model.repairing = false
		safe_zone_changed.emit(false)


func _build_visuals() -> void:
	if has_node("CollisionShape3D"):
		return

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.1, 0.8, 2.6)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	var wave_sensor := Area3D.new()
	wave_sensor.name = "WaveSensor"
	wave_sensor.monitoring = true
	wave_sensor.monitorable = false
	var sensor_shape := CollisionShape3D.new()
	var sensor_box := BoxShape3D.new()
	sensor_box.size = Vector3(1.2, 1.0, 2.8)
	sensor_shape.shape = sensor_box
	wave_sensor.add_child(sensor_shape)
	add_child(wave_sensor)

	var boat_scene = load("res://assets/board.glb")
	if boat_scene == null:
		return
	var boat_model = boat_scene.instantiate()
	boat_model.name = "BoatModel"
	boat_model.position = Vector3(0.0, 0.0, 0.0)
	boat_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	boat_model.scale = Vector3(4.0, 4.0, 4.0)
	_promote_visual_priority(boat_model)
	add_child(boat_model)


func _promote_visual_priority(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		overlay.render_priority = 127
		overlay.no_depth_test = true
		mesh_instance.material_overlay = overlay

	for child in node.get_children():
		_promote_visual_priority(child)
