class_name WaveZone
extends Area3D

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")

var turn_push: float = 0.0
var lift_force: float = 0.0
var damage_risk: float = 0.0
var is_large: bool = false
var consumed: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visuals()


func configure(profile) -> void:
	turn_push = profile.turn_push
	lift_force = profile.lift_force
	damage_risk = profile.damage_risk
	is_large = profile.is_large


func _on_body_entered(body: Node) -> void:
	if consumed:
		return
	if body is ShipControllerScript:
		var profile = WaveProfileScript.large(turn_push) if is_large else WaveProfileScript.small(turn_push)
		profile.lift_force = lift_force
		profile.damage_risk = damage_risk
		body.apply_wave_profile(profile)
		consumed = true
		queue_free()


func _build_visuals() -> void:
	if has_node("CollisionShape3D"):
		return

	var collision_shape := CollisionShape3D.new()
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
	material.albedo_color = Color("#62B6CB") if not is_large else Color("#1B4965")
	material.albedo_color.a = 0.65
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.position.y = 0.3
	add_child(mesh_instance)
