# Island Spacing and Reveal Design

**Date:** 2026-04-21

## Goal

Fix two player-facing issues in island presentation:

1. Islands should no longer heavily overlap or cluster on top of each other.
2. Islands should feel visible from farther away, with a smooth far-to-near reveal instead of abrupt near-range pop-in.

## Current State

- Island placement is handled in `scripts/islands/island_spawner.gd`.
- The spawner currently creates islands in a rectangular band around the ship using `generate_spawn_offset()`.
- New islands are accepted immediately with no validation against existing island positions.
- Islands are removed only when they move beyond `cleanup_radius` from the ship.
- Islands become visible only when they are spawned near the ship, so the current system behaves like proximity spawning rather than a persistent distant world.
- `scripts/islands/island.gd` currently owns safe-zone and current-ring gameplay behavior, but not any reveal state.

## Approved Product Decisions

- Island distribution should become **uniformly separated**, not merely “less bad.”
- Island reveal should use **fade-in plus slight scale normalization**:
  - distant islands are faint and slightly oversized,
  - nearby islands become fully opaque and return to normal scale.
- Distant islands may be **visual-only previews**.
- Full gameplay behavior such as safe-zone repair and current-ring interaction should turn on only when the island is close enough to become a normal active island.

## Recommended Architecture

### 1. Add spacing-aware spawn selection

Replace the current “pick one random offset and accept it” behavior with a retry-based candidate search.

- The spawner still samples positions relative to the ship.
- Each candidate position is checked against existing islands.
- The candidate is rejected if it is too close to any existing island.
- The spawner retries until it finds a valid point or hits a maximum attempt count.

This keeps the current lightweight spawning model while directly eliminating most overlap.

### 2. Introduce distance-based island presentation states

Each island should move through three conceptual distance bands:

- **Inactive / culled**: too far away to keep.
- **Preview**: visible from farther away, but visual-only.
- **Active**: fully visible and fully interactive.

The preview and active states should not be implemented as two separate scene types unless the existing scene proves too rigid. The preferred design is one island instance whose presentation changes continuously based on ship distance.

### 3. Let islands own their reveal visuals

`scripts/islands/island.gd` should become responsible for presentation transitions.

The island should expose a distance-driven update path that controls:

- shore transparency,
- model transparency if practical,
- overall scale,
- enabling/disabling safe-zone and current interaction.

This keeps the spawner focused on lifecycle and placement, while island visuals remain local to the island scene.

## Detailed Behavior

### Placement

- Keep spawning around the ship rather than introducing a full world map system.
- Enforce a minimum center-to-center island spacing derived from the current island footprint.
- The initial recommended spacing should be larger than `current_radius * 2`, so both visible geometry and gameplay rings stay distinct.
- If the spawner cannot find a valid point after a bounded number of tries, it should skip spawning for that cycle instead of risking a bad placement or an infinite loop.

### Reveal

- Islands should begin appearing earlier than they do now.
- When an island is in preview range:
  - it should be visible,
  - it should render with reduced opacity,
  - it should be scaled slightly above its final size.
- As the ship approaches, opacity and scale should interpolate smoothly toward the normal active presentation.
- When the island enters active range, existing gameplay behavior should become fully enabled.

### Interaction gating

- Preview islands must not repair the boat.
- Preview islands must not apply current push.
- Active islands retain the existing safe-zone and current-area behavior.

## Files Expected to Change

- `scripts/islands/island_spawner.gd`
  - add spacing validation,
  - add retry limits,
  - define preview/active distance thresholds,
  - update existing islands based on ship distance.
- `scripts/islands/island.gd`
  - add reveal-state/presentation support,
  - gate gameplay interactions by active state,
  - expose a method for distance-driven presentation updates.
- `scenes/islands/Island.tscn`
  - ensure materials and nodes can be adjusted at runtime for opacity and scale.
- `tests/unit/test_island_spawner.gd`
  - add spacing and bounded-spawn tests.
- `tests/unit/test_island_current.gd`
  - extend or supplement tests for inactive preview behavior.

## Risks and Mitigations

### Runtime material mutability

If the imported island model does not support straightforward runtime transparency changes, the implementation should still ship with at least:

- shore fade,
- root scale interpolation,
- interaction gating.

That fallback still solves the main UX problem better than the current hard pop-in.

### Dense spawn regions

If the allowed spawn band is too small for the requested spacing, the retry loop may fail frequently. In that case the correct fix is to:

- widen the preview band,
- slightly reduce target count, or
- tune minimum spacing,

instead of bypassing the distance checks.

## Testing Strategy

- Verify generated island positions stay within the allowed ring.
- Verify accepted positions satisfy minimum spacing.
- Verify the spawner stops after a bounded retry count when space is unavailable.
- Verify preview islands do not apply gameplay effects.
- Verify reveal values move in the right direction as ship distance changes.
- Run the full custom test runner and then launch the game scene for visual confirmation.

## Out of Scope

- A persistent world map.
- Chunk streaming.
- Separate far-distance proxy scenes unless required by material limitations.
- A full LOD system beyond the approved preview-to-active reveal.
