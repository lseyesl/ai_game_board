class_name WaveZone
extends Area3D

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")

var turn_push: float = 0.0
var lateral_force: float = 0.0
var speed_multiplier: float = 1.0
var damage_per_second: float = 0.0
var is_large: bool = false
var spawner = null
var drift_velocity: Vector3 = Vector3.ZERO
var drift_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	monitoring = true
	_build_visuals()
	set_process(true)


func _process(delta: float) -> void:
	position += drift_velocity * delta


func configure(profile) -> void:
	turn_push = profile.turn_push
	lateral_force = profile.lateral_force
	speed_multiplier = profile.speed_multiplier
	damage_per_second = profile.damage_per_second
	is_large = profile.is_large
	_update_visuals()


func configure_drift(velocity: Vector3) -> void:
	drift_velocity = velocity
	if velocity.length() > 0.001:
		drift_direction = velocity.normalized()
	else:
		drift_direction = Vector3.ZERO
	_update_drift_arrow_rotation()


func reset_for_spawn(spawn_position: Vector3, profile) -> void:
	monitoring = true
	position = spawn_position
	configure(profile)
	set_process(true)


func deactivate_to_pool() -> void:
	monitoring = false
	drift_velocity = Vector3.ZERO
	drift_direction = Vector3.ZERO
	set_process(false)


func _build_visuals() -> void:
	if has_node("CollisionShape3D"):
		return

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4.5, 1.4, 7.0)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaveMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(4.5, 0.6, 7.0)
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("#87CEEB")
	material.albedo_color.a = 0.65
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.position.y = 0.3
	mesh_instance.visible = true
	add_child(mesh_instance)

	var arrow_instance := MeshInstance3D.new()
	arrow_instance.name = "DriftArrow"
	var arrow_mesh := BoxMesh.new()
	arrow_mesh.size = Vector3(0.6, 0.15, 2.0)
	arrow_instance.mesh = arrow_mesh
	var arrow_material := StandardMaterial3D.new()
	arrow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_material.albedo_color = Color("#FFFFFF")
	arrow_material.albedo_color.a = 0.9
	arrow_instance.set_surface_override_material(0, arrow_material)
	arrow_instance.position.y = 0.7
	add_child(arrow_instance)


func _update_visuals() -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance != null:
		var material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("#FF4444") if is_large else Color("#87CEEB")
			material.albedo_color.a = 0.75 if is_large else 0.55
		if is_large:
			mesh_instance.scale = Vector3(1.3, 1.5, 1.2)
		else:
			mesh_instance.scale = Vector3.ONE

	var collision_shape := get_node_or_null("CollisionShape3D")
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		if is_large:
			box.size = Vector3(5.8, 1.8, 8.4)
		else:
			box.size = Vector3(4.5, 1.4, 7.0)

	var arrow_instance := get_node_or_null("DriftArrow")
	if arrow_instance != null:
		var arrow_material := arrow_instance.get_active_material(0) as StandardMaterial3D
		if arrow_material != null:
			arrow_material.albedo_color = Color("#FFAAAA") if is_large else Color("#FFFFFF")
			arrow_material.albedo_color.a = 0.9


func _update_drift_arrow_rotation() -> void:
	var arrow_instance := get_node_or_null("DriftArrow")
	if arrow_instance == null:
		return
	if drift_direction.length() < 0.001:
		arrow_instance.visible = false
		return
	arrow_instance.visible = true
	var angle := atan2(drift_direction.x, drift_direction.z)
	arrow_instance.rotation_degrees.y = rad_to_deg(angle)


func set_debug_visible(vis: bool) -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance != null:
		mesh_instance.visible = vis
