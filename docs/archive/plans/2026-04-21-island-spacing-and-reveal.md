# Island Spacing and Reveal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make islands spawn with reliable separation and reveal smoothly from far to near, while keeping preview islands visual-only until the boat is close.

**Architecture:** Keep the existing ship-relative spawning model in `scripts/islands/island_spawner.gd`, but add bounded retry-based placement with minimum spacing checks. Extend `scripts/islands/island.gd` so each island can interpolate between preview and active presentation, with gameplay effects enabled only in active range.

**Tech Stack:** Godot 4, GDScript, existing `Area3D`-based island scene, custom script-based test runner in `tests/run_tests.gd`.

---

### Task 1: Capture current behavior in spawner tests

**Files:**
- Modify: `tests/unit/test_island_spawner.gd`
- Reference: `scripts/islands/island_spawner.gd`

**Step 1: Write failing tests for minimum spacing behavior**

Add tests that generate or validate candidate offsets and assert that accepted spawn positions are never closer than the new spacing threshold.

```gdscript
var positions: Array[Vector3] = []
for _i in range(6):
	var next_position := spawner.find_spawn_offset(positions)
	if next_position == null:
		failures.append("spawner should find a valid island position when the ring has free space")
		break
	for existing in positions:
		if existing.distance_to(next_position) < spawner.minimum_island_spacing:
			failures.append("spawned islands should respect minimum spacing")
	positions.append(next_position)
```

**Step 2: Write a failing bounded-retry test**

Add a test that constrains the spawn area so tightly that placement becomes impossible, then assert the spawner gives up cleanly instead of looping forever.

```gdscript
spawner.spawn_attempt_limit = 3
spawner.spawn_outer_half_width = 2.0
spawner.spawn_outer_half_depth = 2.0
spawner.spawn_inner_half_width = 0.0
spawner.spawn_inner_half_depth = 0.0
spawner.minimum_island_spacing = 50.0

var blocked := spawner.find_spawn_offset([Vector3.ZERO])
if blocked != null:
	failures.append("spawner should return null when it cannot satisfy spacing within the retry limit")
```

**Step 3: Run tests to verify failure**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL with missing methods or missing spacing assertions.

**Step 4: Commit**

```bash
git add tests/unit/test_island_spawner.gd
git commit -m "test: cover island spacing constraints"
```

### Task 2: Implement spacing-aware spawn selection in the spawner

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Test: `tests/unit/test_island_spawner.gd`

**Step 1: Add exported spacing and retry configuration**

Introduce exported settings such as:

```gdscript
@export var minimum_island_spacing: float = 28.0
@export var spawn_attempt_limit: int = 12
@export var preview_spawn_outer_half_width: float = 52.0
@export var preview_spawn_outer_half_depth: float = 76.0
@export var activation_distance: float = 34.0
@export var preview_visible_distance: float = 72.0
```

**Step 2: Add helper methods for spawn validation**

Implement helpers that:

- collect existing island positions,
- test candidate spacing,
- retry candidate generation up to a limit,
- return `null` if no valid point is found.

Target structure:

```gdscript
func find_spawn_offset(existing_positions: Array[Vector3]) -> Variant:
	for _attempt in range(spawn_attempt_limit):
		var candidate := generate_spawn_offset()
		if _is_spawn_position_valid(candidate, existing_positions):
			return candidate
	return null

func _is_spawn_position_valid(candidate: Vector3, existing_positions: Array[Vector3]) -> bool:
	for existing in existing_positions:
		if existing.distance_to(candidate) < minimum_island_spacing:
			return false
	return true
```

**Step 3: Update `_spawn_next_island()` to use the validated offset path**

If no valid offset is found, return without spawning.

```gdscript
var spawn_offset = find_spawn_offset(_existing_offsets_relative_to_ship())
if spawn_offset == null:
	return
```

**Step 4: Run tests to verify pass**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: PASS for island spawner tests and no regressions elsewhere.

**Step 5: Commit**

```bash
git add scripts/islands/island_spawner.gd tests/unit/test_island_spawner.gd
git commit -m "fix: space island spawns apart"
```

### Task 3: Add preview-versus-active behavior tests for islands

**Files:**
- Modify: `tests/unit/test_island_current.gd`
- Reference: `scripts/islands/island.gd`

**Step 1: Write failing tests for presentation state gating**

Add tests that verify preview islands do not apply safe-zone or current behavior.

```gdscript
island.set_preview_state(true)
var preview_push := island.calculate_current_push(Vector3(9.0, 0.0, 0.0), 1.0)
if preview_push != Vector3.ZERO:
	failures.append("preview islands should not push ships with current effects")
```

Add a test that verifies active islands still behave as before.

```gdscript
island.set_preview_state(false)
var active_push := island.calculate_current_push(Vector3(9.0, 0.0, 0.0), 1.0)
if active_push == Vector3.ZERO:
	failures.append("active islands should keep current behavior")
```

**Step 2: Run tests to verify failure**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL with missing preview-state methods or incorrect behavior.

**Step 3: Commit**

```bash
git add tests/unit/test_island_current.gd
git commit -m "test: cover island preview gating"
```

### Task 4: Implement island reveal state and gameplay gating

**Files:**
- Modify: `scripts/islands/island.gd`
- Modify: `scenes/islands/Island.tscn`
- Test: `tests/unit/test_island_current.gd`

**Step 1: Add preview-state data and a public update API**

Add exported presentation settings and state methods, for example:

```gdscript
@export var preview_alpha: float = 0.25
@export var preview_scale_multiplier: float = 1.08

var is_preview_only: bool = false

func set_preview_state(value: bool) -> void:
	is_preview_only = value
	_apply_presentation()

func update_reveal(distance_to_ship: float, active_distance: float, visible_distance: float) -> void:
	var t := clampf(inverse_lerp(visible_distance, active_distance, distance_to_ship), 0.0, 1.0)
	_apply_reveal_t(t)
```

**Step 2: Gate current/safe interactions by active state**

Ensure preview islands do not affect the ship.

```gdscript
func calculate_current_push(body_position: Vector3, delta: float) -> Vector3:
	if is_preview_only:
		return Vector3.ZERO
	...
```

Also disable monitoring on safe/current areas when preview-only if needed.

**Step 3: Apply reveal visuals to scene nodes**

Update shore mesh material alpha and root or model scale during preview-to-active interpolation. If the imported model material cannot be faded safely, keep the shore fade plus node scaling and leave a code comment documenting the limitation.

**Step 4: Run tests to verify pass**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: PASS for island current tests and existing island behavior tests.

**Step 5: Launch the game for a quick visual smoke test**

Run: `godot4 --path .`

Expected: Islands are faint at distance, become solid as the boat approaches, and no preview island applies gameplay early.

**Step 6: Commit**

```bash
git add scripts/islands/island.gd scenes/islands/Island.tscn tests/unit/test_island_current.gd
git commit -m "feat: add island preview reveal states"
```

### Task 5: Drive reveal updates from the spawner

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Reference: `scripts/islands/island.gd`
- Test: `tests/unit/test_island_spawner.gd`

**Step 1: Update `_process()` to refresh each island's reveal state**

After spawn/cleanup, iterate islands and push distance-based reveal values.

```gdscript
for child in get_children():
	if child is Island:
		var distance := child.global_position.distance_to(ship.global_position)
		child.update_reveal(distance, activation_distance, preview_visible_distance)
```

**Step 2: Expand spawn band for earlier visibility**

Adjust the spawn band or introduce preview-specific outer bounds so islands can exist farther away than the current 28x42 band.

**Step 3: Add or update tests for reveal threshold behavior**

At minimum, add pure logic assertions around threshold values or helper methods so the preview/active boundary is testable without scene rendering.

**Step 4: Run tests to verify pass**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: PASS for all tests.

**Step 5: Launch the game for integrated verification**

Run: `godot4 --path .`

Expected: Islands appear farther out, transition smoothly, and remain well separated.

**Step 6: Commit**

```bash
git add scripts/islands/island_spawner.gd tests/unit/test_island_spawner.gd scripts/islands/island.gd scenes/islands/Island.tscn
git commit -m "feat: reveal islands smoothly from distance"
```

### Task 6: Final verification and tuning pass

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Modify: `scripts/islands/island.gd`
- Modify: `scenes/islands/Island.tscn`
- Modify: `tests/unit/test_island_spawner.gd`
- Modify: `tests/unit/test_island_current.gd`

**Step 1: Run the full test suite again**

Run: `godot4 --headless --path . -s res://tests/run_tests.gd`

Expected: `ALL TESTS PASSED`

**Step 2: Run the playable scene and manually verify**

Run: `godot4 --path .`

Check:

- islands no longer overlap visibly,
- distant islands are faint but noticeable,
- near islands look normal,
- preview islands do not heal or push the boat,
- cleanup still removes islands once they are far enough away.

**Step 3: Make only minimal tuning adjustments**

If the scene is too sparse or too dense, tune exported values only:

- `minimum_island_spacing`
- `spawn_attempt_limit`
- `preview_visible_distance`
- `activation_distance`
- `preview_alpha`
- `preview_scale_multiplier`

**Step 4: Commit**

```bash
git add scripts/islands/island_spawner.gd scripts/islands/island.gd scenes/islands/Island.tscn tests/unit/test_island_spawner.gd tests/unit/test_island_current.gd
git commit -m "chore: tune island spacing and reveal"
```

## Verification Checklist

- `tests/unit/test_island_spawner.gd` proves spacing and bounded retries.
- `tests/unit/test_island_current.gd` proves preview islands are visual-only.
- `godot4 --headless --path . -s res://tests/run_tests.gd` exits 0.
- `godot4 --path .` shows a smooth far-to-near reveal with no obvious overlap.
- No gameplay regression in existing island safe-zone/current behavior after activation.

## Notes for the Implementer

- Prefer one island scene with stateful presentation over introducing a separate preview scene.
- Do not bypass spacing checks just to maintain target count.
- If the imported GLB materials resist runtime alpha changes, keep the preview effect with shore alpha + scale and document the limitation in code comments.
- Keep the diff focused on island spawning and island presentation; do not refactor unrelated world systems.
