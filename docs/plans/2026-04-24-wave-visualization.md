# Wave Visualization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add debug visualization for wave zones + a standalone debug scene for observing sea/wave state.

**Architecture:** Two deliverables — (A) in-game debug overlay toggled by F1/F2, (B) standalone `wave_debug.tscn` scene with free-flight camera and live parameter controls. Both reuse existing `Sea`, `WaveSpawner`, `WaveZone` without changing collision logic or shaders.

**Tech Stack:** Godot 4 / GDScript, existing custom SceneTree test harness.

---

### Task 1: Enable WaveZone Debug Visibility + Consumed Fadeout

**Files:**
- Modify: `scripts/waves/wave_zone.gd`
- Test: `tests/unit/test_wave_profile.gd` (read-only, verify existing still passes)

**Step 1: Modify `_build_visuals()` to default visible = true**

In `scripts/waves/wave_zone.gd`, change line 91:

```gdscript
# BEFORE:
mesh_instance.visible = false

# AFTER:
mesh_instance.visible = true
```

**Step 2: Add consumed fadeout in `_on_body_entered()`**

After `consumed = true` on line 62, add fadeout before pool release:

```gdscript
func _on_body_entered(body: Node3D) -> void:
	if consumed:
		return
	if body is ShipControllerScript:
		var profile = WaveProfileScript.large(turn_push) if is_large else WaveProfileScript.small(turn_push)
		profile.lift_force = lift_force
		profile.damage_risk = damage_risk
		body.apply_wave_profile(profile)
		consumed = true
		_fade_out_consumed()
		if spawner != null and spawner.has_method("release_wave_to_pool"):
			spawner.release_wave_to_pool(self)
		else:
			queue_free()
```

**Step 3: Add `_fade_out_consumed()` method**

```gdscript
func _fade_out_consumed() -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance == null:
		return
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = Color("#888888")
	material.albedo_color.a = 0.25
```

**Step 4: Add `set_debug_visible()` toggle method**

```gdscript
func set_debug_visible(vis: bool) -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance != null:
		mesh_instance.visible = vis
```

**Step 5: Run existing tests to verify no regressions**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `ALL TESTS PASSED`

**Step 6: Commit**

```bash
git add scripts/waves/wave_zone.gd
git commit -m "feat: enable wave zone debug visuals with consumed fadeout and toggle method"
```

---

### Task 2: Create DebugOverlay Controller

**Files:**
- Create: `scripts/debug/debug_overlay.gd`
- Modify: `scripts/main/main.gd`

**Step 1: Create `scripts/debug/debug_overlay.gd`**

```gdscript
class_name DebugOverlay
extends Node

var wave_zones_visible := true
var stats_panel_visible := true
var wave_spawner: WaveSpawner = null

var _stats_label: Label = null
var _canvas: CanvasLayer = null


func _ready() -> void:
	set_process_unhandled_input(true)
	_build_stats_panel()


func _process(_delta: float) -> void:
	if _stats_label == null or not stats_panel_visible:
		return
	if wave_spawner == null:
		return

	var active_count := 0
	var large_count := 0
	var pool_size := wave_spawner.get_inactive_pool_size()
	for child in wave_spawner.get_children():
		if child is Area3D:
			active_count += 1
			if child.is_large:
				large_count += 1

	var furthest := wave_spawner._furthest_ahead_distance
	var large_ratio := float(large_count) / float(maxi(active_count, 1)) * 100.0
	_stats_label.text = (
		"Waves: %d active / %d pooled\n"
		"Large: %d (%.0f%%)\n"
		"Furthest ahead: %.0fm\n"
		"[F1] Toggle zones  [F2] Toggle stats"
	) % [active_count, pool_size, large_count, large_ratio, furthest]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_toggle_wave_zones()
		elif event.keycode == KEY_F2:
			_toggle_stats_panel()


func _toggle_wave_zones() -> void:
	wave_zones_visible = not wave_zones_visible
	if wave_spawner == null:
		return
	for child in wave_spawner.get_children():
		if child.has_method("set_debug_visible"):
			child.set_debug_visible(wave_zones_visible)


func _toggle_stats_panel() -> void:
	stats_panel_visible = not stats_panel_visible
	if _canvas != null:
		_canvas.visible = stats_panel_visible


func _build_stats_panel() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_canvas.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	margin.add_child(vbox)

	# Push to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	_stats_label.add_theme_stylebox_override("normal", bg)
	vbox.add_child(_stats_label)
```

**Step 2: Integrate DebugOverlay into `scripts/main/main.gd`**

Add after line 9 (const declarations):

```gdscript
const DebugOverlayScript = preload("res://scripts/debug/debug_overlay.gd")
```

Add after line 17 (var declarations):

```gdscript
var debug_overlay = null
```

In `_build_gameplay()`, add after `wave_spawner.run_model = run_model` (line 84):

```gdscript
debug_overlay = DebugOverlayScript.new()
debug_overlay.wave_spawner = wave_spawner
add_child(debug_overlay)
```

**Step 3: Run existing tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `ALL TESTS PASSED`

**Step 4: Commit**

```bash
git add scripts/debug/debug_overlay.gd scripts/main/main.gd
git commit -m "feat: add in-game debug overlay with F1/F2 toggle for wave zones and stats"
```

---

### Task 3: Create Free-Flight Debug Camera

**Files:**
- Create: `scripts/debug/wave_debug_camera.gd`

**Step 1: Create `scripts/debug/wave_debug_camera.gd`**

```gdscript
class_name WaveDebugCamera
extends Node3D

var move_speed: float = 20.0
var look_speed: float = 0.003
var camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = -0.5
var _captured := false
var _velocity := Vector3.ZERO
var _target: Node3D = null
var follow_mode := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	add_child(camera)
	_reset_orientation()


func _reset_orientation() -> void:
	_yaw = 0.0
	_pitch = -0.5
	_update_rotation()


func _update_rotation() -> void:
	rotation = Vector3.ZERO
	rotate_y(_yaw)
	rotate_object_local(Vector3.RIGHT, _pitch)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_captured = true
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				_captured = false

	if event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * look_speed
		_pitch -= event.relative.y * look_speed
		_pitch = clampf(_pitch, -PI / 2.0 + 0.05, PI / 2.0 - 0.05)
		_update_rotation()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			follow_mode = not follow_mode


func _process(delta: float) -> void:
	if follow_mode and _target != null:
		global_position = _target.global_position + Vector3(0.0, 30.0, 0.0)
		look_at(_target.global_position, Vector3.UP)
		return

	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1.0

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 3.0

	var direction := (transform.basis * input_dir).normalized()
	_velocity = _velocity.move_toward(direction * speed, delta * 10.0)
	position += _velocity * delta
```

**Step 2: Commit**

```bash
git add scripts/debug/wave_debug_camera.gd
git commit -m "feat: add free-flight debug camera for standalone wave debug scene"
```

---

### Task 4: Create Wave Debug Panel (Controls + Stats)

**Files:**
- Create: `scripts/debug/wave_debug_panel.gd`

**Step 1: Create `scripts/debug/wave_debug_panel.gd`**

```gdscript
class_name WaveDebugPanel
extends CanvasLayer

signal param_changed(param_name: String, value: float)

var wave_spawner: WaveSpawner = null
var sea: Sea = null
var _paused := false
var _stats_label: Label = null
var _sliders: Dictionary = {}


func _ready() -> void:
	layer = 100
	_build_panel()


func _process(_delta: float) -> void:
	_update_stats()


func is_paused() -> bool:
	return _paused


func _update_stats() -> void:
	if _stats_label == null or wave_spawner == null:
		return

	var active_count := 0
	var large_count := 0
	var pool_size := wave_spawner.get_inactive_pool_size()
	for child in wave_spawner.get_children():
		if child is Area3D:
			active_count += 1
			if child.is_large:
				large_count += 1

	var large_ratio := float(large_count) / float(maxi(active_count, 1)) * 100.0
	_stats_label.text = (
		"Active: %d | Pooled: %d | Large: %d (%.0f%%)\n"
		"Furthest: %.0fm | %s"
	) % [
		active_count, pool_size, large_count, large_ratio,
		wave_spawner._furthest_ahead_distance,
		"PAUSED" if _paused else "RUNNING"
	]


func _build_panel() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	vbox.add_child(margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(panel_vbox)

	# Stats
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_add_bg(_stats_label)
	panel_vbox.add_child(_stats_label)

	# Sliders
	_add_slider(panel_vbox, "wave_speed", "Wave Speed", 0.1, 3.0, 1.0)
	_add_slider(panel_vbox, "wave_amplitude", "Wave Amplitude", 0.05, 1.0, 0.3)
	_add_slider(panel_vbox, "large_chance", "Large Wave %", 0.0, 1.0, 0.28)
	_add_slider(panel_vbox, "spawn_distance", "Spawn Distance", 30.0, 200.0, 100.0)

	# Pause button
	var pause_btn := Button.new()
	pause_btn.text = "Pause [Space]"
	pause_btn.pressed.connect(_toggle_pause)
	panel_vbox.add_child(pause_btn)

	# Follow camera toggle info
	var info := Label.new()
	info.text = "[F] Toggle follow mode | [Space] Pause | Click+Drag to orbit"
	info.add_theme_font_size_override("font_size", 14)
	info.modulate.a = 0.7
	panel_vbox.add_child(info)


func _add_slider(parent: VBoxContainer, id: String, label_text: String, min_val: float, max_val: float, default: float) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200.0, 0.0)
	hbox.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%.2f" % default
	val_label.custom_minimum_size = Vector2(50.0, 0.0)
	val_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(val_label)

	slider.value_changed.connect(func(val: float):
		val_label.text = "%.2f" % val
		param_changed.emit(id, val)
	)
	_sliders[id] = slider


func _add_bg(label: Label) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", bg)


func _toggle_pause() -> void:
	_paused = not _paused
	if wave_spawner != null:
		wave_spawner.set_process(not _paused)
	get_tree().paused = _paused
```

**Step 2: Commit**

```bash
git add scripts/debug/wave_debug_panel.gd
git commit -m "feat: add wave debug panel with sliders and stats display"
```

---

### Task 5: Create Wave Debug Scene Controller

**Files:**
- Create: `scripts/debug/wave_debug_controller.gd`

**Step 1: Create `scripts/debug/wave_debug_controller.gd`**

```gdscript
class_name WaveDebugController
extends Node3D

const SeaScript = preload("res://scripts/world/sea.gd")
const WaveSpawnerScript = preload("res://scripts/waves/wave_spawner.gd")
const WaveDebugCameraScript = preload("res://scripts/debug/wave_debug_camera.gd")
const WaveDebugPanelScript = preload("res://scripts/debug/wave_debug_panel.gd")

var sea: Sea = null
var wave_spawner: WaveSpawner = null
var debug_camera: WaveDebugCamera = null
var debug_panel: WaveDebugPanel = null
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
	# Ship proxy (invisible, just for spawner to track)
	ship_proxy = Node3D.new()
	ship_proxy.position = Vector3(0.0, 0.0, 0.0)
	add_child(ship_proxy)

	# Sea surface
	sea = SeaScript.new()
	sea.target = ship_proxy
	add_child(sea)

	# Wave spawner
	wave_spawner = WaveSpawnerScript.new()
	wave_spawner.ship = ship_proxy
	add_child(wave_spawner)

	# Debug camera
	debug_camera = WaveDebugCameraScript.new()
	debug_camera.position = Vector3(0.0, 30.0, 40.0)
	debug_camera._target = ship_proxy
	add_child(debug_camera)

	# Debug panel
	debug_panel = WaveDebugPanelScript.new()
	debug_panel.wave_spawner = wave_spawner
	debug_panel.sea = sea
	add_child(debug_panel)

	# Wire panel params
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
```

**Step 2: Commit**

```bash
git add scripts/debug/wave_debug_controller.gd
git commit -m "feat: add wave debug controller orchestrating standalone debug scene"
```

---

### Task 6: Create Standalone Debug Scene

**Files:**
- Create: `scenes/debug/wave_debug.tscn`

**Step 1: Create the .tscn file**

```godot
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/debug/wave_debug_controller.gd" id="1"]

[node name="WaveDebug" type="Node3D"]
script = ExtResource("1")
```

**Step 2: Add to project as runnable scene**

No project.godot change needed — user can run with:
`godot --path . scenes/debug/wave_debug.tscn`

**Step 3: Verify scene loads without errors**

Run: `godot --headless --path . scenes/debug/wave_debug.tscn`
Expected: No parse errors, scene exits cleanly (headless can't render but script parsing should succeed)

**Step 4: Commit**

```bash
git add scenes/debug/wave_debug.tscn
git commit -m "feat: add standalone wave debug scene for sea/wave observation"
```

---

### Task 7: Add Debug Overlay Test

**Files:**
- Create: `tests/unit/test_debug_overlay.gd`
- Modify: `tests/run_tests.gd`

**Step 1: Create `tests/unit/test_debug_overlay.gd`**

```gdscript
extends RefCounted

const DebugOverlayScript = preload("res://scripts/debug/debug_overlay.gd")
const WaveSpawnerScript = preload("res://scripts/waves/wave_spawner.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	var overlay = DebugOverlayScript.new()
	if not overlay.has_method("set_debug_visible") and not overlay.has_method("_toggle_wave_zones"):
		failures.append("debug overlay should expose wave zone toggle capability")

	if not overlay.has_method("_toggle_stats_panel"):
		failures.append("debug overlay should expose stats panel toggle capability")

	# Verify initial state
	if not overlay.wave_zones_visible:
		failures.append("wave zones should be visible by default in debug overlay")
	if not overlay.stats_panel_visible:
		failures.append("stats panel should be visible by default in debug overlay")

	overlay.free()
	return failures
```

**Step 2: Register test in `tests/run_tests.gd`**

Add to the `TEST_FILES` array (after line 14):

```gdscript
"res://tests/unit/test_debug_overlay.gd",
```

**Step 3: Run full test suite**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `ALL TESTS PASSED`

**Step 4: Commit**

```bash
git add tests/unit/test_debug_overlay.gd tests/run_tests.gd
git commit -m "test: add debug overlay unit test and register in test runner"
```

---

### Task 8: Final Verification

**Step 1: Run full test suite**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `ALL TESTS PASSED`

**Step 2: Run the game to verify F1/F2 toggles work**

Run: `godot --path .`
Manual check: F1 toggles wave zone boxes, F2 toggles stats panel at bottom of screen.

**Step 3: Run the debug scene**

Run: `godot --path . scenes/debug/wave_debug.tscn`
Manual check: Sea surface visible, wave zones appear, WASD moves camera, sliders adjust params.
