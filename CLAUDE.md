# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"King and the Boys" — a Godot **4.6** (Forward Plus, Jolt Physics) 3D multiplayer game written in **GDScript**. Players are ghosts that "haunt" characters and things in a procedurally generated, grid-based dungeon. No build system or linter; tests use gdUnit4 (`addons/gdUnit4`, suites in `tests/`).

## Commands

Godot 4.6 is installed via Godots at `F:\Users\Kesepian\Godots\versions\Godot_v4_6-stable_win64_exe\` (use `Godot_v4.6-stable_win64_console.exe` for CLI output). `.vscode/settings.json` still points to an old Steam path that no longer exists.

- Open editor: `<godot> --path . -e`
- Run game (main scene): `<godot> --path .`
- Parse/compile check of all scripts: `<godot> --path . --headless --editor --quit`, then grep the output for `Parse Error` / `Compile Error`. It currently segfaults on quit (exit 139); the logged errors are still usable. If the user's editor is open at the same time, the run can report bogus "Preload file … does not exist" errors from the shared uid cache; run it again.
- Run all tests: `GODOT_BIN=<godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests` (exit 0 = pass, 100 = failures, 101 = warnings such as orphan nodes). A single suite: `-a res://tests/equipment/character_equipment_test.gd`. Reports land in `reports/` (gitignored). CI runs the same suites via `.github/workflows/tests.yml` (needs Git LFS for meshes).
- Tests must only use committed data: build items with `EquipmentFixtures` (`tests/equipment/equipment_fixtures.gd`), restore any cached profile you modify, and keep nodes in the tree (`add_child`) so gdUnit does not count them as orphans. `EditorProperty`/`EditorInterface` code cannot be instantiated headless; test its static helpers instead.

Strict typing is enforced as **errors** in `project.godot` (`untyped_declaration`, `inferred_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_call_argument`, etc.). Every variable, parameter and return must be explicitly typed (`var x: int = 0`, not `var x := 0`); casts and typed `for` loop variables are used everywhere to satisfy this.

## Code conventions

- Scenes/resources are referenced by `uid://...` (e.g. `preload("uid://...")`, autoloads in `project.godot`), not by path. Keep `.uid` files alongside scripts.
- Most scripts are `@tool` and implement `_get_configuration_warnings()` to validate `@export` references; guard runtime logic with `if Engine.is_editor_hint(): return`.
- Dependencies are wired via `@export` node references set in scenes, not `get_node` paths.
- Heavy use of `assert` for invariants, `@abstract` classes/methods (Godot 4.5+ feature), and typed `Dictionary[K, V]`.
- Private members are `_prefixed`.

## Architecture

Top-level folders: `client/` (app shell: networking, scene flow, persistence), `engine/` (gameplay code), `data/` (`.tres`/`.tscn` content built on engine types), `user_interface/` (menus, HUD), `assets/` + `protoype_assets/` (models/textures), `addons/` (third-party plugins plus the in-house `menagerie` model-preview editor plugin).

### Autoloads (`project.godot`)
- `Client` (`client/client.gd`) — start/stop/pause game signals; pausing only applies when offline. Owns the `GameEnvironment` (currently always `Steamworks`) for player names/avatars.
- `Multiplayer` (`client/multiplayer/multiplayer.gd`) — host/join/leave via a `Network` strategy (`ENetNetwork` now, `SteamNetwork` exists). Host is peer id 1, max 4 connections.
- `Lobby` (`client/lobby/lobby.gd`) — a `Spawner` that replicates `Player` nodes (per-peer info) across peers.
- `SceneManager` (`client/game/scene_manager.gd`) — threaded scene loading with loading screen. Server can move all peers with `transition_to_scene_remotely` RPC; peers confirm via `confirm_transition` counter. Newly connecting peers are auto-sent to the server's current scene (lobby menu maps to the guest lobby menu). `transition_to_scene_with_setup` runs a callable before/after the scene change (used to build or load a game).
- `GameConfig`, `Panorama` (menu background scenes), plus addon autoloads `PhantomCameraManager`, `ToastParty`.

### Networking model
Server-authoritative using Godot high-level multiplayer. Dynamic content is replicated by subclasses of `Spawner` (`client/network/spawner.gd`, extends `MultiplayerSpawner`): `Lobby`, `LevelSpawner`, `StructureSpawner`, `ThingSpawner`, `AgentSpawner`, `PlayerGhostSpawner`. Each spawner supports two kinds of spawned nodes — scene-path "added nodes" and custom-spawn "data nodes" (built from a `Dictionary[StringName, Variant]` via `spawn_function`, e.g. `to_character_data()`/`apply_character_data()`) — and must implement `get_all_node_data()` / `_remove_all_data_nodes()`. Property replication uses `Synchronizer` (`MultiplayerSynchronizer`).

### Persistence
`Serializer` (`client/serialization/serializer.gd`) saves/loads world state by walking two node groups:
- `SerializersNodes` → `NodeSerializer`s, each bound to a `Spawner`, record which nodes were spawned and respawn them on load.
- `SerializersProperties` → `PropertiesSerializer`s, each with a list of `NodePath:property` entries. Restored in ascending `restoriation_order` (defaults to its `Type`): `NORMAL` (missing = error), `INTANGIBLE` (missing = queued and applied when the node is later added, e.g. late-joining peers), `EPHEMERAL` (missing = dropped).
Nodes are restored first, then properties. Save path is currently `res://test.save` (gitignored). The `State` base class also has `serialize`/`deserialize` so state machines can be persisted.

### Gameplay (`engine/`)
- `Game` (`engine/game.gd`) is the game scene root: on the server `setup_game()` builds the level and starts spawning player ghosts; `save_game`/`load_game` go through `Serializer`; disconnecting returns to main.
- `Level` (`engine/levels/level.gd`) — grid-based procedural dungeon (`grid_size`, `grid_extents`). Builds outer wall, starting tile, then corridors/rooms by picking tiles from a `DungeonTileSet` resource (bitflag-matched blueprints + weighted tiles, with `ConnectionRestriction` resources and `RoomType`s). Tiles have a `Structure.Status` and are progressively revealed/discovered around player-controlled characters (fog-of-war style).
- Object kinds: `Structure`, `Thing`, `Character` — each a scene + spawner + `HitBox` subclass + `SpawnPoint` subclass + `Profile` subclass. `Profile` (abstract `Resource`) holds name, portrait, model variations, collision/hit-box `AreaShape`s; concrete content lives in `data/`. `SpawnTable` / `ProfileSpawnTable` / `NestedSpawnTable` provide weighted random profile selection.
- Models: `Model`, `ModularCharacter` (28 `ModularBodyPart`s addressed via `ModularCharacter.Part` / `get_part()`), and `ModelAnimation` resources (bounce, flip, emerge, slide...) in `data/model_animations/`. A body part picks meshes from a folder by index (editor stepping) or takes an exact mesh via `apply_mesh()`; meshes are matched across parts by their file number (`..._05.res`).
- State machines: generic `StateMachine` (Node) + `State` (`RefCounted`, abstract). `AgentStateMachine` drives NPC `Agent`s (default/haunted); `PlayerStateMachine` drives `PlayerGhost` (default / haunting character / haunting thing). States transition by emitting `finished(next_state)`; initial state is a `GDScript` export.
- Haunting: a `PlayerGhost` interacts (`interact`/`haunt`/`unhaunt` input actions) with a target's `HitBox`, which emits `haunted`/`unhaunted`; the target's state machine then hands control to the player.

### Equipment (`engine/objects/equipment/`)
- `EquipmentProfile` (an item, a `Profile`) = `type` + `appearance` (`EquipmentAppearance` → `EquipmentPartMesh`es: part, male mesh, optional female mesh). Items are saved one per file under `data/equipment/<type>/` (`EquipmentProfile.ITEM_DIRECTORY`), because sync and saves send item paths.
- `EquipmentType` (`data/equipment/types/*.tres`) decides the `slot`, the `parts` its items set, `blocked_slots` (e.g. helmets block FACE), optional `part_groups` (parts sharing a mesh number; the first part leads; left/right pairs are linked automatically) and `excluded_combinations` (keys of mesh numbers, e.g. `"05 03"`, never generated again). `EquipmentProfile.Slot` is stored by number in saved types: only append new slots.
- Slots own fixed parts (`EquipmentProfile.get_slot_parts()`). `CharacterEquipment` (child of `Character`) holds one item per slot; equipping resets every part of the slot and its blocked slots, then applies the item, and is refused while another item blocks the slot. `Character` re-applies body and equipment on every model rebuild.
- `CharacterProfile` has one starting equipment field per slot (`head` … `waist`, named after the slot; `get_starting_equipment_for(slot)`) plus `random_equipment` (one `SpawnTable` per rolled item). `create_character_data()` runs on the server only: it resolves the variation, rolls the base body (`ModelConfigurationRandom.roll()` → `BODY`, mesh paths) and equipment (`EQUIPMENT`, item paths). Character data has 5 keys.
- Sync: `CharacterEquipment.equipped_paths` is replicated by its own `EquipmentSynchronizer`, pinned to server authority even inside a `PlayerGhost` (client) subtree. Peers call `request_equip()` / `request_unequip()`; the server only loads items from the item directory. There is no ownership/inventory check yet. Saves need nothing extra: spawner data already holds the paths.
- Authoring happens in Menagerie (`addons/menagerie/`): the Gear tab's Equipment panel steps through a type's parts, saves items and creates all combinations; the profiles list deletes to the OS trash (optionally excluding combinations); an inspector plugin replaces `CharacterProfile` slot fields with a slot-filtered, grouped picker.
- Design notes and progress: "Equipment Resources Plan" doc (claude.ai, see memory).

### Physics layers (`project.godot`)
1 World, 2 Characters, 3 Things, 4 Structures, 5 WorldAreas, 6 HitBoxes, 7 HurtBoxes, 17 Ghosts, 21 GhostHitBoxes.
