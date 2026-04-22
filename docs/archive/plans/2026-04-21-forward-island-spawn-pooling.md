# Forward Island Spawn and Pooling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand island spawn range ahead of the boat, limit spawning to the forward sector, and reuse island instances through a simple spawner-owned pool.

**Architecture:** Keep `scripts/islands/island_spawner.gd` as the only lifecycle manager, but replace the old four-sided rectangular ring with a forward-only spawn region. Add explicit island reuse hooks in `scripts/islands/island.gd`, then update tests so spawn direction, pooling, and reset behavior are verified through the custom SceneTree harness.

**Tech Stack:** Godot 4, GDScript, `Area3D` island scene instances, custom headless test harness in `tests/run_tests.gd`.

---

### Task 1: Replace old spawner expectations with forward-only tests

**Files:**
- Modify: `tests/unit/test_island_spawner.gd`
- Reference: `scripts/islands/island_spawner.gd`

**Step 1: Write failing tests for front-only spawn coverage**

Replace the current expectation that islands can spawn behind the ship with tests that require only front-facing offsets.

```gdscript
if offset.z >= spawner.spawn_inner_half_depth:
	failures.append("island spawner should not place islands behind the boat")
```

Add assertions for front-left / front-center / front-right coverage.

**Step 2: Add a failing test for larger forward preview range**

```gdscript
if absf(offset.z) > 42.0:
	saw_farther_forward_spawn = true
```

Assert that some generated offsets exceed the old near-only range while still remaining in front.

**Step 3: Run tests to verify failure**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL because the current spawner still allows back-facing spawns.

**Step 4: Commit**

```bash
git add tests/unit/test_island_spawner.gd
git commit -m "test: require forward-only island spawns"
```

### Task 2: Implement forward-only spawn geometry

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Test: `tests/unit/test_island_spawner.gd`

**Step 1: Add explicit forward-region helper methods**

Add helpers for the expanded forward range, for example:

```gdscript
func _spawn_preview_half_width() -> float:
	return maxf(spawn_outer_half_width, preview_visible_distance)

func _spawn_preview_half_depth() -> float:
	return maxf(spawn_outer_half_depth, preview_visible_distance)
```

**Step 2: Replace four-sided sampling with front-left / front / front-right sampling**

Implement a generator that only returns offsets with front-facing Z.

```gdscript
match region:
	0: # front-left
	1: # front-center
	2: # front-right
```

**Step 3: Update spawn-band validation to match the new region**

Make sure `is_in_spawn_band()` rejects any back-half offsets.

**Step 4: Run tests to verify pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: forward-only spawn tests pass and existing reveal tests stay green.

**Step 5: Commit**

```bash
git add scripts/islands/island_spawner.gd tests/unit/test_island_spawner.gd
git commit -m "fix: limit island spawns to the forward sector"
```

### Task 3: Add failing tests for island pool reuse

**Files:**
- Modify: `tests/unit/test_island_spawner.gd`
- Reference: `scripts/islands/island_spawner.gd`
- Reference: `scripts/islands/island.gd`

**Step 1: Write a failing test for release-to-pool behavior**

Add a test that cleans up an island and expects it to move into an inactive pool instead of being freed.

```gdscript
spawner.release_island_to_pool(island)
if spawner.get_inactive_pool_size() != 1:
	failures.append("cleaned islands should return to the pool instead of being freed")
```

**Step 2: Write a failing test for acquire-before-instantiate behavior**

```gdscript
var reused = spawner.acquire_island()
if reused != island:
	failures.append("spawner should reuse a pooled island before instantiating a new one")
```

**Step 3: Run tests to verify failure**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: FAIL with missing pool methods or wrong lifecycle behavior.

**Step 4: Commit**

```bash
git add tests/unit/test_island_spawner.gd
git commit -m "test: cover island pool reuse"
```

### Task 4: Implement a simple spawner-owned island pool

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Test: `tests/unit/test_island_spawner.gd`

**Step 1: Add active/inactive pool collections**

Use simple arrays, not a generalized pooling framework.

```gdscript
var inactive_islands: Array[Island] = []
```

**Step 2: Add acquire/release helpers**

```gdscript
func acquire_island() -> Island:
	if not inactive_islands.is_empty():
		return inactive_islands.pop_back()
	return IslandScene.instantiate()

func release_island_to_pool(island: Island) -> void:
	island.deactivate_to_pool()
	inactive_islands.append(island)
```

**Step 3: Use pool release in cleanup instead of `queue_free()`**

Update `_process()` cleanup so distant islands are recycled.

**Step 4: Run tests to verify pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: pool tests pass and no regressions appear.

**Step 5: Commit**

```bash
git add scripts/islands/island_spawner.gd tests/unit/test_island_spawner.gd
git commit -m "feat: add island reuse pool"
```

### Task 5: Add island reset/deactivate lifecycle methods

**Files:**
- Modify: `scripts/islands/island.gd`
- Test: `tests/unit/test_island_current.gd`

**Step 1: Write failing reset/recycle tests**

Add tests that prove a pooled island returns with no stale state.

```gdscript
island.set_preview_state(true)
island.deactivate_to_pool()
island.reset_for_spawn(12.0)
if island.is_preview:
	failures.append("reused islands should reset out of stale preview state unless explicitly reconfigured")
```

**Step 2: Implement `deactivate_to_pool()`**

Make it clear collisions, monitoring, visuals, and tracked bodies.

**Step 3: Implement `reset_for_spawn(...)`**

Make it restore reveal visuals, interaction defaults, and repair rate.

**Step 4: Run tests to verify pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: pooled island reset behavior passes and current/safe-zone tests remain green.

**Step 5: Commit**

```bash
git add scripts/islands/island.gd tests/unit/test_island_current.gd
git commit -m "feat: add island reset hooks for pooling"
```

### Task 6: Integrate pooled spawn with reveal and manual validation

**Files:**
- Modify: `scripts/islands/island_spawner.gd`
- Modify: `scripts/islands/island.gd`
- Modify: `tests/unit/test_island_spawner.gd`
- Modify: `tests/unit/test_island_current.gd`

**Step 1: Ensure reused islands are reconfigured on spawn**

Update `_spawn_next_island()` to:

- acquire from the pool,
- call island reset,
- set position,
- set repair rate,
- apply preview state / reveal defaults.

**Step 2: Run the full test suite**

Run: `godot --headless --path . -s res://tests/run_tests.gd`

Expected: `ALL TESTS PASSED`

**Step 3: Launch the game for smoke validation**

Run: `godot --path .`

Check:

- islands appear farther ahead,
- islands no longer generate behind the boat,
- distant islands are preview-only,
- close islands still activate normally,
- cleanup no longer depends on freeing nodes.

**Step 4: Make only minimal tuning changes if needed**

Tune only exported values such as:

- `preview_visible_distance`
- `active_distance`
- `cleanup_radius`
- `minimum_island_spacing`
- `spawn_retry_limit`

**Step 5: Commit**

```bash
git add scripts/islands/island_spawner.gd scripts/islands/island.gd tests/unit/test_island_spawner.gd tests/unit/test_island_current.gd
git commit -m "feat: spawn islands ahead and reuse pooled instances"
```

## Verification Checklist

- No back-half island spawns remain.
- Farther forward spawns occur beyond the old near-only range.
- Minimum spacing still holds in the narrower forward region.
- Distant islands return to the pool instead of being freed.
- Reused islands reset their state cleanly.
- `godot --headless --path . -s res://tests/run_tests.gd` exits 0.
- `godot --path .` shows front-only spawning and larger forward visibility in practice.

## Notes for the Implementer

- Keep the forward sector testable; favor simple front-left/front/front-right bands over a harder-to-verify polar fan.
- Do not build a generalized pooling subsystem for the whole game.
- Keep pooling local to islands unless the repo later introduces a shared lifecycle abstraction.
- Preserve the current preview/active reveal model; pooling should reuse it, not replace it.
