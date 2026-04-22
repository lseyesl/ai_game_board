class_name Island
extends Area3D

const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")

@export var repair_rate: float = 12.0
@export var safe_radius: float = 6.0
@export var current_radius: float = 13.0
@export var current_push_strength: float = 8.5
@export var preview_scale_max: float = 1.08

var is_preview: bool = false
var reveal_ratio: float = 1.0

var safe_bodies: Array[ShipControllerScript] = []
var current_bodies: Array[ShipControllerScript] = []
@onready var safe_collision: CollisionShape3D = get_node_or_null("SafeCollision")
@onready var current_area: Area3D = get_node_or_null("CurrentArea")
@onready var current_collision: CollisionShape3D = get_node_or_null("CurrentArea/CurrentCollision")
@onready var island_model: Node3D = get_node_or_null("IslandModel")
@onready var shore_mesh: MeshInstance3D = get_node_or_null("ShoreMesh")
@onready var shore_material: StandardMaterial3D = _resolve_shore_material()

var _base_island_model_scale: Vector3 = Vector3.ONE
var _base_shore_scale: Vector3 = Vector3.ONE
var _shore_base_color: Color = Color(0.745098, 0.913725, 0.909804, 0.45)


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if island_model != null:
		_base_island_model_scale = island_model.scale
	if shore_mesh != null:
		_base_shore_scale = shore_mesh.scale
	if shore_material != null:
		_shore_base_color = shore_material.albedo_color
	_sync_scene_setup()
	if current_area != null:
		current_area.monitoring = not is_preview
		current_area.body_entered.connect(_on_current_body_entered)
		current_area.body_exited.connect(_on_current_body_exited)
	_apply_reveal_visuals()


func _physics_process(delta: float) -> void:
	if is_preview:
		return
	for index in range(current_bodies.size() - 1, -1, -1):
		var body := current_bodies[index]
		if not is_instance_valid(body):
			current_bodies.remove_at(index)
			continue
		var push_velocity := calculate_current_push(body.global_position, delta)
		if push_velocity == Vector3.ZERO:
			continue
		body.apply_environment_push(push_velocity)


func _on_body_entered(body: Node) -> void:
	if is_preview:
		return
	if body is ShipControllerScript:
		if not safe_bodies.has(body):
			safe_bodies.append(body)
		body.enter_safe_zone(repair_rate)


func _on_body_exited(body: Node) -> void:
	if is_preview:
		return
	if body is ShipControllerScript:
		safe_bodies.erase(body)
		body.exit_safe_zone(repair_rate)


func _on_current_body_entered(body: Node) -> void:
	if is_preview:
		return
	if body is ShipControllerScript and not current_bodies.has(body):
		current_bodies.append(body)


func _on_current_body_exited(body: Node) -> void:
	if body is ShipControllerScript:
		current_bodies.erase(body)


func set_preview_state(value: bool) -> void:
	is_preview = value
	if is_preview:
		for body in safe_bodies:
			if is_instance_valid(body):
				body.exit_safe_zone(repair_rate)
		safe_bodies.clear()
		current_bodies.clear()
	_sync_scene_setup()


func update_reveal_state(value: float) -> void:
	reveal_ratio = clampf(value, 0.0, 1.0)
	_apply_reveal_visuals()


func update_reveal_from_distance(distance: float, reveal_distance: float) -> void:
	if reveal_distance <= 0.0:
		update_reveal_state(1.0)
		return
	update_reveal_state(1.0 - clampf(distance / reveal_distance, 0.0, 1.0))


func deactivate_to_pool() -> void:
	for body in safe_bodies:
		if is_instance_valid(body):
			body.exit_safe_zone(repair_rate)
	safe_bodies.clear()
	current_bodies.clear()


func reset_for_spawn(spawn_position: Vector3, next_repair_rate: float = repair_rate) -> void:
	deactivate_to_pool()
	position = spawn_position
	repair_rate = next_repair_rate
	update_reveal_state(1.0)
	set_preview_state(false)


func calculate_current_push(body_position: Vector3, delta: float) -> Vector3:
	if is_preview:
		return Vector3.ZERO
	var island_position := global_position if is_inside_tree() else position
	var horizontal_offset := body_position - island_position
	horizontal_offset.y = 0.0
	var distance := horizontal_offset.length()
	if distance <= safe_radius or distance > current_radius or is_zero_approx(distance):
		return Vector3.ZERO

	var ring_depth: float = maxf(current_radius - safe_radius, 0.001)
	var edge_ratio: float = 1.0 - ((distance - safe_radius) / ring_depth)
	return horizontal_offset.normalized() * current_push_strength * edge_ratio * delta


func _sync_scene_setup() -> void:
	if safe_collision != null and safe_collision.shape is CylinderShape3D:
		var safe_cylinder := safe_collision.shape as CylinderShape3D
		safe_cylinder.radius = safe_radius
		safe_cylinder.height = 2.0

	if current_collision != null and current_collision.shape is CylinderShape3D:
		var current_cylinder := current_collision.shape as CylinderShape3D
		current_cylinder.radius = current_radius
		current_cylinder.height = 2.0
		current_collision.disabled = is_preview

	if safe_collision != null:
		safe_collision.disabled = is_preview

	if current_area != null:
		current_area.monitoring = not is_preview

	if shore_mesh != null and shore_mesh.mesh is CylinderMesh:
		var shore_cylinder := shore_mesh.mesh as CylinderMesh
		shore_cylinder.top_radius = safe_radius
		shore_cylinder.bottom_radius = safe_radius
		shore_cylinder.height = 0.12

	_apply_reveal_visuals()


func _apply_reveal_visuals() -> void:
	var visual_ratio := reveal_ratio
	if not is_preview:
		visual_ratio = 1.0

	var scaled_ratio := lerpf(preview_scale_max, 1.0, visual_ratio)
	if island_model != null:
		island_model.scale = _base_island_model_scale * scaled_ratio

	if shore_mesh != null:
		shore_mesh.scale = Vector3(_base_shore_scale.x * scaled_ratio, _base_shore_scale.y, _base_shore_scale.z * scaled_ratio)

	if shore_material != null:
		var color := _shore_base_color
		color.a = _shore_base_color.a * visual_ratio
		shore_material.albedo_color = color


func _resolve_shore_material() -> StandardMaterial3D:
	if shore_mesh == null:
		return null

	var surface_material := shore_mesh.get_active_material(0)
	if surface_material is StandardMaterial3D:
		var material_copy := (surface_material as StandardMaterial3D).duplicate()
		shore_mesh.set_surface_override_material(0, material_copy)
		return material_copy

	return null
