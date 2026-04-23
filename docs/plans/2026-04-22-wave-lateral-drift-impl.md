# Wave Lateral Drift Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add lateral drift to wave zones so waves move perpendicular to the ship's forward direction, creating a more dynamic ocean feel.

**Architecture:** WaveZone gets its own `_process` to apply `drift_velocity` each frame. WaveProfile gains a `drift_speed` property. WaveSpawner computes the `right` vector at spawn time and calls `configure_drift` on each new wave.

**Tech Stack:** Godot 4 / GDScript, custom SceneTree test harness (`tests/run_tests.gd`)

---

### Task 1: Add drift_speed to WaveProfile

**Files:**
- Modify: `scripts/waves/wave_profile.gd:4-25`
- Test: `tests/unit/test_wave_profile.gd`

**Step 1: Write the failing test**

Open `tests/unit/test_wave_profile.gd` and add assertions for `drift_speed`:

```gdscript
# After existing assertions in the small profile test block, add:
if profile.drift_speed < 1.0 or profile.drift_speed > 3.0:
	failures.append("small profile drift_speed should be between 1.0 and 3.0, got %f" % profile.drift_speed)

# After existing assertions in the large profile test block, add:
if profile.drift_speed < 2.0 or profile.drift_speed > 5.0:
	failures.append("large profile drift_speed should be between 2.0 and 5.0, got %f" % profile.drift_speed)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — `drift_speed` does not exist on WaveProfile.

**Step 3: Write minimal implementation**

In `scripts/waves/wave_profile.gd`, add `drift_speed` var and set it in both factory methods:

```gdscript
# Add after line 6 (var damage_risk):
var drift_speed: float = 0.0

# In small() factory (after profile.is_large = false):
profile.drift_speed = randf_range(1.0, 3.0)

# In large() factory (after profile.is_large = true):
profile.drift_speed = randf_range(2.0, 5.0)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED

**Step 5: Commit**

```bash
git add scripts/waves/wave_profile.gd tests/unit/test_wave_profile.gd
git commit -m "feat: add drift_speed to WaveProfile"
```

---

### Task 2: Add drift_velocity and _process to WaveZone

**Files:**
- Modify: `scripts/waves/wave_zone.gd`
- Test: `tests/unit/test_wave_spawner.gd`

**Step 1: Write the failing test**

In `tests/unit/test_wave_spawner.gd`, add a drift test block before `parent.queue_free()`:

```gdscript
# Test: drift_velocity is applied during _process
var drift_wave := spawner.acquire_wave()
var drift_profile = WaveProfileScript.small(0.5)
drift_profile.drift_speed = 2.0
drift_wave.reset_for_spawn(Vector3.ZERO, drift_profile)
drift_wave.configure_drift(Vector3(1.0, 0.0, 0.0) * drift_profile.drift_speed)
spawner.add_child(drift_wave)

var pos_before := drift_wave.position.x
drift_wave._process(1.0)
if drift_wave.position.x <= pos_before:
	failures.append("wave should move laterally when drift_velocity is set and _process is called")

# Test: deactivate_to_pool zeroes drift_velocity and stops processing
drift_wave.deactivate_to_pool()
if drift_wave.drift_velocity != Vector3.ZERO:
	failures.append("deactivate_to_pool should zero drift_velocity")
if drift_wave.is_processing():
	failures.append("deactivate_to_pool should stop processing")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — `drift_velocity` and `configure_drift` do not exist on WaveZone.

**Step 3: Write minimal implementation**

In `scripts/waves/wave_zone.gd`:

1. Add `drift_velocity` var after line 12 (`var spawner = null`):

```gdscript
var drift_velocity: Vector3 = Vector3.ZERO
```

2. Add `set_process(true)` in `_ready()` after `_build_visuals()`:

```gdscript
func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visuals()
	set_process(true)
```

3. Add `_process` method after `_ready`:

```gdscript
func _process(delta: float) -> void:
	position += drift_velocity * delta
```

4. Add `configure_drift` method after `configure`:

```gdscript
func configure_drift(velocity: Vector3) -> void:
	drift_velocity = velocity
```

5. In `deactivate_to_pool`, add drift cleanup:

```gdscript
func deactivate_to_pool() -> void:
	consumed = true
	monitoring = false
	drift_velocity = Vector3.ZERO
	set_processing(false)
```

Note: use `set_processing(false)` (not `set_process`) — `set_processing` is the Godot 4 method that disables `_process` without affecting `_physics_process`.

6. In `reset_for_spawn`, ensure processing is re-enabled:

```gdscript
func reset_for_spawn(spawn_position: Vector3, profile) -> void:
	consumed = false
	monitoring = true
	position = spawn_position
	configure(profile)
	set_processing(true)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED

**Step 5: Commit**

```bash
git add scripts/waves/wave_zone.gd tests/unit/test_wave_spawner.gd
git commit -m "feat: add lateral drift movement to WaveZone"
```

---

### Task 3: Wire drift direction from WaveSpawner

**Files:**
- Modify: `scripts/waves/wave_spawner.gd:104-119`
- Test: `tests/unit/test_wave_spawner.gd`

**Step 1: Write the failing test**

In `tests/unit/test_wave_spawner.gd`, after the direction-aware spawn test block (after line 152), add:

```gdscript
# Test: spawned waves receive lateral drift_velocity
var drift_dir := dir_spawner._ship_forward().cross(Vector3.UP).normalized()
var has_drift := false
for child in spawned_children:
	if child.drift_velocity != Vector3.ZERO:
		has_drift = true
		var drift_dir_actual := child.drift_velocity.normalized()
		var is_lateral := absf(drift_dir_actual.dot(dir_spawner._ship_forward()))
		if is_lateral > 0.1:
			failures.append("drift_velocity should be perpendicular to ship forward, but dot = %f" % is_lateral)
if not has_drift:
	failures.append("at least one spawned wave should have non-zero drift_velocity")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL — "at least one spawned wave should have non-zero drift_velocity"

**Step 3: Write minimal implementation**

In `scripts/waves/wave_spawner.gd`, in `_spawn_next_wave`, after the `wave.reset_for_spawn(spawn_position, profile)` call (line 118), add:

```gdscript
var drift_sign := -1.0 if randf() < 0.5 else 1.0
wave.configure_drift(right * drift_sign * profile.drift_speed)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: ALL TESTS PASSED

**Step 5: Commit**

```bash
git add scripts/waves/wave_spawner.gd tests/unit/test_wave_spawner.gd
git commit -m "feat: wire lateral drift from WaveSpawner to WaveZone"
```
