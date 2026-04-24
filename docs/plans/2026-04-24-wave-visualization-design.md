# Ocean Wave Visualization — Design Document

## Problem

The game has two independent wave systems with no visual bridge:

1. **Visual ocean** (`Sea` + `water.gdshader`) — pure shader sine waves, follows ship
2. **Gameplay waves** (`WaveZone` + `WaveSpawner`) — Area3D collision zones affecting ship physics/damage, but debug visuals are **hidden by default** (`visible = false`)

Developers cannot see wave zones, making it impossible to debug spawn spacing, drift direction, or large/small wave distribution.

## Solution

Two deliverables:

### A. Enhanced Debug Overlay (in main game)

| Feature | Implementation |
|---------|---------------|
| F1 toggle wave zone visibility | `WaveZone` mesh `visible = true` by default when debug active; global toggle via shortcut |
| F2 toggle debug stats panel | HUD overlay showing: active wave count, pool size, furthest wave distance, large wave ratio |
| Wave zone color enhancement | Small = semi-transparent cyan (#87CEEB), Large = semi-transparent red (#FF0000), Consumed = gray fadeout |

### B. Standalone Debug Scene (`scenes/debug/wave_debug.tscn`)

A separate scene for observing sea and wave state without running the full game:

| Component | Description |
|-----------|-------------|
| Free-flight camera | Bird's-eye / follow mode, WASD move, mouse rotate |
| Sea mesh | Reuse existing `Sea` + `water.gdshader` |
| Wave zone visualization | All WaveZones visible by default + type/status labels |
| Control panel | Live params: `wave_speed`, `wave_amplitude`, `large_wave_chance`, `spawn_distance` |
| Stats dashboard | Active/pooled count, spawn rate, spacing histogram |
| Pause/step | Pause simulation, single-step to observe wave behavior |

## Architecture

```
Main Game Scene (Main.tscn)
├── Existing nodes unchanged
├── DebugOverlay (new) ← F1/F2 toggle
│   ├── Wave zone visibility control
│   └── Debug stats label

Debug Scene (wave_debug.tscn) ← Run independently
├── Sea (reused)
├── WaveSpawner (reused)
├── WaveDebugCamera (new) ← Free flight
├── WaveDebugPanel (new) ← Controls + stats
└── WaveDebugController (new) ← Scene orchestration
```

## File Changes

| File | Change |
|------|--------|
| `scripts/waves/wave_zone.gd` | Modify: `visible = true` when debug active, consumed fadeout, add toggle method |
| `scripts/ui/hud.gd` | Modify: add debug stats label |
| `scripts/main/main.gd` | Modify: add DebugOverlay node, register shortcuts |
| `scripts/debug/debug_overlay.gd` | **New**: F1/F2 shortcut handling + stats collection |
| `scripts/debug/wave_debug_controller.gd` | **New**: Standalone debug scene controller |
| `scripts/debug/wave_debug_camera.gd` | **New**: Free-flight camera |
| `scripts/debug/wave_debug_panel.gd` | **New**: Parameter adjustment + stats display |
| `scenes/debug/wave_debug.tscn` | **New**: Standalone debug scene |

## Constraints

- **No changes** to `water.gdshader` — visual ocean stays as-is
- **No changes** to collision logic — WaveZone behavior unchanged, only visibility
- Debug features **off by default** — zero performance impact in release
- Reuse existing `Sea`, `WaveSpawner`, `WaveZone` — no duplication
