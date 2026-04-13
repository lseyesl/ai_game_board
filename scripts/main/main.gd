extends Node3D

const RunModelScript = preload("res://scripts/core/run_model.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const SeaScript = preload("res://scripts/world/sea.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const CameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const WaveSpawnerScript = preload("res://scripts/waves/wave_spawner.gd")
const IslandSpawnerScript = preload("res://scripts/islands/island_spawner.gd")

var run_model = RunModelScript.new()
var ship = null
var sea = null
var hud = null
var camera_rig = null
var wave_spawner = null
var island_spawner = null


func _ready() -> void:
	randomize()
	_build_environment()
	_build_gameplay()


func _process(_delta: float) -> void:
	if run_model.is_game_over() and (Input.is_action_just_pressed("ui_accept") or Input.is_anything_pressed()):
		get_tree().reload_current_scene()


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


func _build_gameplay() -> void:
	sea = SeaScript.new()
	add_child(sea)

	ship = ShipControllerScript.new()
	ship.run_model = run_model
	ship.position = Vector3(0.0, 0.0, 0.0)
	add_child(ship)
	ship.damage_taken.connect(_on_ship_damage_taken)

	sea.target = ship

	camera_rig = CameraRigScript.new()
	camera_rig.target = ship
	add_child(camera_rig)
	camera_rig.position = Vector3(0.0, 8.0, 14.0)

	wave_spawner = WaveSpawnerScript.new()
	wave_spawner.ship = ship
	wave_spawner.run_model = run_model
	add_child(wave_spawner)

	island_spawner = IslandSpawnerScript.new()
	island_spawner.ship = ship
	island_spawner.run_model = run_model
	add_child(island_spawner)

	hud = HUDScript.new()
	hud.set_run_model(run_model)
	add_child(hud)


func _on_ship_damage_taken(amount: float) -> void:
	if amount <= 0.0:
		return
	hud.flash_damage()
	camera_rig.request_bump(minf(0.75, amount / 20.0))
