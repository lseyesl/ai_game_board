# Wave Lateral Drift Design

## Problem

Waves are static obstacles — they spawn at a fixed position and never move.
This makes them feel like pillars rather than ocean swell. Adding lateral drift
(perpendicular to the ship's forward direction) creates a more natural, dynamic
sea feel with minimal implementation cost.

## Decision

**Approach A: WaveZone owns its own `_process`**

Each wave independently drifts along the `right` axis (perpendicular to ship
forward). Direction and speed are assigned at spawn time. Large waves drift
faster than small ones.

## Changes

### 1. `scripts/waves/wave_profile.gd`

Add `drift_speed: float` property:

- `small()`: `drift_speed` sampled from `randf_range(1.0, 3.0)`
- `large()`: `drift_speed` sampled from `randf_range(2.0, 5.0)`

### 2. `scripts/waves/wave_zone.gd`

Add drift state and movement:

- New var: `drift_velocity: Vector3 = Vector3.ZERO`
- `_ready()`: `set_process(true)`
- `_process(delta)`: `position += drift_velocity * delta`
- New method: `configure_drift(velocity: Vector3)` — sets `drift_velocity`
- `configure()`: read `drift_speed` from profile (but direction set separately)
- `deactivate_to_pool()`: `set_process(false)`, zero `drift_velocity`
- `reset_for_spawn()`: `set_process(true)`

### 3. `scripts/waves/wave_spawner.gd`

In `_spawn_next_wave()`:

- Compute `right = forward.cross(Vector3.UP).normalized()`
- Randomly pick left or right: `sign = -1.0 if randf() < 0.5 else 1.0`
- Call `wave.configure_drift(right * sign * profile.drift_speed)` after
  `reset_for_spawn`

### 4. `tests/unit/test_wave_spawner.gd`

- Verify spawned waves have non-zero `drift_velocity`
- Verify `deactivate_to_pool` zeroes `drift_velocity` and disables process

## Out of Scope

- Forward-direction wave movement (toward or away from ship)
- Drift speed changes during wave lifetime
- Lateral cleanup boundary (waves still cleaned up by forward-distance check)
