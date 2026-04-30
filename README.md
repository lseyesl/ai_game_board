# Portrait Boat Survival

A portrait-oriented Godot 4 boat survival prototype. The project uses a very small scene shell and builds the main runtime tree in code from `scripts/main/main.gd`.

## Requirements

- Godot 4.x available as `godot` on your `PATH`

## Run the game

```sh
godot --path .
```

The main scene is `scenes/main/Main.tscn`, which attaches `scripts/main/main.gd` and creates the sea, ship, camera, wave spawner, island spawner, debug overlay, and HUD at runtime.

## Run tests

```sh
godot --headless --path . -s res://tests/run_tests.gd
```

The test harness prints `ALL TESTS PASSED` on success.

## Useful tooling

Inspect the boat GLB tree:

```sh
godot --headless --path . -s res://tools/inspect_board.gd
```

## Project structure

- `project.godot` — Godot project configuration and app metadata.
- `scenes/main/Main.tscn` — thin root scene shell.
- `scenes/islands/Island.tscn` — reusable island scene.
- `scripts/main/` — runtime assembly and restart flow.
- `scripts/core/` — pure rules and run state.
- `scripts/ship/` — boat controller and GLB/collision setup.
- `scripts/waves/` — wave profiles, wave areas, and spawning.
- `scripts/islands/` — island behavior and spawning.
- `scripts/ui/` — HUD built in code.
- `scripts/camera/`, `scripts/world/`, `scripts/input/` — camera, sea, and steering support.
- `tests/` — custom Godot `SceneTree` test harness.

## Controls

Steering input prefers device accelerometer, then gyroscope, and falls back to the default `ui_left` / `ui_right` keyboard actions. After game over, press `ui_accept` or tap/click to restart.
