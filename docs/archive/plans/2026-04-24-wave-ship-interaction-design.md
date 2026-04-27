# Wave-Ship Continuous Area Interaction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign wave-ship interaction so waves are persistent area zones that continuously deflect, slow, and damage the ship, with the ship actively querying overlapping waves each frame.

**Architecture:** ShipController uses `get_overlapping_areas()` per frame to find WaveZone instances, computes net lateral push, speed reduction, and DPS damage from all overlapping waves. WaveZone becomes a passive data node — no longer calls `apply_wave_profile` on the ship. WaveProfile gains `lateral_force`, `speed_multiplier`, `damage_per_second`, `drift_direction`.

**Tech Stack:** Godot 4 / GDScript, custom SceneTree test harness (`tests/run_tests.gd`)

**Design doc:** `docs/plans/2026-04-24-wave-ship-interaction-design.md`

---

### Task 1: Redesign WaveProfile with new continuous-effect fields

**Files:**

- Modify: `scripts/waves/wave_profile.gd`
- Modify: `tests/unit/test_wave_profile.gd`

**Step 1: Write the failing tests**

Replace `tests/unit/test_wave_profile.gd` with:

```gdscript
extends RefCounted

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	# --- Small wave profile ---
	var small := WaveProfileScript.small()
	if small.is_large:
		failures.append("small profile is_large should be false")
	if small.turn_push <= 0.0:
		failures.append("small profile should have positive turn_push")
	if small.lateral_force <= 0.0:
		failures.append("small profile should have positive lateral_force")
	if small.speed_multiplier <= 0.0 or small.speed_multiplier > 1.0:
		failures.append("small profile speed_multiplier should be in (0,1], got %f" % small.speed_multiplier)
	if not is_equal_approx(small.damage_per_second, 0.0):
		failures.append("small profile damage_per_second should be 0, got %f" % small.damage_per_second)
	if small.drift_speed < 0.2 or small.drift_speed > 0.8:
		failures.append("small profile drift_speed should be between 0.2 and 0.8, got %f" % small.drift_speed)

	# --- Large wave profile ---
	var large := WaveProfileScript.large()
	if not large.is_large:
		failures.append("large profile is_large should be true")
	if large.turn_push <= 0.0:
		failures.append("large profile should have positive turn_push")
	if large.lateral_force <= small.lateral_force:
		failures.append("large profile lateral_force should exceed small")
	if large.speed_multiplier >= small.speed_multiplier:
		failures.append("large profile speed_multiplier should be lower (more slowdown) than small")
	if large.damage_per_second <= 0.0:
		failures.append("large profile should have positive damage_per_second")
	if large.drift_speed < 0.3 or large.drift_speed > 1.2:
		failures.append("large profile drift_speed should be between 0.3 and 1.2, got %f" % large.drift_speed)

	return failures
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — `lateral_force`, `speed_multiplier`, `damage_per_second` do not exist on WaveProfile yet.

**Step 3: Rewrite WaveProfile**

Replace `scripts/waves/wave_profile.gd` with:

```gdscript
class_name WaveProfile
extends RefCounted

var turn_push: float = 0.0
var lateral_force: float = 0.0
var speed_multiplier: float = 1.0
var damage_per_second: float = 0.0
var drift_speed: float = 0.0
var is_large: bool = false


static func small(push_direction: float = 0.35) -> WaveProfile:
	var profile := WaveProfile.new()
	profile.turn_push = push_direction
	profile.lateral_force = 3.0
	profile.speed_multiplier = 0.85
	profile.damage_per_second = 0.0
	profile.is_large = false
	profile.drift_speed = randf_range(0.2, 0.8)
	return profile


static func large(push_direction: float = 0.7) -> WaveProfile:
	var profile := WaveProfile.new()
	profile.turn_push = push_direction
	profile.lateral_force = 7.0
	profile.speed_multiplier = 0.6
	profile.damage_per_second = 5.0
	profile.is_large = true
	profile.drift_speed = randf_range(0.3, 1.2)
	return profile
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `test_wave_profile` PASS. Other tests may fail (they reference old fields like `lift_force`, `damage_risk`). That is expected — we fix them in later tasks.

**Step 5: Commit**

```bash
git add scripts/waves/wave_profile.gd tests/unit/test_wave_profile.gd
git commit -m "feat: redesign WaveProfile with continuous-effect fields"
```

---

### Task 2: Convert WaveZone to passive data node

**Files:**

- Modify: `scripts/waves/wave_zone.gd`
- Modify: `tests/unit/test_wave_spawner.gd`

**Step 1: Write the failing tests**

Update `tests/unit/test_wave_spawner.gd`. The changes needed:

1. Replace references to `consumed` with `monitoring` checks (since `consumed` is removed)
2. Replace references to `lift_force` and `damage_risk` with `lateral_force`, `speed_multiplier`, `damage_per_second`
3. Replace `turn_push` / `lift_force` / `damage_risk` checks in `reset_for_spawn` test with new field checks
4. Add test: WaveZone exposes `drift_direction` property
5. Add test: WaveZone no longer calls `apply_wave_profile` on ship (verify `body_entered` does NOT trigger ship methods)

Update `tests/unit/test_wave_spawner.gd` — replace lines 69-84 (reset_for_spawn test) and lines 155-160 (deactivate test):

```gdscript
# In the reset_for_spawn test section (replacing lines 69-84):
var wave_c := spawner.acquire_wave()
var profile = WaveProfileScript.large(0.8)
profile.lateral_force = 7.0
profile.speed_multiplier = 0.6
profile.damage_per_second = 5.0
wave_c.reset_for_spawn(Vector3(3.0, 0.0, -20.0), profile)
if wave_c.monitoring == false:
	failures.append("reset_for_spawn should enable monitoring")
if not is_equal_approx(wave_c.turn_push, profile.turn_push):
	failures.append("reset_for_spawn should configure turn_push from profile")
if not is_equal_approx(wave_c.lateral_force, profile.lateral_force):
	failures.append("reset_for_spawn should configure lateral_force from profile")
if not is_equal_approx(wave_c.speed_multiplier, profile.speed_multiplier):
	failures.append("reset_for_spawn should configure speed_multiplier from profile")
if not is_equal_approx(wave_c.damage_per_second, profile.damage_per_second):
	failures.append("reset_for_spawn should configure damage_per_second from profile")
if wave_c.is_large != profile.is_large:
	failures.append("reset_for_spawn should configure is_large from profile")

# Add after the drift_velocity test (after line 180):
# Test: drift_direction is exposed and normalized
var dir_wave := spawner.acquire_wave()
dir_wave.configure_drift(Vector3(3.0, 0.0, -4.0))
if dir_wave.drift_direction.length() <= 0.0:
	failures.append("drift_direction should be set by configure_drift")
var norm := dir_wave.drift_direction.normalized()
if not is_equal_approx(dir_wave.drift_direction.length(), 1.0) and dir_wave.drift_direction.length() > 0.0:
	failures.append("drift_direction should be a normalized vector")

# In the deactivate test (replacing lines 155-160):
var wave_d := spawner.acquire_wave()
wave_d.deactivate_to_pool()
if wave_d.monitoring:
	failures.append("deactivate_to_pool should disable monitoring")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — WaveZone still has old fields, no `drift_direction`, `consumed` still exists, etc.

**Step 3: Rewrite WaveZone**

Replace `scripts/waves/wave_zone.gd` with:

```gdscript
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


func _update_visuals() -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance == null:
		return
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = Color("#FF0000") if is_large else Color("#87CEEB")
	material.albedo_color.a = 0.65


func set_debug_visible(vis: bool) -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance != null:
		mesh_instance.visible = vis
```

Key changes from original:

- **Removed**: `consumed` flag, `_on_body_entered` signal connection, `_on_body_entered()` method, `_fade_out_consumed()`
- **Removed**: `lift_force`, `damage_risk` (replaced by `lateral_force`, `speed_multiplier`, `damage_per_second`)
- **Added**: `drift_direction: Vector3` — set by `configure_drift()`, normalized
- **Retained**: Area3D collision shape, visual rendering, drift animation, pool mechanism

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `test_wave_spawner` PASS. Other tests may still fail due to old field references.

**Step 5: Commit**

```bash
git add scripts/waves/wave_zone.gd tests/unit/test_wave_spawner.gd
git commit -m "feat: convert WaveZone to passive data node with drift_direction"
```

---

### Task 3: Update WaveSpawner to use new profile fields

**Files:**

- Modify: `scripts/waves/wave_spawner.gd`

**Step 1: Update spawner's `_spawn_next_wave` to set new profile fields**

The spawner currently sets `profile.lift_force` and `profile.damage_risk` after creation. These fields no longer exist. Update to set `lateral_force`, `speed_multiplier`, `damage_per_second` instead.

In `scripts/waves/wave_spawner.gd`, replace the `_spawn_next_wave` method (lines 104-121):

```gdscript
func _spawn_next_wave(forward: Vector3) -> void:
	var ship_position := ship.global_position as Vector3
	var right := forward.cross(Vector3.UP).normalized()
	var spacing := randf_range(min_spacing, max_spacing)
	_furthest_ahead_distance += spacing
	var spawn_position := ship_position + forward * _furthest_ahead_distance + right * randf_range(-lane_width, lane_width)
	var wave := acquire_wave()
	wave.spawner = self
	var push_direction := randf_range(0.35, 0.95)
	push_direction *= -1.0 if randf() < 0.5 else 1.0
	var profile = WaveProfileScript.large(push_direction) if randf() < large_wave_chance else WaveProfileScript.small(push_direction)
	if profile.is_large:
		profile.lateral_force = randf_range(5.0, 9.0)
		profile.speed_multiplier = randf_range(0.5, 0.7)
		profile.damage_per_second = randf_range(4.0, 8.0)
	wave.reset_for_spawn(spawn_position, profile)
	var drift_sign := -1.0 if randf() < 0.5 else 1.0
	wave.configure_drift(right * drift_sign * profile.drift_speed)
	add_child(wave)
```

**Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `test_wave_spawner` still PASS (spawner test doesn't check the specific random-range values for large waves, only pool mechanics).

**Step 3: Commit**

```bash
git add scripts/waves/wave_spawner.gd
git commit -m "feat: update WaveSpawner to use new continuous-effect profile fields"
```

---

### Task 4: Rewrite ShipController with active wave querying

**Files:**

- Modify: `scripts/ship/ship_controller.gd`

**Step 1: Rewrite ShipController**

Replace `scripts/ship/ship_controller.gd` with:

```gdscript
class_name ShipController
extends CharacterBody3D

const SteeringInputScript = preload("res://scripts/input/steering_input.gd")
const IslandRulesScript = preload("res://scripts/core/island_rules.gd")

signal damage_taken(amount: float)
signal safe_zone_changed(in_safe_zone: bool)

@export var forward_speed: float = 18.0
@export var turn_speed: float = 1.7
@export var steering_smoothing: float = 5.0
@export var bob_strength: float = 0.4
@export var pitch_strength: float = 2.5
@export var roll_strength: float = 1.8
@export var gravity: float = 18.0

var input_adapter = null
var run_model = null
var steering_axis_smoothed: float = 0.0
var position_delta: Vector3 = Vector3.ZERO
var wave_turn_velocity: float = 0.0
var wave_turn_damping: float = 2.8
var wave_lateral_velocity: Vector3 = Vector3.ZERO
var wave_lateral_damping: float = 3.0
var wave_speed_multiplier: float = 1.0
var base_y: float = 0.0
var current_repair_rate: float = 0.0
var safe_zone_count: int = 0


func _ready() -> void:
	if input_adapter == null:
		input_adapter = SteeringInputScript.new()
	base_y = position.y
	_build_visuals()


func _physics_process(delta: float) -> void:
	if input_adapter == null:
		input_adapter = SteeringInputScript.new()
	simulate_tick(delta, input_adapter.get_steering_axis())


func simulate_tick(delta: float, steering_input: float) -> void:
	if run_model != null and run_model.is_game_over():
		position_delta = Vector3.ZERO
		return

	# --- Query overlapping waves ---
	var overlapping := get_overlapping_areas()
	var net_lateral := Vector3.ZERO
	var min_speed_multiplier := 1.0
	var total_damage := 0.0
	var total_turn_push := 0.0

	for area in overlapping:
		if area is WaveZone:
			var wave: WaveZone = area
			if wave.drift_direction.length() > 0.001:
				net_lateral += wave.drift_direction * wave.lateral_force
			min_speed_multiplier = minf(min_speed_multiplier, wave.speed_multiplier)
			total_damage += wave.damage_per_second * delta
			total_turn_push += wave.turn_push

	# --- Apply wave effects ---
	wave_turn_velocity += total_turn_push
	wave_speed_multiplier = min_speed_multiplier

	if net_lateral.length() > 0.001:
		wave_lateral_velocity = net_lateral

	# --- Apply damage ---
	if total_damage > 0.0 and run_model != null and not run_model.invulnerable:
		var applied := run_model.add_damage(total_damage)
		if applied > 0.0:
			damage_taken.emit(applied)

	# --- Steering + turn ---
	steering_axis_smoothed = lerpf(steering_axis_smoothed, steering_input, clampf(delta * steering_smoothing, 0.0, 1.0))
	rotate_y(-(steering_axis_smoothed + wave_turn_velocity) * turn_speed * delta)
	wave_turn_velocity = move_toward(wave_turn_velocity, 0.0, wave_turn_damping * delta)

	# --- Bob (cosmetic) ---
	var t := Time.get_ticks_msec() / 1000.0
	var speed_factor := clampf(forward_speed / 18.0, 0.3, 1.5)
	var bob_offset := (sin(t * 2.0) + sin(t * 3.7) * 0.3 + sin(t * 0.8) * 0.5) * bob_strength * speed_factor
	var bob_y := base_y + bob_offset
	position.y = bob_y

	var pitch := sin(t * 2.0 + 0.5) * pitch_strength * speed_factor
	var roll := sin(t * 1.3 + 1.0) * roll_strength * speed_factor
	_apply_boat_tilt(pitch, roll)

	# --- Movement: forward (with speed multiplier) + lateral push ---
	var forward_delta := -transform.basis.z.normalized() * forward_speed * wave_speed_multiplier * delta
	var lateral_delta := wave_lateral_velocity * delta
	position_delta = forward_delta + lateral_delta
	position += position_delta

	# --- Decay lateral velocity when no waves ---
	if net_lateral.length() <= 0.001:
		wave_lateral_velocity = wave_lateral_velocity.lerp(
			Vector3.ZERO,
			clampf(delta * wave_lateral_damping, 0.0, 1.0)
		)
		wave_speed_multiplier = 1.0

	# --- Distance + safe zone ---
	if run_model != null:
		run_model.advance_distance(position_delta.length())
		if safe_zone_count > 0:
			run_model.invulnerable = true
			run_model.repairing = true
			IslandRulesScript.apply_repair(run_model, current_repair_rate, delta)
		else:
			run_model.invulnerable = false
			run_model.repairing = false


func _apply_boat_tilt(pitch_deg: float, roll_deg: float) -> void:
	var boat_model := get_node_or_null("BoatModel")
	if boat_model == null:
		return
	boat_model.rotation_degrees.x = pitch_deg
	boat_model.rotation_degrees.z = roll_deg


func enter_safe_zone(repair_rate: float) -> void:
	safe_zone_count += 1
	current_repair_rate = max(current_repair_rate, repair_rate)
	if run_model != null:
		run_model.invulnerable = IslandRulesScript.enter_island(run_model.invulnerable)
		run_model.repairing = true
		safe_zone_changed.emit(true)


func exit_safe_zone(_repair_rate: float) -> void:
	safe_zone_count = max(0, safe_zone_count - 1)
	if safe_zone_count == 0:
		current_repair_rate = 0.0
		if run_model != null:
			run_model.invulnerable = IslandRulesScript.exit_island(run_model.invulnerable)
			run_model.repairing = false
		safe_zone_changed.emit(false)


func _build_visuals() -> void:
	if has_node("CollisionShape3D"):
		return

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.1, 0.8, 2.6)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	var boat_scene = load("res://assets/board.glb")
	if boat_scene == null:
		return
	var boat_model = boat_scene.instantiate()
	boat_model.name = "BoatModel"
	boat_model.position = Vector3(0.0, 0.0, 0.0)
	boat_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	boat_model.scale = Vector3(4.0, 4.0, 4.0)
	_promote_visual_priority(boat_model)
	add_child(boat_model)


func _promote_visual_priority(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		overlay.render_priority = 127
		overlay.no_depth_test = true
		mesh_instance.material_overlay = overlay

	for child in node.get_children():
		_promote_visual_priority(child)
```

Key changes from original:

- **Removed**: `apply_wave_profile()` method
- **Removed**: `wave_vertical_velocity` and airborne gravity logic
- **Removed**: `environment_push_velocity` and its damping
- **Removed**: `ShipRulesScript` preload and usage
- **Added**: `wave_lateral_velocity`, `wave_lateral_damping`, `wave_speed_multiplier`
- **Added**: Per-frame `get_overlapping_areas()` loop that reads WaveZone data
- **Added**: Direct damage calculation `damage_per_second * delta`
- **Added**: Lateral push via `wave_lateral_velocity`
- **Added**: Speed multiplier applied to `forward_speed`
- **Simplified**: Vertical bob is purely cosmetic (no more airborne/landing physics from waves)

**Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `test_wave_ship_interaction` will FAIL (it references `ShipRulesScript.apply_wave` which we may keep for now but the test logic is wrong). Other tests should pass.

**Step 3: Commit**

```bash
git add scripts/ship/ship_controller.gd
git commit -m "feat: rewrite ShipController with active wave querying and lateral push"
```

---

### Task 5: Simplify ShipRules and update wave-ship interaction tests

**Files:**

- Modify: `scripts/core/ship_rules.gd`
- Modify: `tests/unit/test_wave_ship_interaction.gd`

**Step 1: Write the failing tests**

Replace `tests/unit/test_wave_ship_interaction.gd` with:

```gdscript
extends RefCounted

const RunModelScript = preload("res://scripts/core/run_model.gd")
const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")
const ShipControllerScript = preload("res://scripts/ship/ship_controller.gd")
const SteeringInputScript = preload("res://scripts/input/steering_input.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	# --- RunModel damage still works ---
	var model = RunModelScript.new()
	model.add_damage(5.0)
	if model.damage < 5.0:
		failures.append("RunModel.add_damage should increase damage")

	# --- Large wave profile has damage_per_second ---
	var large_wave = WaveProfileScript.large()
	if large_wave.damage_per_second <= 0.0:
		failures.append("large wave profile should have positive damage_per_second")

	# --- Small wave profile has no damage ---
	var small_wave = WaveProfileScript.small()
	if small_wave.damage_per_second > 0.0:
		failures.append("small wave profile should have zero damage_per_second")

	# --- Ship moves forward along negative Z ---
	var ship = ShipControllerScript.new()
	ship.run_model = RunModelScript.new()
	ship.input_adapter = SteeringInputScript.new()
	ship.forward_speed = 10.0
	ship.base_y = 0.0
	ship._build_visuals()
	if ship.get_node_or_null("BoatModel") == null:
		failures.append("ship should load the board.glb boat model")
	ship.simulate_tick(1.0, 0.0)
	if ship.position_delta.z >= 0.0:
		failures.append("ship should move forward along negative z")

	# --- Ship respects speed_multiplier from waves ---
	# Simulate wave effect by manually setting wave_speed_multiplier
	ship.wave_speed_multiplier = 0.5
	ship.simulate_tick(1.0, 0.0)
	var expected_speed := 10.0 * 0.5
	var actual_forward := -ship.position_delta.z
	if not is_equal_approx(actual_forward, expected_speed):
		failures.append("ship forward speed should be reduced by wave_speed_multiplier, expected %f got %f" % [expected_speed, actual_forward])

	# --- Wave lateral velocity is applied ---
	ship.wave_lateral_velocity = Vector3(5.0, 0.0, 0.0)
	ship.wave_speed_multiplier = 1.0
	ship.simulate_tick(1.0, 0.0)
	if ship.position_delta.x <= 0.0:
		failures.append("ship should be pushed laterally by wave_lateral_velocity")

	# --- Lateral velocity decays when no waves push ---
	ship.wave_lateral_velocity = Vector3(10.0, 0.0, 0.0)
	ship.simulate_tick(1.0, 0.0)  # no overlapping waves, so it should decay
	if ship.wave_lateral_velocity.length() >= 10.0:
		failures.append("wave_lateral_velocity should decay when no overlapping waves")

	ship.free()

	return failures
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — old test references `ShipRulesScript.apply_wave` which doesn't match new test expectations.

**Step 3: Simplify ShipRules**

Since damage is now computed directly in ShipController as `damage_per_second * delta`, `ShipRules.apply_wave()` is no longer called. Simplify it to a minimal passthrough or remove the damage logic.

Replace `scripts/core/ship_rules.gd` with:

```gdscript
class_name ShipRules
extends RefCounted

# Damage is now computed directly in ShipController as
# wave.damage_per_second * delta. ShipRules is retained
# as a namespace for potential future rule validation.
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED

**Step 5: Commit**

```bash
git add scripts/core/ship_rules.gd tests/unit/test_wave_ship_interaction.gd
git commit -m "feat: simplify ShipRules and update wave-ship tests for continuous damage"
```

---

### Task 6: Add drift direction visual indicator to WaveZone

**Files:**

- Modify: `scripts/waves/wave_zone.gd`

**Step 1: Add directional gradient to wave mesh**

In `scripts/waves/wave_zone.gd`, update `_build_visuals()` to add a directional arrow indicator as a child node beneath the wave mesh. Also update `_update_visuals()` to color the arrow.

Add to `_build_visuals()` after the WaveMesh creation:

```gdscript
# --- Direction indicator arrow ---
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
```

Add to `_update_visuals()`:

```gdscript
# Update drift arrow color to match wave type
var arrow_instance := get_node_or_null("DriftArrow")
if arrow_instance != null:
	var arrow_material := arrow_instance.get_active_material(0) as StandardMaterial3D
	if arrow_material != null:
		arrow_material.albedo_color = Color("#FFAAAA") if is_large else Color("#FFFFFF")
		arrow_material.albedo_color.a = 0.9
```

Add a new method `_update_drift_arrow_rotation()` called from `configure_drift()`:

```gdscript
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
```

Call `_update_drift_arrow_rotation()` at the end of `configure_drift()`.

**Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED (visual changes don't affect test logic)

**Step 3: Manual verification**

Run: `godot --path .`

Expected: Waves now show a white (small) or pink (large) arrow inside them, pointing in the drift direction.

**Step 4: Commit**

```bash
git add scripts/waves/wave_zone.gd
git commit -m "feat: add drift direction arrow indicator to wave visuals"
```

---

### Task 7: Increase wave drift visibility and enhance visual distinction

**Files:**

- Modify: `scripts/waves/wave_spawner.gd`
- Modify: `scripts/waves/wave_zone.gd`

**Step 1: Increase drift speed ranges for better visibility**

In `scripts/waves/wave_profile.gd`, increase `drift_speed` ranges:

```gdscript
# In small():
profile.drift_speed = randf_range(0.8, 2.0)

# In large():
profile.drift_speed = randf_range(1.0, 3.0)
```

**Step 2: Make large wave mesh bigger for visual distinction**

In `scripts/waves/wave_zone.gd`, update `_update_visuals()` to also scale the collision shape and mesh for large waves:

```gdscript
func _update_visuals() -> void:
	var mesh_instance := get_node_or_null("WaveMesh")
	if mesh_instance != null:
		var material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("#FF4444") if is_large else Color("#87CEEB")
			material.albedo_color.a = 0.75 if is_large else 0.55
		# Large waves are visually bigger
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

	# Update drift arrow color
	var arrow_instance := get_node_or_null("DriftArrow")
	if arrow_instance != null:
		var arrow_material := arrow_instance.get_active_material(0) as StandardMaterial3D
		if arrow_material != null:
			arrow_material.albedo_color = Color("#FFAAAA") if is_large else Color("#FFFFFF")
			arrow_material.albedo_color.a = 0.9
```

**Step 3: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED

**Step 4: Manual verification**

Run: `godot --path .`

Expected: Large waves are visibly bigger and redder, small waves are smaller and lighter blue. Both drift noticeably sideways.

**Step 5: Commit**

```bash
git add scripts/waves/wave_profile.gd scripts/waves/wave_zone.gd scripts/waves/wave_spawner.gd
git commit -m "feat: enhance wave visual distinction and drift visibility"
```

---

### Task 8: Full integration test and manual playtest

**Files:**

- No new files (verification only)

**Step 1: Run full test suite**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `ALL TESTS PASSED`

**Step 2: Manual playtest**

Run: `godot --path .`

Verify:

1. Ship always moves forward along its heading
2. Small waves deflect ship laterally and slow it slightly (no damage)
3. Large waves deflect strongly, slow significantly, and deal damage over time
4. Wave drift direction is visible via arrows and lateral wave movement
5. Multiple overlapping waves stack their effects
6. Leaving a wave zone: lateral velocity decays, speed returns to normal
7. Safe zones (islands) still work — invulnerability prevents wave damage
8. HUD damage flash still triggers when wave damage is taken
9. Game over still occurs at damage = 100

**Step 3: Fix any issues found during playtest**

If any issues, fix and re-run tests.

**Step 4: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix: address integration issues from playtest"
```
