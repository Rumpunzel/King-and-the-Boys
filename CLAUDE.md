# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"King and the Boys" is a Godot 4 (GDScript, Forward Plus, `config/features` = 4.6) cooperative multiplayer dungeon crawler. Players move their characters through a dungeon that is generated as they explore it, in simultaneous, movement-only turns (actions and combat come later). Multiplayer runs over ENet or Steam (GodotSteam); the host is the referee. The turn system's plan, decisions and progress live in the Claude doc "Turn-Based Behaviour Plan" (https://claude.ai/artifact/L2JbNnrgs7fMqo4o4Cpnkt).

## Running

No Godot binary is on PATH. Use 4.6: `/f/Users/Kesepian/Godots/versions/Godot_v4_6-stable_win64_exe/Godot_v4.6-stable_win64.exe` (`..._console.exe` for command line output).

- Run game: `<godot> --path .`
- Open editor: `<godot> -e --path .`
- Smoke check (loads autoloads + main scene, prints script errors): `<godot> --headless --path . --quit-after 300`. `--check-only --script` skips autoloads and reports false errors. Don't start a second `--editor` while the user's editor is open.
- Script check: `<godot> --headless --path . res://tests/script_check.tscn` loads every script of ours (not the vendored addons) so each one compiles; the editor scan and the tests only compile what they load.
- New `class_name`s only resolve after an editor rescan (`<godot> --headless --path . --import`, only while the user's editor is closed).
- Headless runs don't print GDScript warnings; the editor does when it reloads scripts.

Assets (meshes, textures, `.blend`) are in Git LFS (~1.7 GB); `.blend` files need a Blender path in the editor settings.

Tests are gdUnit4 suites (`addons/gdUnit4`, `extends GdUnitTestSuite`, `test_*` funcs), split in two: `tests/unit/` (no level, no assets) and `tests/integration/` (turn rules on a generated level). **No test needs assets**: integration tests build the level from `engine/levels/level.tscn` (the plain level) with the model-free tiles and hero in `tests/fixtures/` (`tests/fixtures/model_free_world.gd`); real profiles hold their model scenes and load meshes and textures with themselves. The fixture profiles are files because spawners replicate structures by their profile's path. Run headless: `<godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration` (exit 0 = pass, 100 = failures). Reports go to `reports/` (gitignored). gdUnit can print a green summary while project scripts fail to compile: also grep for `SCRIPT ERROR`. Test pitfalls: offline, `Player.is_local_player()` is true for every player; Godot treats `append` of two different arrays as the same callable (connect a lambda per array); lambdas copy local variables (share a flag through an array).

Lint: `gdlint .` (gdtoolkit 4.5.0, config in `gdlintrc`, taken from Vagrant: line length 240, only the vendored addons excluded by directory name, so `menagerie` and `tests` are linted). If `gdlint` is not on PATH: `python -m gdtoolkit.linter .`. Don't use `gdformat`.

CI (`.github/workflows/`): **Tests** runs on every push (which covers PR commits): `gdlint`, and `Script check and tests` (script check, then unit and integration tests as separate steps of one job). It needs no Git LFS: the shared setup action (`.github/actions/godot`) leaves `assets/` and `protoype_assets/` out (`.gdignore`) and imports only scripts and small resources. **Asset check** (`asset_check.yml`) runs the main scene with the real assets, only by hand (Actions → Run workflow); run it on `main`, whose caches serve every branch (GitHub drops caches unused for 7 days; then LFS download and import take ~35 min again). CI turns the Blender importer off before importing: without a Blender path, Godot asks how to import `.blend` files and holds back the whole import, so no uid cache is written and every `uid://` path fails. Keep `GODOT_VERSION` in the workflows in sync with `project.godot`. `main` is protected: a pull request merges once `gdlint` and `Script check and tests` passed (no force pushes; merged branches are deleted on GitHub).

## Conventions

- **Game and UI are decoupled.** No gameplay logic or state in UI scripts or scenes: the UI only displays state and forwards the player's intent to game objects (e.g. `PlayerGhost.request_pass`), which own the rules. Settings the UI toggles (e.g. auto-pass) are properties of the game object. UI does not go into game object scenes either: the turn panel lives in the game scene's `UserInterface`, not in `player_ghost.tscn`.
- **The host is the referee.** Clients send requests (RPCs to `Multiplayer.HOST_ID`); the host checks them and changes replicated state. Game state that peers need is replicated by `MultiplayerSynchronizer`s, and each peer turns it into visuals itself.
- **Typed GDScript, strict warnings** (`project.godot`): untyped and inferred declarations and unsafe access/calls are errors. Always use explicit types; put values from untyped `Dictionary`/`Array`s into a typed variable first.
- Node wiring is done through `@export` vars in a "Configuration" export group rather than `$` paths. Many scripts are `@tool`; setters guard with `Engine.is_editor_hint()`.
- References use `uid://` (in scenes, `load()`/`preload()`). `ResourceSaver.save()` outside the editor drops `uid=` attributes.
- Scripts must not `preload` resources that pull in assets (meshes, textures): scripts would no longer compile without the assets, e.g. in CI. Set such resources in scenes instead (e.g. `Level._wall_tile`).
- A `preload` of a scene that uses the preloading script itself is a load cycle (the scene reports the script as missing): load such scenes on use (see `InputPrompt`, `KeyPrompt`).

## Architecture

**Autoloads** (`project.godot`): `Client` (game start/stop, player names and avatars via the game environment, e.g. Steamworks), `GameConfig`, `Multiplayer` (hosting/joining, `HOST_ID`), `Lobby` (players, spawned as `Player` nodes), `SceneManager` (scene transitions with loading screen), `Panorama`, `PhantomCameraManager`, `ToastParty`.

**Folders**: `client/` (multiplayer, networks, lobby, serialization, game environments), `engine/` (game scene, levels, structures/things/characters and their profiles, player, agents, state machines, turns), `user_interface/` (menus, HUD, turn panel, generic controls like `ToggleButton`, `PlayerAvatar`, `PlayerName`), `data/` (authored resources: levels, tiles, characters, gear, model animations), `assets/` and `protoype_assets/` (LFS), `tests/`, `tools/`. Addons: `menagerie` (ours, editor tool for profiles), the rest vendored (`gdUnit4`, `godotsteam`, `phantom_camera`, `debug_draw_3d`, `toastparty`, `radial_progress`, `godot-git-plugin`, `godot-plugin-refresher`).

**Scene flow**: main menu → multiplayer/lobby menus → `engine/game.tscn` (`Game`: `Level` from `data/levels/level.tscn`, `PlayerGhostSpawner`, `TurnManager`, `Serializer`, `UserInterface`). The host's `Game.setup_game()` builds the level, lets peers sync the turn state and spawns a `PlayerGhost` per player.

**Profiles and spawning**: `Profile` → `StructureProfile` / `ThingProfile` / `CharacterProfile` hold names, stats and model variations; `create()` instantiates the node. Spawners replicate nodes by their profile's resource path. Profiles without model variations give no model (used by the test fixtures); levels, structures and characters work without one.

**Level**: `data/levels/level.tscn` inherits `engine/levels/level.tscn` and adds the dungeon tile set (`DungeonTileSet`), starting and wall tiles, sky and floor. The dungeon is generated around the characters as they move (`Level._build_dungeon_from`); sight follows passages. A tile has a logical `Structure.status` (placed, discovered, revealed), set by the host the moment a step brings it into sight, and a `shown_status` (its look), which every peer catches up through reveal and discover queues, one per character: they wait until the peer has the step that raised the tile (`Character.step_count`, `Structure.status_cause` / `status_cause_step`) and the figure entered its cell. Statuses no step raised show at once.

**Turns** (`engine/turns/turn_manager.gd`, host-authoritative): every character gets `CharacterProfile.speed` moves per turn; all players move at once. `request_move`, `request_undo`, `request_pass`, `request_auto_pass` are RPCs the host checks. Undo goes back to the turn start or the character's last board-changing step (a step that discovered or revealed tiles). A turn ends when every connected player has passed. Characters own their grid state (`grid_cell`, `tile_spot`, `facing`, `movement_points`, `undo_steps`, `step_count`, replicated, owned by the host) and animate their figure locally (`Character._apply_grid_visuals`; quick steps redirect the move under way). Tiles hold up to five pieces on spots set by their profile. `PlayerGhost` is the player: it owns `auto_pass` and the undo/pass actions the turn panel's buttons call (with the actions as shortcuts).

**Haunting** (a player controlling another character, from a previous implementation; `PlayerStateHauntingCharacter` / `...Thing`) is kept but tabled; the player's own character is hidden meanwhile.

Saving: `Serializer` collects `NodeSerializer`s (spawned nodes) and `PropertiesSerializer`s (e.g. `SynchronizerSerializer`: a synchronizer's spawn properties, such as the turn number). Passes are cleared on load (player ids differ between sessions).
