# Portrait Boat Survival MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a portrait mobile Godot 4 prototype where a boat auto-sails forward, the player steers with the gyroscope, waves disrupt the route and sometimes damage the boat, islands repair and grant invulnerability, and the run ends at 100% damage.

**Architecture:** Use a small Godot 4 scene graph with deterministic gameplay systems instead of realistic water physics. Keep the ship controller, wave hazards, island zones, game state, and HUD loosely coupled so the MVP can be tuned quickly and expanded later without rewriting core logic.

**Tech Stack:** Godot 4, GDScript, Godot built-in scene system, optional GUT for unit tests, Android/iOS gyroscope input with desktop fallback.

---

## Notes Before Starting

- Keep the first playable loop tiny and testable.
- Prefer pure helper scripts for damage math, spawn timing, and input filtering so they can be unit tested.
- For device-only behavior like gyroscope input, provide a desktop simulation fallback before testing on phone.
- Do not add progression systems, weather layers, or content breadth during MVP.

### Task 1: Create the Godot project skeleton

**Files:**
- Create: `project.godot`
- Create: `icon.svg`
- Create: `scenes/main/Main.tscn`
- Create: `scripts/main/main.gd`
- Create: `docs/plans/2026-04-13-portrait-boat-survival-design.md`

**Step 1: Create the base project files**

Create a Godot 4 project configured for portrait orientation with `Main.tscn` as the entry scene.

**Step 2: Set project display defaults**

Set portrait-friendly base resolution, stretch mode, and mobile orientation in `project.godot`.

**Step 3: Wire the empty main scene**

Create `Main.tscn` with a root node and attach `scripts/main/main.gd`.

**Step 4: Launch the project**

Run: `godot4 --path .`
Expected: Project opens and starts with an empty main scene and no script errors.

**Step 5: Commit**

```bash
git add project.godot icon.svg scenes/main/Main.tscn scripts/main/main.gd docs/plans/2026-04-13-portrait-boat-survival-design.md
git commit -m "chore: scaffold portrait Godot project"
```

### Task 2: Add pure gameplay model tests for damage, repair, and score

**Files:**
- Create: `tests/unit/test_run_model.gd`
- Create: `scripts/core/run_model.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_damage_caps_at_100():
	var model = RunModel.new()
	model.add_damage(150.0)
	assert_eq(model.damage, 100.0)

func test_repair_stops_at_zero():
	var model = RunModel.new()
	model.damage = 30.0
	model.repair(50.0)
	assert_eq(model.damage, 0.0)

func test_distance_increases_while_running():
	var model = RunModel.new()
	model.advance_distance(12.5)
	assert_eq(model.distance, 12.5)
```

**Step 2: Run test to verify it fails**

Run: `godot4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs`
Expected: FAIL because `RunModel` does not exist yet.

**Step 3: Write minimal implementation**

```gdscript
class_name RunModel
extends RefCounted

var damage: float = 0.0
var distance: float = 0.0

func add_damage(amount: float) -> void:
	damage = min(100.0, damage + amount)

func repair(amount: float) -> void:
	damage = max(0.0, damage - amount)

func advance_distance(amount: float) -> void:
	distance += amount
```

**Step 4: Run test to verify it passes**

Run: `godot4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs`
Expected: PASS for all three tests.

**Step 5: Commit**

```bash
git add tests/unit/test_run_model.gd scripts/core/run_model.gd
git commit -m "test: add core run model"
```

### Task 3: Build desktop-safe input abstraction for gyro steering

**Files:**
- Create: `scripts/input/steering_input.gd`
- Create: `tests/unit/test_steering_input.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_keyboard_fallback_returns_negative_on_left():
	var input_adapter = SteeringInput.new()
	input_adapter.set_debug_axis(-1.0)
	assert_eq(input_adapter.get_steering_axis(), -1.0)

func test_axis_is_clamped():
	var input_adapter = SteeringInput.new()
	input_adapter.set_debug_axis(2.5)
	assert_eq(input_adapter.get_steering_axis(), 1.0)
```

**Step 2: Run test to verify it fails**

Run: `godot4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs`
Expected: FAIL because `SteeringInput` does not exist yet.

**Step 3: Write minimal implementation**

```gdscript
class_name SteeringInput
extends RefCounted

var debug_axis := 0.0

func set_debug_axis(value: float) -> void:
	debug_axis = clamp(value, -1.0, 1.0)

func get_steering_axis() -> float:
	return debug_axis
```

Add a note in code that device gyroscope input will feed this same normalized axis later.

**Step 4: Run test to verify it passes**

Run: `godot4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/input/steering_input.gd tests/unit/test_steering_input.gd
git commit -m "test: add steering input abstraction"
```

### Task 4: Add the ship scene and forward movement loop

**Files:**
- Create: `scenes/ship/Ship.tscn`
- Create: `scripts/ship/ship_controller.gd`
- Modify: `scenes/main/Main.tscn`
- Modify: `scripts/main/main.gd`

**Step 1: Write the failing test**

Create a small scene test or script-level assertion proving the ship advances forward over time.

```gdscript
extends GutTest

func test_ship_moves_forward_after_tick():
	var ship = preload("res://scripts/ship/ship_controller.gd").new()
	ship.forward_speed = 10.0
	ship.simulate_tick(1.0, 0.0)
	assert_true(ship.position_delta.z < 0.0)
```

**Step 2: Run test to verify it fails**

Run the targeted unit test and confirm movement helpers are missing.

**Step 3: Write minimal implementation**

Implement:
- forward speed value
- smoothed steering axis input
- helper function for deterministic movement math
- scene node with visible placeholder mesh

**Step 4: Run project to verify it passes visually**

Run: `godot4 --path .`
Expected: A visible placeholder boat advances in the play space without script errors.

**Step 5: Commit**

```bash
git add scenes/ship/Ship.tscn scripts/ship/ship_controller.gd scenes/main/Main.tscn scripts/main/main.gd
git commit -m "feat: add controllable boat prototype"
```

### Task 5: Integrate real gyro input with desktop fallback

**Files:**
- Modify: `scripts/input/steering_input.gd`
- Modify: `scripts/ship/ship_controller.gd`
- Modify: `project.godot`

**Step 1: Write the failing test**

Add a test for input smoothing and fallback preference.

```gdscript
func test_returns_debug_axis_when_device_motion_unavailable():
	var input_adapter = SteeringInput.new()
	input_adapter.set_debug_axis(0.5)
	assert_eq(input_adapter.get_steering_axis(), 0.5)
```

**Step 2: Run test to verify it fails**

Expected: FAIL because the fallback branch is not implemented correctly.

**Step 3: Write minimal implementation**

Implement:
- gyroscope / accelerometer-derived lateral axis
- clamp and smoothing
- keyboard or debug slider fallback for desktop
- project permissions/settings needed for mobile sensor use

**Step 4: Run manual verification**

Run on desktop first with fallback controls, then on a mobile build.
Expected: Desktop fallback steers the boat; mobile tilt steers the boat without severe jitter.

**Step 5: Commit**

```bash
git add scripts/input/steering_input.gd scripts/ship/ship_controller.gd project.godot
git commit -m "feat: connect gyro steering with fallback input"
```

### Task 6: Create wave zone data model and tests

**Files:**
- Create: `scripts/waves/wave_profile.gd`
- Create: `scripts/waves/wave_zone.gd`
- Create: `tests/unit/test_wave_profile.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_large_wave_profile_has_damage_risk():
	var profile = WaveProfile.large()
	assert_true(profile.damage_risk > 0.0)

func test_small_wave_profile_pushes_without_damage_requirement():
	var profile = WaveProfile.small()
	assert_true(profile.turn_push != 0.0)
```

**Step 2: Run test to verify it fails**

Expected: FAIL because `WaveProfile` factory methods do not exist.

**Step 3: Write minimal implementation**

Implement a simple data object with:
- `turn_push`
- `lift_force`
- `damage_risk`
- `is_large`

**Step 4: Run test to verify it passes**

Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/waves/wave_profile.gd scripts/waves/wave_zone.gd tests/unit/test_wave_profile.gd
git commit -m "feat: add wave hazard profiles"
```

### Task 7: Spawn and render small and large wave zones

**Files:**
- Create: `scripts/waves/wave_spawner.gd`
- Create: `scenes/waves/WaveZone.tscn`
- Modify: `scenes/main/Main.tscn`
- Modify: `scripts/main/main.gd`

**Step 1: Write the failing test**

Create a deterministic spawner test that verifies the spawner returns wave definitions ahead of the player.

```gdscript
func test_spawner_creates_wave_ahead_of_player():
	var spawner = WaveSpawner.new()
	var spawn_z = spawner.get_next_spawn_z(0.0)
	assert_true(spawn_z < 0.0)
```

**Step 2: Run test to verify it fails**

Expected: FAIL because `WaveSpawner` helper methods do not exist.

**Step 3: Write minimal implementation**

Implement:
- spawn cadence
- small / large wave selection
- ahead-of-player placement
- simple visual placeholder for each wave type

**Step 4: Run visual verification**

Run: `godot4 --path .`
Expected: Wave hazards continuously appear ahead of the boat and scroll into gameplay space.

**Step 5: Commit**

```bash
git add scripts/waves/wave_spawner.gd scenes/waves/WaveZone.tscn scenes/main/Main.tscn scripts/main/main.gd
git commit -m "feat: spawn wave hazards"
```

### Task 8: Apply wave influence and damage to the ship

**Files:**
- Modify: `scripts/ship/ship_controller.gd`
- Modify: `scripts/waves/wave_zone.gd`
- Modify: `scripts/core/run_model.gd`
- Create: `tests/unit/test_wave_ship_interaction.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_large_wave_adds_damage_when_launch_threshold_exceeded():
	var model = RunModel.new()
	var wave = WaveProfile.large()
	ShipRules.apply_wave(model, wave, 1.0)
	assert_true(model.damage > 0.0)
```

**Step 2: Run test to verify it fails**

Expected: FAIL because the shared ship-wave rule helper does not exist.

**Step 3: Write minimal implementation**

Implement:
- wave entry / overlap handling
- heading push
- lift event for large waves
- damage application when launch or landing threshold is exceeded
- invulnerability bypass while on islands

**Step 4: Run verification**

Run unit tests and then run the scene.
Expected: Small waves push the ship; large waves visibly disrupt it and sometimes increase damage.

**Step 5: Commit**

```bash
git add scripts/ship/ship_controller.gd scripts/waves/wave_zone.gd scripts/core/run_model.gd tests/unit/test_wave_ship_interaction.gd
git commit -m "feat: connect wave hazards to ship damage"
```

### Task 9: Add island scene, zone behavior, and healing tests

**Files:**
- Create: `scenes/islands/Island.tscn`
- Create: `scripts/islands/island.gd`
- Create: `scripts/islands/island_spawner.gd`
- Create: `tests/unit/test_island_rules.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_island_repairs_damage_over_time():
	var model = RunModel.new()
	model.damage = 40.0
	IslandRules.apply_repair(model, 5.0, 2.0)
	assert_eq(model.damage, 30.0)

func test_island_sets_invulnerable_state():
	var state = IslandRules.enter_island(false)
	assert_true(state)
```

**Step 2: Run test to verify it fails**

Expected: FAIL because `IslandRules` does not exist.

**Step 3: Write minimal implementation**

Implement:
- island safe radius
- repair-over-time
- enter/exit invulnerability toggle
- spawn logic ahead of the player with lane variety

**Step 4: Run visual verification**

Run: `godot4 --path .`
Expected: Islands appear ahead of the player; entering their radius repairs damage and prevents new damage.

**Step 5: Commit**

```bash
git add scenes/islands/Island.tscn scripts/islands/island.gd scripts/islands/island_spawner.gd tests/unit/test_island_rules.gd
git commit -m "feat: add island repair zones"
```

### Task 10: Add HUD with distance, damage, and safe-state feedback

**Files:**
- Create: `scenes/ui/HUD.tscn`
- Create: `scripts/ui/hud.gd`
- Modify: `scenes/main/Main.tscn`
- Modify: `scripts/main/main.gd`

**Step 1: Write the failing test**

Create a small UI binding test or script test that verifies the HUD formats distance and damage text from known values.

**Step 2: Run test to verify it fails**

Expected: FAIL because HUD bindings do not exist.

**Step 3: Write minimal implementation**

Implement:
- distance label
- damage bar / value
- invulnerable or repairing indicator
- basic game-over overlay hook

**Step 4: Run visual verification**

Run: `godot4 --path .`
Expected: HUD updates continuously during play and clearly communicates damage and island safety state.

**Step 5: Commit**

```bash
git add scenes/ui/HUD.tscn scripts/ui/hud.gd scenes/main/Main.tscn scripts/main/main.gd
git commit -m "feat: add run hud and status feedback"
```

### Task 11: Add run lifecycle and restart flow

**Files:**
- Modify: `scripts/main/main.gd`
- Modify: `scripts/core/run_model.gd`
- Modify: `scenes/ui/HUD.tscn`
- Modify: `scripts/ui/hud.gd`
- Create: `tests/unit/test_game_over_rules.gd`

**Step 1: Write the failing test**

```gdscript
extends GutTest

func test_run_ends_when_damage_reaches_100():
	var model = RunModel.new()
	model.add_damage(100.0)
	assert_true(model.is_game_over())
```

**Step 2: Run test to verify it fails**

Expected: FAIL because `is_game_over` does not exist.

**Step 3: Write minimal implementation**

Implement:
- run-over state transition
- freeze gameplay on game over
- final distance display
- restart button or tap-to-restart flow

**Step 4: Run verification**

Run: `godot4 --path .`
Expected: Reaching 100% damage ends the run cleanly and allows restart without reloading the editor.

**Step 5: Commit**

```bash
git add scripts/main/main.gd scripts/core/run_model.gd scenes/ui/HUD.tscn scripts/ui/hud.gd tests/unit/test_game_over_rules.gd
git commit -m "feat: add game over and restart flow"
```

### Task 12: Add sea presentation and impact feedback polish

**Files:**
- Create: `scenes/world/Sea.tscn`
- Create: `scripts/world/sea.gd`
- Create: `scripts/camera/camera_rig.gd`
- Modify: `scenes/main/Main.tscn`
- Modify: `scripts/ship/ship_controller.gd`

**Step 1: Write the failing test**

Write a minimal script test for camera impact intensity clamping or feedback cooldown logic.

**Step 2: Run test to verify it fails**

Expected: FAIL because the feedback helper does not exist.

**Step 3: Write minimal implementation**

Implement:
- scrolling / animated sea surface
- mild camera follow and bump response
- splash / repair placeholder hooks
- clear island entry / exit feedback states

**Step 4: Run visual verification**

Run: `godot4 --path .`
Expected: The game reads as a coherent ocean run, not just floating debug primitives.

**Step 5: Commit**

```bash
git add scenes/world/Sea.tscn scripts/world/sea.gd scripts/camera/camera_rig.gd scenes/main/Main.tscn scripts/ship/ship_controller.gd
git commit -m "feat: add sea presentation and impact feedback"
```

### Task 13: Validate portrait mobile build and tune first-run balance

**Files:**
- Modify: `project.godot`
- Modify: `scripts/ship/ship_controller.gd`
- Modify: `scripts/waves/wave_spawner.gd`
- Modify: `scripts/islands/island_spawner.gd`
- Modify: `docs/plans/2026-04-13-portrait-boat-survival-design.md`

**Step 1: Write the failing test**

Write a small parameter validation test around spawn ranges or steering clamp values if not already covered.

**Step 2: Run test to verify it fails**

Expected: FAIL because current tuning values do not meet the encoded bounds.

**Step 3: Write minimal implementation**

Tune:
- steering sensitivity and smoothing
- small / large wave spawn intervals
- island spawn frequency and lane range
- repair rate and damage amounts
- portrait layout scaling

Update the design doc only if tuning changes the agreed behavior.

**Step 4: Run full verification**

Run:
- `godot4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs`
- `godot4 --path .`
- mobile export / device smoke test

Expected:
- tests pass
- project runs without script errors
- first run is understandable within seconds
- device tilt control is playable

**Step 5: Commit**

```bash
git add project.godot scripts/ship/ship_controller.gd scripts/waves/wave_spawner.gd scripts/islands/island_spawner.gd docs/plans/2026-04-13-portrait-boat-survival-design.md
git commit -m "chore: tune portrait boat survival mvp"
```
