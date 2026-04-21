# AGENTS.md

## Read first
- Start with `project.godot`, `scenes/main/Main.tscn`, and `scripts/main/main.gd`.
- `Main.tscn` is only a thin shell. The real game tree is assembled in code inside `scripts/main/main.gd`.

## Project shape
- This repo is a single Godot 4 / GDScript project, not a monorepo.
- Runtime subsystems are split under `scripts/`:
  - `core/` = pure rules/state (`run_model.gd`, `ship_rules.gd`, `island_rules.gd`)
  - `ship/` = boat controller and boat GLB loading
  - `waves/` = wave profile, wave areas, spawner
  - `islands/` = island behavior + island spawner
  - `ui/`, `camera/`, `world/`, `input/` = HUD, camera rig, sea, steering abstraction
- `scenes/` is intentionally small. Besides `Main.tscn`, the main reusable prefab is `scenes/islands/Island.tscn`.

## Verified commands
- Run the game: `godot --path .`
- Run the full test suite: `godot --headless --path . -s res://tests/run_tests.gd`
- Inspect the boat GLB tree: `godot --headless --path . -s res://tools/inspect_board.gd`

## Testing gotchas
- The canonical test entrypoint is `tests/run_tests.gd`. It is a custom `SceneTree` harness, not GUT.
- Success is printed as `ALL TESTS PASSED`; failures exit nonzero.
- Some tests require the live `SceneTree` from the harness, so do not try to verify behavior by loading individual test scripts directly.
- Archived docs mention old `godot4 ... addons/gut/...` commands. Treat those as stale unless the repo actually gains an `addons/` test setup.

## Godot/runtime gotchas
- `scripts/main/main.gd` preloads and instantiates nearly every subsystem programmatically.
- `scripts/ship/ship_controller.gd` loads `res://assets/board.glb` at runtime and builds its collision shape in code.
- `scripts/ui/hud.gd` builds the HUD in code.
- `scripts/input/steering_input.gd` prefers accelerometer, then gyroscope, then keyboard fallback via default `ui_left` / `ui_right` actions.
- Restart flow uses `ui_accept` in `scripts/main/main.gd`.

## Repo-local noise to ignore during exploration
- `.godot/` and `.import/` are generated editor/import artifacts.
- `.worktrees/` is an excluded nested worktree area, not primary source.
- `docs/archive/plans/` is useful historical context, but executable source wins over archived prose.
