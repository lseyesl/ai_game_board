extends RefCounted

const SeaScript = preload("res://scripts/world/sea.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	var sea = SeaScript.new()
	var target := Node3D.new()
	target.position = Vector3(25.0, 0.0, -600.0)
	sea.target = target
	sea._build_mesh()
	sea._physics_process(0.0)

	if not is_equal_approx(sea.position.x, target.position.x):
		failures.append("sea should follow target x position")
	if not is_equal_approx(sea.position.z, target.position.z - 40.0):
		failures.append("sea should stay offset ahead of target z position")

	var sea_mesh := sea.get_node_or_null("SeaPlane") as MeshInstance3D
	if sea_mesh == null:
		failures.append("sea should build a SeaPlane mesh")
	else:
		var material := sea_mesh.get_active_material(0) as ShaderMaterial
		if material == null:
			failures.append("SeaPlane should use a ShaderMaterial")
		else:
			var sea_center = material.get_shader_parameter("sea_center")
			if not (sea_center is Vector3):
				failures.append("water shader should receive sea_center so edge fade follows the moving sea")
			elif sea_center != sea.position:
				failures.append("water shader sea_center should match the moving sea position")

	var shader_file := FileAccess.open("res://shaders/water.gdshader", FileAccess.READ)
	if shader_file == null:
		failures.append("water shader file should be readable for visual style regression checks")
	else:
		var shader_source := shader_file.get_as_text()
		if shader_source.contains("step(0.5, spec)"):
			failures.append("water shader should avoid broad white cartoon specular blocks")
		if not shader_source.contains("foam_line"):
			failures.append("water shader should use narrow animated foam lines instead of large white areas")
		if not shader_source.contains("aqua_band"):
			failures.append("water shader should add aqua color banding for a more animated sea style")

	sea.free()
	target.free()

	return failures
