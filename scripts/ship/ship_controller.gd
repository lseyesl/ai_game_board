class_name ShipController
extends CharacterBody3D

const SteeringInputScript = preload("res://scripts/input/steering_input.gd")
const IslandRulesScript = preload("res://scripts/core/island_rules.gd")
const ShipRulesScript = preload("res://scripts/core/ship_rules.gd")

signal damage_taken(amount: float)
signal safe_zone_changed(in_safe_zone: bool)

@export var forward_speed: float = 18.0
@export var turn_speed: float = 1.7
@export var steering_smoothing: float = 5.0
@export var bob_strength: float = 0.15
@export var gravity: float = 18.0
@export var environment_push_damping: float = 4.0

var input_adapter = null
var run_model = null
var steering_axis_smoothed: float = 0.0
var position_delta: Vector3 = Vector3.ZERO
var wave_turn_velocity: float = 0.0
var wave_turn_damping: float = 2.8
var wave_vertical_velocity: float = 0.0
var environment_push_velocity: Vector3 = Vector3.ZERO
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
	if run_model != null and run_model.is_game_over():
		position_delta = Vector3.ZERO
		return

	steering_axis_smoothed = lerpf(steering_axis_smoothed, steering_input, clampf(delta * steering_smoothing, 0.0, 1.0))
	rotate_y(-(steering_axis_smoothed + wave_turn_velocity) * turn_speed * delta)
	wave_turn_velocity = move_toward(wave_turn_velocity, 0.0, wave_turn_damping * delta)

	if wave_vertical_velocity > 0.0 or position.y > base_y + 0.05:
		wave_vertical_velocity -= gravity * delta
		position.y += wave_vertical_velocity * delta
		if position.y <= base_y:
			position.y = base_y
			wave_vertical_velocity = 0.0
	else:
		var bob_offset := sin(Time.get_ticks_msec() * 0.004) * bob_strength
		position.y = base_y + bob_offset

	var forward_delta := -transform.basis.z.normalized() * forward_speed * delta
	var environment_delta := environment_push_velocity * delta
	position_delta = forward_delta + environment_delta
	position += position_delta
	environment_push_velocity = environment_push_velocity.lerp(
		Vector3.ZERO,
		clampf(delta * environment_push_damping, 0.0, 1.0)
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


func apply_wave_profile(profile) -> void:
	wave_turn_velocity += profile.turn_push
	if profile.lift_force > 0.0:
		wave_vertical_velocity = max(wave_vertical_velocity, profile.lift_force)

	if run_model == null:
		return

	var damage_amount: float = ShipRulesScript.apply_wave(run_model, profile, max(1.0, profile.lift_force / 4.0))
	if damage_amount > 0.0:
		damage_taken.emit(damage_amount)


func apply_environment_push(push_velocity: Vector3) -> void:
	environment_push_velocity += push_velocity


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
