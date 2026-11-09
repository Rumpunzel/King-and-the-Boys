# King and the Boys

A cooperative multiplayer dungeon crawler made with Godot 4.6.

Players explore a dungeon that unfolds as they walk it. Everyone moves at the same time: each character has a number of moves per turn, steps can be undone until they reveal something new, and the turn ends once every player has passed.

## Getting started

- Godot 4.6 (Forward Plus).
- Git LFS for the assets: `git lfs install`, then clone (or `git lfs pull`).
- `.blend` assets need a Blender path in Godot's editor settings.

Run the game with `godot --path .`, or open the project in the editor.

## Development

- Tests (gdUnit4, no assets needed): `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration`
- Script check: `godot --headless --path . res://tests/script_check.tscn`
- Lint: `gdlint .` (gdtoolkit 4.5.0)

CI runs lint, the script check and all tests on every push; an asset check runs the main scene with the real assets on demand. See `CLAUDE.md` for details on the architecture and conventions.
