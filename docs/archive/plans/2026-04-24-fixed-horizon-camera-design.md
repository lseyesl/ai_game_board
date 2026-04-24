# Fixed-Horizon Camera Follow Design

## Goal

Keep the main camera at a stable angled view relative to the sea plane while it follows the sailboat, so the player can clearly see the boat and nearby ocean without inheriting distracting wave pitch/roll.

## Chosen Approach

Use a hybrid chase camera in `scripts/camera/camera_rig.gd`: follow the ship's position and horizontal heading, but compute the camera offset on the XZ plane and keep the vertical height fixed relative to sea level. The rig continues to smooth movement with `follow_smoothing` and keeps the existing damage bump behavior.

## Behavior

- Camera stays behind and above the ship at a fixed distance and height.
- Camera uses the ship's yaw/forward direction so it remains a useful trailing view as the ship turns.
- Camera ignores ship pitch/roll and visual bobbing for orientation, keeping the horizon steadier.
- Camera looks toward a point slightly above and ahead of the ship for a clear mobile portrait view.
- Existing `request_bump()` damage feedback remains as a temporary vertical offset.

## Alternatives Considered

1. Fixed world-angle translation only: very stable, but the ship can turn away from the visible play area.
2. Full ship-relative camera: immersive, but more likely to feel shaky because it inherits ship tilt.
3. Hybrid yaw-follow camera: stable horizon with useful forward visibility. This is the selected approach.

## Testing

Add focused tests for `CameraRig` to verify that target roll/pitch does not leak into the camera rig, while yaw and target movement still affect the follow position. Run the canonical Godot test harness: `godot --headless --path . -s res://tests/run_tests.gd`.
