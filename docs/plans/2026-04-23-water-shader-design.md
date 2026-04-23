# Water Shader Design

## Goal
Replace static sea plane with a stylized/cartoon water shader that adds visual life to the ocean surface.

## User Preferences
- **Style**: Cartoon/stylized (not photorealistic)
- **WaveZone boxes**: Hide visual, keep collision
- **Visual layers**: Vertex displacement, normal perturbation, depth color gradient, simple specular

## Changes

### 1. New file: `shaders/water.gdshader`
- Vertex: multi-layer sin() Y displacement (large + medium + ripple)
- Fragment: analytical normal from height derivatives, dual-tone depth gradient (#7EC8E3 high / #3A7CA5 low), hard-edge Blinn-Phong specular for cartoon feel, edge alpha fade
- Uniforms: TIME (automatic), wave_speed, wave_amplitude, sun_direction

### 2. Modify: `scripts/world/sea.gd`
- PlaneMesh: add subdivide_depth=64, subdivide_width=64 for vertex density
- Replace StandardMaterial3D with ShaderMaterial loading water.gdshader
- Pass sun direction uniform matching DirectionalLight3D rotation in main.gd

### 3. Modify: `scripts/waves/wave_zone.gd`
- Set WaveMesh visible=false in _build_visuals()
- Collision and gameplay logic unchanged

## Constraints
- Mobile renderer (project.godot) — no compute shaders, keep simple
- Zero texture dependencies — all procedural
- Must not break existing test suite
