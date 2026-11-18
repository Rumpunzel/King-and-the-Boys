# Lobby Hero Picking and Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players pick their hero in the lobby with one button per hero, one hero per player, and guests ready up before the host may start.

**Architecture:** Hero and ready become host-owned state on `Player`, replicated by a second synchronizer under host authority. The pick rules live on the `Lobby` autoload (host side): it holds the hero roster, grants or refuses picks, assigns a free hero to new players and tells whether the host may start. Players ask through RPCs on their `Player`; the lobby UI only shows this state and forwards clicks.

**Tech Stack:** Godot 4.6, typed GDScript, `MultiplayerSynchronizer`, gdUnit4.

**Spec:** `docs/superpowers/specs/2026-11-16-lobby-hero-pick-design.md`

## Global Constraints

- Read `CLAUDE.md` first. Typed GDScript, strict warnings: explicit types everywhere, no `as` on `Variant`s.
- Host is the referee: requests are RPCs to `Multiplayer.HOST_ID`; the host checks and changes replicated state.
- No gameplay rules in UI scripts or scenes.
- Every new `class_name` gets an `@icon` from `tools/icons/` by `uid://` (yellow for data, green for UI); a new icon gets a row in `tools/icons/CREDITS.md`.
- References by `uid://`; new `.tres` files get a header UID (`ResourceUID.id_to_text(ResourceUID.create_id())`).
- Scripts must not `preload` resources holding hero profiles (they pull in models); set them in scenes.
- New `.gd` files: run `<godot> --headless --path . --import` (editor closed) and commit their `.uid`.
- Godot: `/f/Users/Kesepian/Godots/versions/Godot_v4_6-stable_win64_exe/Godot_v4.6-stable_win64_console.exe` (`<godot>` below).
- Tests: `<godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration` (exit 0); also grep the output for `SCRIPT ERROR`. Lint: `python -m gdtoolkit.linter .`. Script check: `<godot> --headless --path . res://tests/script_check.tscn`.
- Commit each task on `feature/lobby-hero-pick`, ending messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Leave the unrelated `data/characters/people/knight.tres` change out. Don't push.
- `ready` is a `Node` signal: the ready flag is named `ready_to_start`.

## Review Focus

1. Two guests clicking the same free hero at once: the host grants one, refuses the other; nobody shows the hero even briefly as theirs. (Task 2 test `test_a_taken_hero_is_refused`.)
2. A guest unreadies while the host clicks Start: the host checks `Lobby.can_start()` again in `_on_start_pressed` and does nothing. (Task 5 step.)
3. A peer connected but without a `Player` yet: `can_start()` is false. (Task 2 test `test_start_waits_for_a_peer_without_a_player`.)
4. A reconnecting player in the running game is given no lobby hero and their requests are refused. (Task 2 test `test_picks_are_refused_once_closed`.)
5. A player leaving frees their hero for the next pick and for the random assignment. (Task 2 test `test_a_leaving_player_frees_their_hero`.)

---

### Task 1: Hero roster resource

**Files:**
- Create: `engine/objects/characters/hero_roster.gd` (`class_name HeroRoster extends Resource`, yellow `@icon`)
- Create: `data/characters/heroes.tres` (the six heroes, in the order of `_available_characters` in `user_interface/menus/lobby_menu/character_selection.tscn`)
- Create: `tests/fixtures/second_hero.tres` (copy of `tests/fixtures/hero.tres` with another `name`, model-free), `tests/fixtures/heroes.tres` (`HeroRoster` of `hero.tres`, `second_hero.tres`)
- Test: `tests/unit/lobby/hero_roster_test.gd`

**Interfaces:**
- Produces: `HeroRoster.heroes: Array[CharacterProfile]` (`@export`); `HeroRoster.has(profile: CharacterProfile) -> bool`.

- [ ] **Step 1: Write the failing test** `test_the_roster_knows_its_heroes`: load `tests/fixtures/heroes.tres` (by `uid://`, path in a comment); `assert_bool(roster.has(hero)).is_true()` for both fixture heroes; `assert_bool(roster.has(null)).is_false()`; a `CharacterProfile.new()` gives false.
- [ ] **Step 2: Run the tests, expect a failure** (unknown class `HeroRoster`; run `--import` first so the new class resolves).
- [ ] **Step 3: Write `HeroRoster`, the three `.tres` files.**
- [ ] **Step 4: Run tests, script check and lint; expect all green.**
- [ ] **Step 5: Commit** (`Add the hero roster`), including the new `.uid` files.

### Task 2: Pick and ready rules on the Lobby

**Files:**
- Modify: `client/lobby/lobby.gd`
- Modify: `client/lobby/player/player.gd`
- Test: `tests/unit/lobby/hero_pick_test.gd`

**Interfaces:**
- Consumes: `HeroRoster` (Task 1).
- Produces, on `Lobby` (host side; none of these are RPCs):
  - `var hero_roster: HeroRoster` (null: no heroes are assigned or checked, so suites not about picks are unaffected).
  - `var picks_open: bool = true`; `func close_picks() -> void` (sets false); opened again in `_on_game_started` and `_on_joining_multiplayer`.
  - `signal readiness_changed` (emitted whenever a player's hero or `ready_to_start` changes, a player joins or leaves).
  - `func get_holder(profile: CharacterProfile) -> Player` (null if free).
  - `func get_free_heroes(for_player: Player) -> Array[CharacterProfile]` (roster heroes held by nobody else, roster order).
  - `func try_pick(player: Player, profile: CharacterProfile) -> bool`: false unless `picks_open`, `hero_roster.has(profile)`, not `player.ready_to_start`, and `get_holder(profile)` is null or `player`. On success sets `player.character` (own hero again: nothing changes, true).
  - `func pick_random(player: Player) -> bool`: `try_pick` of a random free hero other than the current one (the current one if it is the only free one).
  - `func try_set_ready(player: Player, ready: bool) -> bool`: false unless `Multiplayer.is_online()`, `picks_open` and `not player.is_host()`.
  - `func can_start() -> bool`: offline true; online `_can_start_with(multiplayer.get_peers())`.
  - `func _can_start_with(peers: PackedInt32Array) -> bool`: every id in `peers` has a `Player` with `ready_to_start`.
  - Host side, `_spawn_player` assigns `pick_random(player)` when `is_multiplayer_authority()`, `hero_roster` is set and `picks_open`.
- Produces, on `Player`:
  - `var ready_to_start: bool` (setter emits `player_info_changed`).
  - The player_id setter calls `set_multiplayer_authority(player_id, false)` so children keep the host's authority (Task 3 adds the child).

- [ ] **Step 1: Write the failing tests.** Offline (`is_local_player()` is true for all; see `tests/unit/lobby/lobby_test.gd` for joining players by `Lobby.call("_on_player_joined", info)` and cleaning up). `before_test` sets `Lobby.hero_roster` to the fixture roster and `picks_open = true`; `after_test` removes joined players and sets `hero_roster = null`. Tests:
  - `test_a_joining_player_gets_a_free_hero`: two joins get the two different fixture heroes.
  - `test_a_free_hero_is_granted`: after freeing one (leave), `try_pick` of it is true and `player.character` is it.
  - `test_a_taken_hero_is_refused`: `try_pick(b, a.character)` is false, `b.character` unchanged.
  - `test_the_own_hero_is_accepted`: `try_pick(a, a.character)` is true.
  - `test_a_hero_outside_the_roster_is_refused`: `try_pick(a, CharacterProfile.new())` is false.
  - `test_a_ready_player_cannot_change_hero`: set `a.ready_to_start = true` directly, `try_pick` of a free hero false.
  - `test_ready_is_refused_offline`: `try_set_ready(a, true)` false.
  - `test_picks_are_refused_once_closed`: `close_picks()`; `try_pick` false; a player joining now gets no hero (`character` null).
  - `test_a_leaving_player_frees_their_hero`: after `_on_peer_disconnected`, `get_holder(old_hero)` is null and it is in `get_free_heroes(other)`.
  - `test_start_waits_for_a_peer_without_a_player`: one joined player (`JOINING_ID`) readied directly; `Lobby.call("_can_start_with", PackedInt32Array([JOINING_ID]))` is true, with `[JOINING_ID, 7]` false; unreadied, `[JOINING_ID]` false. `test_start_is_allowed_offline`: `can_start()` true.
- [ ] **Step 2: Run the tests, expect failures** (missing members).
- [ ] **Step 3: Implement** the Lobby members and `Player.ready_to_start` above. Emit `readiness_changed` from the player's `player_info_changed` (connect in `_spawn_player`) and from join/leave. Remove nothing else yet.
- [ ] **Step 4: Run all tests (unit + integration), script check, lint; expect green.** `game_start_test.gd` must still pass (it builds players without a roster).
- [ ] **Step 5: Commit** (`Let the lobby decide hero picks and ready`).

### Task 3: Host-owned sync and requests

**Files:**
- Modify: `client/lobby/player/player.tscn`, `client/lobby/player/player.gd`
- Test: `tests/unit/lobby/hero_pick_test.gd` (one more test)

**Interfaces:**
- Consumes: Task 2's `Lobby.try_pick`, `pick_random`, `try_set_ready`.
- Produces, on `Player`:
  - `@rpc("any_peer", "call_local", "reliable") func request_character(character_id: String) -> void` and `request_pick_random()`, `request_ready(new_ready: bool)`: on the host only; the sender (`multiplayer.get_remote_sender_id()`, `0` locally meaning `Multiplayer.HOST_ID`) must equal `player_id`, else ignored. `request_character` resolves the id with `ResourceId.find()` after checking `ResourceId.get_file_path(id)` is the path of a roster hero; then calls the Lobby rule.
  - `func ask_for_character(profile: CharacterProfile) -> void`, `ask_for_random_character()`, `ask_for_ready(new_ready: bool)`: what the UI calls; each sends its request with `rpc_id(Multiplayer.HOST_ID, …)`.
  - `func reroll_body() -> void`: local player only, `body = character.roll_body(0)`.
  - `_serialized_character` is replaced by `_character_id: String` (`ResourceId.of(character)` / `ResourceId.find()`), replicated with `ready_to_start` by a new child `HostSynchronizer` (`MultiplayerSynchronizer`, `root_path = ".."`, properties `.:_character_id` and `.:ready_to_start`, spawn and on change). `player.tscn`'s own config keeps `player_name` and `body` only. The existing `character` setter (rolls the body when the local player's hero changes) stays. Peers trust the hero the host syncs (the host is that synchronizer's authority), so only the host's requests check the roster; this replaces the spec's "peers accept only heroes in the roster".

- [ ] **Step 1: Write the failing test** `test_a_request_from_another_peer_is_ignored`: call `player.request_character(ResourceId.of(free_hero))` directly offline on a joined player whose `player_id` is not `Multiplayer.HOST_ID`; its `character` is unchanged (the local sender counts as the host). And `test_the_hosts_request_is_granted`: the same on the host's own player (create it as `lobby_test.gd` `before()` does) picks the hero.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement** the synchronizer, the requests and `ask_*`, `reroll_body`.
- [ ] **Step 4: Run tests, script check, lint; expect green.** Smoke check: `<godot> --headless --path . --quit-after 300`, no new errors.
- [ ] **Step 5: Commit** (`Sync heroes and ready from the host`).

### Task 4: Hero buttons and stats in the lobby

**Files:**
- Create: `user_interface/menus/lobby_menu/hero_picker.gd` + `.tscn` (`class_name HeroPicker extends Container`, green `@icon`)
- Create: `user_interface/menus/lobby_menu/hero_stats.gd` + `.tscn` (`class_name HeroStats extends Container`, green `@icon`)
- Modify: `user_interface/menus/lobby_menu/lobby_menu.gd` (+ its scenes: `lobby_host_menu.tscn`, `lobby_guest_menu.tscn` inherit it), `lobby_player_panel.gd`, `lobby_player_panel.tscn`
- Delete: `user_interface/menus/lobby_menu/character_selection.gd`, `.tscn` (and its `.uid`), once nothing uses it

**Interfaces:**
- Consumes: `Lobby.hero_roster`, `get_holder()`, `readiness_changed`; `Player.ask_for_character()`, `ask_for_random_character()`, `reroll_body()`, `character`, `ready_to_start`.
- Produces:
  - `LobbyMenu` exports `_hero_roster: HeroRoster` (set to `data/characters/heroes.tres` in the scene) and sets `Lobby.hero_roster` in `_enter_tree` (outside the editor).
  - `HeroPicker.player: Player`: one `Button` per roster hero (portrait from `Profile.portrait`, name); disabled when held by another player (text adds the holder's `player_name`) or `player.ready_to_start`; the own hero pressed/highlighted. Pressing another hero calls `player.ask_for_character(hero)`; pressing the own hero calls `player.reroll_body()`. Rebuilds its state on `Lobby.readiness_changed`.
  - `HeroStats.character: CharacterProfile`: name; Strength, Intelligence, Agility, Movement (`strength`, `intelligence`, `agility`, `speed`); one label or icon per `Ability` with `Ability.description` as `tooltip_text` (`Ability.icon` when set, else `Ability.name`).
  - `LobbyPlayerPanel`: the local panel holds a `HeroPicker` and a `HeroStats`; other panels a `HeroStats` (or the existing `CharacterPanel`) only. Drop the panel's `if not player.character: player.character = …` (the host assigns now); R calls `player.ask_for_random_character()`.

- [ ] **Step 1: Write the failing test** `tests/unit/lobby/hero_stats_test.gd` `test_the_stats_show_the_heroes_values`: instance `hero_stats.tscn`, `add_child`, set `character` to `tests/fixtures/hero.tres`; the labels' text contains its `strength`, `intelligence`, `agility`, `speed`, and the ability tooltips equal the abilities' descriptions.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement** the two controls, wire them into the panels and `LobbyMenu`, delete `CharacterSelection`. Keep `LobbyMenu._update_preview` as is (a new hero rebuilds and plays `selected_animation`, a new body redresses).
- [ ] **Step 4: Run tests, script check, lint; expect green.** Run the game offline (`<godot> --path .`), open the lobby: every hero has a button, clicking switches the stage model and stats, clicking the own hero rerolls the look, R picks another; screenshot or describe.
- [ ] **Step 5: Commit** (`Pick heroes with buttons in the lobby`), with new `.uid`s.

### Task 5: Ready toggle and Start gate

**Files:**
- Modify: `user_interface/menus/lobby_menu/lobby_player_panel.gd`, `lobby_host_menu.gd`, `lobby_host_menu.tscn`

**Interfaces:**
- Consumes: `Player.ask_for_ready()`, `ready_to_start`; `Lobby.can_start()`, `close_picks()`, `readiness_changed`; `Multiplayer.is_online()`.

- [ ] **Step 1: Ready toggle.** `_ready_button` shows only online and for guests (hidden for the host's player and offline). On the local guest's panel it is enabled and calls `player.ask_for_ready(pressed)`; its pressed state follows `player.ready_to_start` (set without re-sending). On other panels it is disabled and shows their state. Remove `_update_player_panel`'s forced `button_pressed = true`.
- [ ] **Step 2: Start gate.** `LobbyHostMenu` enables Start only when `Lobby.can_start()`; online its text reads `"Start (%d / %d ready)"` (ready guests / connected peers), offline `"Start"`. Refresh on `Lobby.readiness_changed`, `multiplayer.peer_connected` / `peer_disconnected` and the hosting toggles. `_on_start_pressed` returns at once unless `Lobby.can_start()`, then calls `Lobby.close_picks()` before closing the menu.
- [ ] **Step 3: Run tests, script check, lint; expect green.**
- [ ] **Step 4: Manual multiplayer check** with two windowed instances over ENet (host + join on localhost): picks grey out on both; a taken hero can't be clicked; the guest's Ready locks their buttons and shows on the host; Start is off with "0 / 1 ready", on with "1 / 1 ready"; the guest unreadying turns it off; the guest leaving frees their hero; Start leads into the game with each player's picked hero and look. Report what was seen.
- [ ] **Step 5: Commit** (`Gate the start on ready guests`).

### Task 6: Project notes

**Files:**
- Modify: `CLAUDE.md` (Architecture: `Lobby` autoload line and the lobby part of "Scene flow" / Equipment's `Player.body` note: heroes are picked with buttons, one each, host-owned `character`/`ready_to_start` via `HostSynchronizer`, `Lobby.hero_roster` = `data/characters/heroes.tres` set by `LobbyMenu`, R asks for a random free hero, Start waits for every guest's ready online).

- [ ] **Step 1: Update `CLAUDE.md`** in its existing style (plain sentences, names of the members).
- [ ] **Step 2: Lint and full test run once more; expect green.**
- [ ] **Step 3: Commit** (`Note hero picking and ready in CLAUDE.md`).
