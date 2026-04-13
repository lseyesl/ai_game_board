class_name Island
extends Area3D

const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")

@export var repair_rate: float = 12.0


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visuals()


func _on_body_entered(body: Node) -> void:
	if body is ShipControllerScript:
		body.enter_safe_zone(repair_rate)


func _on_body_exited(body: Node) -> void:
	if body is ShipControllerScript:
		body.exit_safe_zone(repair_rate)


func _build_visuals() -> void:
	if has_node("CollisionShape3D"):
		return

	var collision_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 6.0
	cylinder.height = 2.0
	collision_shape.shape = cylinder
	add_child(collision_shape)

	var island_mesh := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 2.5
	top_mesh.bottom_radius = 3.4
	top_mesh.height = 1.8
	island_mesh.mesh = top_mesh
	var island_material := StandardMaterial3D.new()
	island_material.albedo_color = Color("#6A994E")
	island_mesh.set_surface_override_material(0, island_material)
	island_mesh.position.y = 0.9
	add_child(island_mesh)

	var shore_mesh := MeshInstance3D.new()
	var shore_cylinder := CylinderMesh.new()
	shore_cylinder.top_radius = 6.0
	shore_cylinder.bottom_radius = 6.0
	shore_cylinder.height = 0.12
	shore_mesh.mesh = shore_cylinder
	var shore_material := StandardMaterial3D.new()
	shore_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shore_material.albedo_color = Color("#BEE9E8")
	shore_material.albedo_color.a = 0.45
	shore_mesh.set_surface_override_material(0, shore_material)
	shore_mesh.position.y = 0.06
	add_child(shore_mesh)
