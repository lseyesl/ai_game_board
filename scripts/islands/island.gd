class_name Island
extends Area3D

const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")

@export var repair_rate: float = 12.0
@export var safe_radius: float = 6.0
@export var current_radius: float = 13.0
@export var current_push_strength: float = 8.5

var current_bodies: Array[ShipControllerScript] = []
@onready var safe_collision: CollisionShape3D = get_node_or_null("SafeCollision")
@onready var current_area: Area3D = get_node_or_null("CurrentArea")
@onready var current_collision: CollisionShape3D = get_node_or_null("CurrentArea/CurrentCollision")
@onready var shore_mesh: MeshInstance3D = get_node_or_null("ShoreMesh")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sync_scene_setup()
	if current_area != null:
		current_area.monitoring = true
		current_area.body_entered.connect(_on_current_body_entered)
		current_area.body_exited.connect(_on_current_body_exited)


func _physics_process(delta: float) -> void:
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
	if body is ShipControllerScript:
		body.enter_safe_zone(repair_rate)


func _on_body_exited(body: Node) -> void:
	if body is ShipControllerScript:
		body.exit_safe_zone(repair_rate)


func _on_current_body_entered(body: Node) -> void:
	if body is ShipControllerScript and not current_bodies.has(body):
		current_bodies.append(body)


func _on_current_body_exited(body: Node) -> void:
	if body is ShipControllerScript:
		current_bodies.erase(body)


func calculate_current_push(body_position: Vector3, delta: float) -> Vector3:
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

	if shore_mesh != null and shore_mesh.mesh is CylinderMesh:
		var shore_cylinder := shore_mesh.mesh as CylinderMesh
		shore_cylinder.top_radius = safe_radius
		shore_cylinder.bottom_radius = safe_radius
		shore_cylinder.height = 0.12
