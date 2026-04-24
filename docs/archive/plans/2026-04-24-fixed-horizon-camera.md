# Fixed-Horizon Camera Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the main camera follow the sailboat from a stable angled view relative to the sea plane, preserving yaw-follow and damage bump while ignoring ship pitch/roll.

**Architecture:** Keep runtime wiring in `scripts/main/main.gd` unchanged: `CameraRig.target = ship`. Modify `scripts/camera/camera_rig.gd` so desired position is computed from the target's horizontal heading instead of the full 3D basis, and add a small public update helper to make behavior testable. Add unit coverage through the existing custom Godot harness.

**Tech Stack:** Godot 4.6, GDScript, custom `tests/run_tests.gd` SceneTree harness.

---

### Task 1: Add CameraRig Tests

**Files:**
- Create: `tests/unit/test_camera_rig.gd`
- Create: `tests/run_camera_rig_tests.gd`
- Modify: `tests/run_tests.gd`

Add focused tests proving the camera ignores target pitch/roll, still follows target yaw, and keeps damage bump behavior. Register the camera test in the canonical harness and keep the focused runner for isolated camera verification.

### Task 2: Implement Fixed-Horizon Camera Follow

**Files:**
- Modify: `scripts/camera/camera_rig.gd`

Extract follow math to `update_follow(delta)`, compute the offset from the target's horizontal forward vector, keep fixed vertical height plus `impact_strength`, and look slightly ahead of the ship.

### Task 3: Final Verification

Run diagnostics on modified GDScript files, run `godot --headless --path . -s res://tests/run_camera_rig_tests.gd`, then run `godot --headless --path . -s res://tests/run_tests.gd`.

Do not commit unless the user explicitly asks for a commit.
