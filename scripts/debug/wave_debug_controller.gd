class_name WaveDebugController
extends Node3D

const SeaScript = preload("res://scripts/world/sea.gd")
const WaveSpawnerScript = preload("res://scripts/waves/wave_spawner.gd")
const WaveDebugCameraScript = preload("res://scripts/debug/wave_debug_camera.gd")
const WaveDebugPanelScript = preload("res://scripts/debug/wave_debug_panel.gd")

var sea = null
var wave_spawner = null
var debug_camera = null
var debug_panel = null
var ship_proxy: Node3D = null


func _ready() -> void:
	_build_environment()
	_build_scene()


func _process(_delta: float) -> void:
	if ship_proxy != null and debug_camera != null:
		if not debug_camera.follow_mode:
			ship_proxy.position = debug_camera.global_position + (-debug_camera.global_transform.basis.z.normalized()) * 50.0
			ship_proxy.position.y = 0.0


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#87CEEB")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFFFFF")
	env.ambient_light_energy = 1.1
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 2.0
	add_child(sun)


func _build_scene() -> void:
	ship_proxy = Node3D.new()
	ship_proxy.position = Vector3(0.0, 0.0, 0.0)
	add_child(ship_proxy)

	sea = SeaScript.new()
	sea.target = ship_proxy
	add_child(sea)

	wave_spawner = WaveSpawnerScript.new()
	wave_spawner.ship = ship_proxy
	add_child(wave_spawner)

	debug_camera = WaveDebugCameraScript.new()
	debug_camera.position = Vector3(0.0, 30.0, 40.0)
	debug_camera._target = ship_proxy
	add_child(debug_camera)

	debug_panel = WaveDebugPanelScript.new()
	debug_panel.wave_spawner = wave_spawner
	debug_panel.sea = sea
	add_child(debug_panel)

	debug_panel.param_changed.connect(_on_param_changed)


func _on_param_changed(param_name: String, value: float) -> void:
	match param_name:
		"wave_speed":
			if sea != null and sea.has_node("SeaPlane"):
				var mesh_inst := sea.get_node("SeaPlane") as MeshInstance3D
				if mesh_inst != null:
					var mat := mesh_inst.get_active_material(0) as ShaderMaterial
					if mat != null:
						mat.set_shader_parameter("wave_speed", value)
		"wave_amplitude":
			if sea != null and sea.has_node("SeaPlane"):
				var mesh_inst := sea.get_node("SeaPlane") as MeshInstance3D
				if mesh_inst != null:
					var mat := mesh_inst.get_active_material(0) as ShaderMaterial
					if mat != null:
						mat.set_shader_parameter("wave_amplitude", value)
		"large_chance":
			if wave_spawner != null:
				wave_spawner.large_wave_chance = value
		"spawn_distance":
			if wave_spawner != null:
				wave_spawner.spawn_distance_ahead = value
