class_name Sea
extends Node3D

var target: Node3D = null


func _ready() -> void:
	_build_mesh()


func _physics_process(_delta: float) -> void:
	if target != null:
		position.x = target.position.x
		position.z = target.position.z - 40.0


func _build_mesh() -> void:
	if has_node("SeaPlane"):
		return

	var sea_mesh := MeshInstance3D.new()
	sea_mesh.name = "SeaPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 420.0)
	sea_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#5FA8D3")
	material.roughness = 0.15
	material.metallic = 0.0
	sea_mesh.set_surface_override_material(0, material)
	add_child(sea_mesh)
