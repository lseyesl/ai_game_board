# Forward Island Spawn and Pooling Design

**Date:** 2026-04-21

## Goal

Improve island spawning so islands appear farther ahead of the boat, only generate in the boat's forward-facing region, and reuse island instances instead of repeatedly allocating and freeing them.

## Current State

- `scripts/islands/island_spawner.gd` currently spawns islands in a four-sided rectangular ring around the ship.
- The current shape allows left, right, front, and back spawn regions.
- Islands beyond `cleanup_radius` are destroyed with `queue_free()`.
- `scripts/islands/island.gd` already supports preview-vs-active state, reveal visuals, and disabling gameplay interaction while previewed.
- There is no existing node pool in the repo; waves and islands both currently use disposable spawn + free patterns.

## Approved Product Decisions

- Island spawn range should be larger than it is now.
- Islands should only spawn in the **forward-facing sector** of the boat.
- The forward sector should be implemented as a practical approximation, not a mathematically perfect radial fan if a simpler shape is easier to test.
- A simple island cache/pool should be added to reduce repeated instance creation cost.

## Recommended Architecture

### 1. Replace four-sided spawning with a forward-only sector

Keep ship-relative spawning, but stop treating all four sides equally.

The recommended implementation is a **three-band forward region**:

- front-left band,
- front-center band,
- front-right band.

This keeps the implementation close to the current rectangular-band logic while producing the feel of a forward-facing cone. It is also much easier to test than a true angle-based polar sampler.

### 2. Keep `IslandSpawner` as the lifecycle owner

Do not add a new manager node.

`scripts/islands/island_spawner.gd` should remain the single owner of:

- spawn selection,
- active-count maintenance,
- distance-based cleanup,
- reveal-state updates,
- island pool acquisition and release.

This matches the repo’s existing pattern where spawners are long-lived manager nodes created by `scripts/main/main.gd`.

### 3. Add explicit island reset/deactivate hooks

`scripts/islands/island.gd` should expose explicit lifecycle methods for reuse, for example:

- `reset_for_spawn(...)`
- `deactivate_to_pool()`

The spawner should not manually reset many internal fields from outside. Island-specific cleanup belongs inside the island script.

## Detailed Behavior

### Spawn region

- Spawn points should be chosen only in front of the boat’s movement direction.
- In this repo, “forward” already corresponds to negative local Z from the ship’s frame of reference.
- Back-facing generation should be removed completely.
- Left and right should only exist as **front-left** and **front-right**, not full side bands that extend behind the boat.

### Range changes

- `preview_visible_distance` should be increased to push first appearance farther ahead.
- `cleanup_radius` must also be reviewed so pooled islands are not immediately released after being spawned farther out.
- `active_distance` remains the threshold for enabling real interaction.

### Pooling

- The spawner should maintain two logical collections:
  - active islands in use,
  - inactive islands available for reuse.
- On spawn request:
  - acquire from the inactive pool if available,
  - otherwise instantiate a new island.
- On cleanup:
  - deactivate the island,
  - hide and disable it,
  - return it to the pool instead of freeing it.

### Island reset responsibilities

When an island is reused, it must reset at least:

- global/local position,
- `repair_rate`,
- preview state,
- reveal ratio/visuals,
- collision and monitoring flags,
- tracked `current_bodies` state.

If the island is released while a ship is overlapping, the release path must safely clear any ongoing interaction state before pooling.

## Files Expected to Change

- `scripts/islands/island_spawner.gd`
  - replace four-sided ring logic with a forward-only region,
  - expand spawn range,
  - add acquire/release pool paths,
  - stop using `queue_free()` for normal island cleanup.
- `scripts/islands/island.gd`
  - add explicit reuse lifecycle methods,
  - guarantee safe reset and deactivate behavior for pooled islands.
- `tests/unit/test_island_spawner.gd`
  - replace behind-spawn assumptions,
  - add forward-only region coverage,
  - add pool reuse coverage.
- `tests/unit/test_island_current.gd`
  - verify pooled islands reset preview/interaction state cleanly if needed.

## Risks and Mitigations

### Narrower spawn region increases placement contention

Forward-only spawning reduces available space, so spacing failures may happen more often.

Mitigation:

- increase retry limit moderately,
- enlarge the preview spawn range,
- keep bounded failure instead of forcing a bad spawn.

### Reused nodes can leak old state

Pooling can leave stale current bodies, disabled collisions, or wrong visuals.

Mitigation:

- put reset/deactivate logic inside `Island`,
- add tests specifically for reused-island state reset.

### Over-design risk

There is no existing pool framework in the repo.

Mitigation:

- use a simple array-based pool owned by `IslandSpawner`,
- avoid introducing a generalized pooling subsystem.

## Testing Strategy

- Verify spawn offsets never appear in the rear half-space.
- Verify at least some generated offsets appear farther out than the old preview range.
- Verify the spawner can still respect minimum spacing in the new forward-only region.
- Verify cleaned-up islands are returned to the pool instead of freed.
- Verify subsequent spawns reuse pooled islands when available.
- Verify reused islands do not retain stale preview state, reveal visuals, or gameplay interaction state.
- Run the full custom harness and then launch the game for smoke validation.

## Out of Scope

- A generalized reusable pooling utility shared by all subsystems.
- Converting waves to use pooling.
- Changing the boat movement model or forward-direction convention.
- Reworking the island scene hierarchy beyond what is required for reuse.
