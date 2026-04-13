# Portrait Boat Survival Game Design

## Summary

This game is a portrait mobile Godot prototype focused on one-handed, tilt-based boat survival. The player controls a small boat that moves forward automatically across an endless ocean. Random waves push the boat off course, larger waves can launch it into the air and cause damage, and randomly spawned islands act as temporary repair and invulnerability zones. The run ends when ship damage reaches 100%.

The target experience is light, readable, and immediately playable. The player should understand the loop within seconds: steer, survive waves, reach islands to recover, and push for a longer distance score.

## Product Direction

- **Platform:** portrait mobile
- **Engine:** Godot 4
- **Visual style:** simple cartoony 3D/2.5D
- **Control style:** auto-forward movement with gyroscope-only steering
- **Primary score:** distance traveled
- **Game structure:** endless survival run
- **Target feel:** light casual, easy to learn, short-session friendly

## Core Player Experience

The player starts each run already moving forward. Their only continuous input is tilting the device left and right to steer the boat's heading. Waves disrupt that heading and create pressure. Islands break that pressure by offering a safe zone where the ship repairs and becomes invulnerable until it leaves the island radius.

The intended emotional loop is:

1. Maintain control under light wave interference.
2. React to stronger wave threats before they destabilize the run.
3. Spot and reach an island before damage becomes critical.
4. Recover briefly, then re-enter open water and continue pushing for distance.

## Game Loop

### Moment-to-moment loop

1. Boat advances automatically.
2. Player steers by tilting the device.
3. Waves apply drift, lift, and occasional damage risk.
4. Player corrects heading and scans for islands.
5. Entering an island zone repairs damage over time and grants invulnerability.
6. Leaving the island returns the player to normal danger.
7. Distance score continues increasing until damage reaches 100%.

### Failure condition

- Ship damage accumulates from severe wave events.
- The run ends at **100% damage**.
- Final results screen highlights total distance and a few supporting stats.

## Core Systems

### 1. Ship System

The ship owns the player's essential state:

- heading / steering response
- forward movement
- damage percentage
- island invulnerability state
- short-lived hit feedback state

Design rules:

- Forward speed is mostly constant in MVP.
- Gyroscope input should be filtered and smoothed before affecting rotation.
- Steering should feel boat-like, not instant.
- Damage increases gradually across a run, not in huge spikes from minor mistakes.
- Invulnerability only exists while inside an island radius.

### 2. Wave System

Waves are the main hazard source and should be modeled as gameplay events, not full fluid simulation.

Two main wave classes:

#### Small waves
- Appear more frequently.
- Push the boat laterally or rotate its heading.
- Create constant steering pressure.
- Usually do not directly cause damage.

#### Large waves
- Appear less frequently.
- Apply stronger heading disruption.
- Can lift the boat upward enough to trigger an airborne event.
- Landing or excessive launch height can cause damage.

This creates readable escalation: common waves test control, rare waves threaten survival.

### 3. Island System

Islands are not obstacles. They are mobile-run repair stations and pacing anchors.

Island behavior:

- Spawn ahead of the player within reachable lanes.
- Expose a visible safety radius.
- Repair ship damage continuously while the player stays inside.
- Grant full invulnerability while inside.
- Remove both effects immediately on exit.

Design purpose:

- create relief after danger
- give the player a clear short-term target
- prevent runs from becoming pure attrition

## Camera and Framing

The camera should sit behind and above the ship with a mild downward angle. The boat should remain in the lower-middle portion of the portrait frame so the upper screen space can show upcoming waves and islands.

Camera rules:

- prioritize readability over cinematic motion
- keep horizon and upcoming hazards visible
- use only small impact bumps for large waves or damage
- avoid heavy shake that hides steering information

## UI and Feedback

UI should stay minimal and readable.

### Required HUD

- current distance
- best distance or session record marker
- damage bar / percentage
- island invulnerability indicator

### Feedback rules

- Small wave hit: subtle tilt, splash, short audio cue.
- Large wave hit: stronger vertical motion, impact cue, clearer screen response.
- Damage taken: distinct flash or bar pulse.
- Island entry: immediate positive feedback through VFX, color, audio, and repair tick.
- Island exit: clear return-to-danger feedback.

The player should never wonder whether they are safe, damaged, or currently repairing.

## Technical Approach

The MVP should use **Godot 4 with simplified 3D gameplay logic**. The ship should not rely on realistic boat physics. Instead, the game should use deterministic movement with parameterized wave effects.

Recommended implementation style:

- `Node3D` / `CharacterBody3D` driven ship controller
- `Area3D`-based wave hazard zones
- `Area3D`-based island repair zones
- animated sea material for visual motion
- gameplay forces authored through tuning values, not simulation complexity

This keeps the prototype controllable, portable to mobile, and easy to rebalance.

## Scene / System Breakdown

- `Main` scene: owns run lifecycle and world composition
- `Ship`: movement, damage, invulnerability, feedback hooks
- `Sea`: visual ocean plane and ambient motion
- `WaveSpawner`: creates small and large wave zones ahead of the player
- `WaveZone`: stores wave strength, lift, and risk values
- `IslandSpawner`: places islands at readable intervals
- `Island`: repair and invulnerability radius
- `CameraRig`: follows ship and handles mild impact motion
- `HUD`: score, damage, safe-state, game-over display

## Tuning Goals for MVP

These are starting goals, not final values:

- steering feels forgiving and stable
- small waves are frequent but manageable
- large waves are threatening but avoidable often enough to feel fair
- islands appear often enough to rescue a skilled-but-imperfect player
- an average first run lasts long enough to understand the loop

The balancing target is not difficulty first. The balancing target is clarity first, then retention.

## Testing Priorities

### 1. Input clarity
- Does tilt steering feel stable?
- Is there enough smoothing to avoid jitter?
- Can the player correct heading reliably?

### 2. Hazard readability
- Can the player tell what kind of wave is approaching?
- Is damage understandable when it happens?
- Are island safe zones visible enough from a distance?

### 3. Pacing
- Does the run alternate naturally between stress and recovery?
- Are islands arriving too often or too late?
- Are large waves memorable without feeling random or unfair?

## MVP Scope

### Include in MVP

- portrait single-run gameplay loop
- auto-forward boat movement
- gyroscope steering
- small wave and large wave hazards
- ship damage and game over
- random repair islands with inside-radius invulnerability
- distance scoring
- restart flow

### Exclude from MVP

- advanced weather systems
- multiple boat types
- upgrades / meta progression
- economy / shop systems
- realistic ocean simulation
- missions or campaign structure
- complex UI overlays

## Expansion Path After MVP

If the prototype is fun, the next layer can safely add:

- score multipliers for risky routes
- richer wave families
- distance milestones
- unlockable boat cosmetics
- lightweight upgrade choices between runs

Those should only happen after steering feel, island pacing, and wave readability are already strong.

## Final Design Position

The correct first version is a tight, readable, survival-focused prototype. The game should succeed or fail based on whether tilt steering, wave disruption, and island recovery form a satisfying loop within the first few minutes. If that loop works, the rest of the game can grow from it.
