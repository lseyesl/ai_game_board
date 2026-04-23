# Boat Bobbing Enhancement Design

## Goal

Make the sailboat visibly bob up and down following wave motion, with natural
multi-frequency oscillation and pitch/roll rotation for immersion.

## Current State

- `ship_controller.gd` line 60: single sine bob `sin(ticks*0.004)*0.15` — mechanical, barely visible
- `wave_vertical_velocity` handles one-shot bounce from large waves
- No pitch or roll rotation

## Design

### 1. Multi-harmonic bob (vertical)

Replace single sine with 3 overlapping harmonics:

```gdscript
var t := Time.get_ticks_msec() / 1000.0
var bob_offset := sin(t * 2.0) * bob_strength \
    + sin(t * 3.7) * bob_strength * 0.3 \
    + sin(t * 0.8) * bob_strength * 0.5
```

Increase `bob_strength` default from 0.15 → 0.4.

### 2. Speed modulation

Scale bob amplitude by forward speed:

```gdscript
var speed_factor := clampf(forward_speed / 18.0, 0.3, 1.5)
bob_offset *= speed_factor
```

### 3. Pitch (fore-aft tilt)

Apply to BoatModel node (not ShipController) to avoid Y-rotation conflicts:

```gdscript
var pitch := sin(t * 2.0 + 0.5) * pitch_strength * speed_factor
boat_model.rotation_degrees.x = pitch
```

### 4. Roll (side-to-side tilt)

Different frequency for async feel:

```gdscript
var roll := sin(t * 1.3 + 1.0) * roll_strength * speed_factor
boat_model.rotation_degrees.z = roll
```

### 5. New export variables

```gdscript
@export var pitch_strength: float = 2.5
@export var roll_strength: float = 1.8
```

### 6. Wave bounce pause

When `wave_vertical_velocity > 0` or `position.y > base_y + 0.05`,
skip bob/tilt — let physics bounce dominate. Reset BoatModel rotation to zero.

## Scope

- Only `scripts/ship/ship_controller.gd` modified
- No new files, no WaveZone changes
- Existing tests must still pass
