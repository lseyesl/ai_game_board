class_name Sea
extends Node3D

var target: Node3D = null


func _ready() -> void:
	_build_mesh()


func _physics_process(_delta: float) -> void:
	if target != null:
		position.x = target.position.x
		position.z = target.position.z - 40.0
		_update_shader_center()


func _build_mesh() -> void:
	if has_node("SeaPlane"):
		return

	var sea_mesh := MeshInstance3D.new()
	sea_mesh.name = "SeaPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 420.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	sea_mesh.mesh = plane
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/water.gdshader")
	shader_material.set_shader_parameter("wave_speed", 1.0)
	shader_material.set_shader_parameter("wave_amplitude", 0.3)
	shader_material.set_shader_parameter("sun_direction", Vector3(0.5, 0.8, 0.3).normalized())
	shader_material.set_shader_parameter("sea_center", _get_shader_center())
	sea_mesh.set_surface_override_material(0, shader_material)
	add_child(sea_mesh)


func _update_shader_center() -> void:
	var sea_mesh := get_node_or_null("SeaPlane") as MeshInstance3D
	if sea_mesh == null:
		return
	var shader_material := sea_mesh.get_active_material(0) as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("sea_center", _get_shader_center())


func _get_shader_center() -> Vector3:
	return global_position if is_inside_tree() else position
