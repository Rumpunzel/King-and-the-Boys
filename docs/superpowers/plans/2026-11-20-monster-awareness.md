# Monster Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Monsters notice heroes by the heroes' light and sight and by their own facing, keep a replicated awareness (roaming, hunting, investigating) that players see, pick steps through a strategy, and roam slowly.

**Architecture:** One host-only rule class, `MonsterSenses`, answers who notices whom and updates each monster's `Agent.awareness` after every board change the turn manager makes; awareness is replicated (and saved) through the agent's existing synchronizer. `AgentStateDefault` asks a `MonsterStrategy` resource for each step; `InvestigateStrategy` is the default. The HUD shows "!" / "?" over monsters, and the agent scene marks the investigated cell.

**Tech Stack:** Godot 4.6 GDScript (typed, strict warnings), gdUnit4 integration tests on the model-free fixtures, gdlint.

**Spec:** `docs/superpowers/specs/2026-11-20-monster-awareness-design.md`

## Global Constraints

- Host is the referee: noticing and awareness are decided on the host and replicated; peers only show them. No gameplay in UI scripts.
- Typed GDScript, strict warnings; every new `class_name` gets an `@icon` from `tools/icons/` (white for systems such as `MonsterSenses`, yellow for data such as strategies; reuse a family icon or add one with a row in `tools/icons/CREDITS.md`); new scripts' `.uid` files committed (run `<godot> --headless --path . --import` after adding a `class_name`, editor closed).
- `engine/turns/turn_manager.gd` (679 lines) stays well under 1000: noticing lives in `MonsterSenses`.
- Default roaming speed `1`; dark vision never makes a hero noticeable; a monster notices only from cells inside the hero's own `get_vision()` sight.
- Commands: tests `<godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration` (exit 0 = pass; also grep the output for `SCRIPT ERROR`); lint `python -m gdtoolkit.linter .`; script check `<godot> --headless --path . res://tests/script_check.tscn`. `<godot>` is the console exe from `CLAUDE.local.md`.
- Commit each task on `feature/monster-awareness`; push only when asked.

## Review Focus

1. A hero who is noticed and then undoes a step (or an ability) that did not cause the notice: the undo works, the notice and alert stay. Test in Task 2.
2. A save loaded while monsters hunt: awareness comes back from the save; nothing from the old game stays in `MonsterSenses` (no stale `_noticed` entries closing undos in the new game). Test in Task 2.
3. A monster turned off (`Level.monsters_enabled = false`) or freed while hunting: noticed sets and alerts drop it; no errors on freed characters. Test in Task 2.
4. A held ability previewed (`request_ability_begin`/`adjust`) brings a hero into a monster's view: no notice until it is used. Test in Task 2.
5. An investigating monster whose target cell becomes unreachable (a turned tile closes the way): it does not stall the monster phase; it roams again. Test in Task 3.

---

### Task 1: The noticing rule

**Files:**
- Modify: `engine/objects/characters/character.gd` (`_get_sight_lights`, new `is_lit`)
- Modify: `engine/levels/level_sight.gd`, `engine/levels/level.gd` (pathing to a cell without a sight limit)
- Create: `engine/agents/monster_senses.gd`
- Test: `tests/integration/agents/monster_senses_test.gd`

**Interfaces:**
- Produces:
  - `Character.is_lit() -> bool`: whether the character sees by a light (`not _get_sight_lights().is_empty()`); `_get_sight_lights()` also takes the lights carried by the other standing, visible heroes on its own cell (`Level.get_figures_on(grid_cell, self)`), so a hero beside a torch carrier sees and is lit by that torch.
  - `Level.get_step_towards(from: Vector2i, target: Vector2i) -> int`: first step along passages towards `target` by breadth-first search over placed tiles, `-1` if `from == target` or unreachable. `LevelSight.get_step_towards_in_sight` keeps its behaviour and shares the search.
  - `class_name MonsterSenses extends RefCounted`, `_init(turn_manager: TurnManager, level: Level)`, `notices(monster: Character, hero: Character) -> bool`.

- [ ] **Step 1: Write the failing tests** in `tests/integration/agents/monster_senses_test.gd` (setup as `tests/integration/turns/monster_turn_test.gd`: level from `ModelFreeWorld`, a `TurnManager`, `_spawn_hero`, `_spawn_monster`, `_cell_in_sight(steps)`; a lit hero is a fixture hero profile `duplicate()` with `abilities = [LANTERN]` (`uid://s4o504byc2n0`, starts lit, vision +3); a monster's facing set with `monster.place_on_grid(cell, Vector2.ZERO, direction)`):
  - `test_a_lit_hero_is_noticed_by_a_monster_facing_away` — lit hero on start, monster at `_cell_in_sight(2)` facing away from the start → `notices` true.
  - `test_an_unlit_hero_is_not_noticed_from_beyond_their_sight` — unlit hero (vision 1.5), monster at `_cell_in_sight(2)` facing the start → false.
  - `test_an_unlit_hero_is_noticed_by_a_monster_looking_at_them` — unlit hero, monster at `_cell_in_sight(1)` facing the start → true; facing away → false.
  - `test_an_unlit_hero_is_noticed_on_the_monsters_tile` — both on the start, monster facing away → true.
  - `test_a_hero_in_a_wall_light_is_lit` — tile light `uid://cvimunviu8yb1` (torch_tile_light) on the hero's tile → `is_lit()` true, monster at `_cell_in_sight(2)` facing away notices.
  - `test_a_hero_beside_a_torch_carrier_is_lit` — unlit hero and lit hero on one tile → unlit hero `is_lit()` true and `get_vision()` equals the carrier's.
  - `test_dark_vision_does_not_make_a_hero_noticeable` — unlit hero with `dark_vision = 16.0` (duplicated profile), monster at `_cell_in_sight(2)` facing away → false.
  - `test_a_lantern_put_out_stops_a_notice_from_behind` — lit hero noticed from behind; `request_ability` toggles the lantern → `notices` false.
  - `test_a_turned_off_monster_notices_nothing` — `_level.monsters_enabled = false` → false.
  - `test_the_step_towards_a_cell_follows_passages_beyond_sight` — `_level.get_step_towards(start, cell five steps away)` equals the direction of the first step of a passage path (use `_cells_at`), and `-1` for the start itself.

- [ ] **Step 2: Run them, expect failures** (`MonsterSenses` / `is_lit` / `get_step_towards` missing → script errors count as failure).

- [ ] **Step 3: Implement.** `notices(monster, hero)`: false unless both are valid, visible, inside the tree and on this level; let `seen = level.get_cells_in_sight(hero.grid_cell, hero.get_vision())`; false unless `seen.has(monster.grid_cell)`; true if `hero.is_lit()` or `monster.grid_cell == hero.grid_cell`; else true only if the hero is straight ahead: `offset = hero.grid_cell - monster.grid_cell` is a positive multiple of `Level.direction_to_vector(monster.facing)` and `level.get_cells_in_sight(monster.grid_cell, monster.get_perception()).has(hero.grid_cell)`.

- [ ] **Step 4: Run the suite, expect green**; lint; commit "Notice heroes by their light and sight, or by facing them".

### Task 2: Awareness, its updates, undo and alerts

**Files:**
- Modify: `engine/agents/agent.gd`, `engine/agents/agent.tscn` (replicated awareness)
- Modify: `engine/agents/monster_senses.gd` (`update`, `reset`)
- Modify: `engine/turns/turn_manager.gd` (hooks; `_alert_heroes_seen_by` and `_clear_alerts` go)
- Modify: `engine/objects/characters/character.gd` (`_get_rest`: passed before alerted)
- Test: `tests/integration/agents/monster_awareness_test.gd`; adapt `tests/integration/turns/monster_turn_test.gd` alert tests

**Interfaces:**
- Consumes: `MonsterSenses.notices`, `Level.get_step_towards` (Task 1).
- Produces:
  - `Agent.Awareness { ROAMING, HUNTING, INVESTIGATING }`, `Agent.awareness: Awareness`, `Agent.awareness_target: Vector2i`, `signal awareness_changed`; both properties added to `AgentSynchronizer`'s replication config with `spawn = true`, `replication_mode = 2`, so `SynchronizerSerializer` saves them and older saves load `ROAMING`.
  - `MonsterSenses.update(actor: Character = null) -> void`; `MonsterSenses.reset() -> void` (forgets who was noticed).
  - `TurnManager.get_senses() -> MonsterSenses` (made on first use, host only).

- [ ] **Step 1: Write the failing tests** in `monster_awareness_test.gd` (same setup; `_agent(monster)` = `monster.get_parent() as Agent`):
  - `test_noticing_a_hero_hunts_them` — lit hero, monster in their sight; `get_senses().update()` → `HUNTING`, target the hero's cell, `hero.alerted` true.
  - `test_a_hero_slipping_out_of_notice_is_investigated_where_last_seen` — then the hero's lantern goes out and the monster faces away; `update()` → `INVESTIGATING`, target still the old cell, `hero.alerted` false.
  - `test_an_investigation_ends_where_no_one_is_noticed` — monster placed on its target cell, nobody noticed; `update()` → `ROAMING`.
  - `test_a_monster_hunts_the_nearest_of_two_noticed_heroes`.
  - `test_a_step_that_gets_a_hero_noticed_can_not_be_undone` — lit hero steps into a monster's notice via `request_move` → `undo_steps` 0 and `request_undo` leaves them where they are; an unnoticed step stays undoable.
  - `test_whoever_got_a_hero_noticed_can_not_undo_it` — a lit hero steps onto an unlit hero's tile and that gets the unlit one noticed → both `undo_steps` 0.
  - `test_an_undo_that_got_no_one_noticed_keeps_the_notice` (Review Focus 1).
  - `test_a_previewed_ability_notices_nothing_until_used` (Review Focus 4; `tests/fixtures/held_test_ability.tres` or the turn tile fixture, `request_ability_begin`/`adjust` → no notice, `request_ability` → notice).
  - `test_loading_forgets_who_was_noticed` (Review Focus 2: `stop_monster_phase()` → `alerted` cleared, then a new notice still closes undo exactly once; awareness round-trips through `SynchronizerSerializer` like `tests/integration/levels/level_save_test.gd` saves agents).
  - `test_a_monster_turned_off_or_freed_drops_its_notice` (Review Focus 3).
  - `test_a_passed_hero_shows_the_pass_over_the_alert` (`hero.show_passed(true)` while alerted → `_get_rest()` is `passed_animations`).
  - In `monster_turn_test.gd`: `test_a_hero_a_monster_comes_for_is_on_alert_until_the_next_turn` becomes `test_a_hero_is_on_alert_while_noticed` (lit hero; alert from the moment of notice, still after the turn turned over while the monster stands in sight); `test_a_monster_notices_heroes_by_perception_and_not_by_light` goes (Task 1 covers the new rule); `test_a_monster_hunts_a_hero_it_sees` uses a lit hero.

- [ ] **Step 2: Run them, expect failures.**

- [ ] **Step 3: Implement `update(actor)`** (host only): for each visible monster in the tree on this level, the noticed heroes are those `notices()` accepts. If any: `HUNTING`, target the nearest by `grid_cell.distance_squared_to` (turn order on ties). Else if `HUNTING`: `INVESTIGATING`, target kept. Else if `INVESTIGATING` and standing on the target: `ROAMING`. Each hero noticed now by any monster and not noticed at the last `update` gets `close_undo`, and so does `actor` if it is valid and anyone was newly noticed. `alerted` is true exactly for the heroes noticed now (by any monster). Freed or invisible characters drop out of the noticed set.

- [ ] **Step 4: Hook it into the turn manager** (one call each, after the board changed): `request_move` after `await try_step` (`update(character)`); `request_undo` after a step or ability step was taken back (`update(character)`); `request_ability` after `_use_ability` (`update(character)`); in `_move_monsters` after each `try_step` (`update()`, replacing `_alert_heroes_seen_by`); `_block` after the sequence (`update()`); `stop_monster_phase` calls `reset()` and clears every `alerted`. `_start_next_turn` no longer clears alerts. Not on `request_ability_begin`/`adjust`.

- [ ] **Step 5: `_get_rest()`** checks `shows_passed` before `alerted`.

- [ ] **Step 6: Run the suite, expect green**; lint; script check; commit "Monsters keep a replicated awareness; noticing closes undo and alerts".

### Task 3: Strategies, roaming speed, facing

**Files:**
- Create: `engine/agents/strategies/monster_strategy.gd`, `engine/agents/strategies/investigate_strategy.gd`
- Modify: `engine/objects/characters/character_profile.gd` (`roam_speed`, `strategy`)
- Modify: `engine/agents/state_machine/states/agent_state_default.gd` (asks the strategy; `_wander` moves into `InvestigateStrategy`)
- Modify: `engine/turns/turn_manager.gd` (`_move_monsters` roam limit)
- Modify: `engine/objects/characters/character.gd` (`_look_at_thing_on_tile` skips monsters)
- Test: `tests/integration/agents/monster_strategy_test.gd`

**Interfaces:**
- Consumes: `Agent.awareness`, `Agent.awareness_target` (Task 2), `Level.get_step_towards` (Task 1).
- Produces:
  - `class_name MonsterStrategy extends Resource`, `func choose_step(agent: Agent) -> int` (`-1` to stop; the base stops).
  - `class_name InvestigateStrategy extends MonsterStrategy`: on a tile with a standing hero → `-1`; `HUNTING`/`INVESTIGATING` → `-1` on the target, else `level.get_step_towards(cell, target)`, and if that is `-1` (unreachable) the agent's awareness becomes `ROAMING` and it wanders; `ROAMING` → a random passage, not straight back unless there is no other (today's `_wander`).
  - `CharacterProfile.roam_speed: int = 1` and `CharacterProfile.strategy: MonsterStrategy` (null = a shared `InvestigateStrategy`), both in the monster export group.

- [ ] **Step 1: Write the failing tests** in `monster_strategy_test.gd`:
  - `test_a_roaming_monster_takes_its_roaming_speed_in_steps` — no hero noticed, fixture monster (speed 2) → one step after `_pass_turn()` (track `step_count`).
  - `test_a_hunting_monster_takes_its_full_speed` — lit hero two steps away in sight → monster reaches the hero's tile in one monster phase.
  - `test_a_monster_noticing_mid_turn_uses_the_rest_of_its_speed` — monster roams one step into a lit hero's notice and steps on (step_count 2).
  - `test_an_investigating_monster_goes_to_the_last_seen_cell` — awareness set to `INVESTIGATING` with a target three steps away → it heads there at full speed, then roams.
  - `test_an_unreachable_investigation_turns_to_roaming` (Review Focus 5) — target set to a cell with no passage path → no stall, `ROAMING`.
  - `test_a_monster_keeps_facing_the_way_it_stepped_beside_a_centrepiece` — `_look_at_thing_on_tile` leaves a monster's figure rotation at its facing (put a `Thing` on the tile the way `tests/integration` centrepiece tests do, or assert the method returns without turning for a monster).
  - `test_a_profile_strategy_decides_the_step` — a test strategy (inline `MonsterStrategy` subclass in the test file returning a fixed direction) on a duplicated monster profile is used.

- [ ] **Step 2: Run them, expect failures.**

- [ ] **Step 3: Implement** the two strategy classes, the profile fields, `AgentStateDefault.choose_step()` → `(profile.strategy if profile.strategy else default).choose_step(get_agent())`, and in `_move_monsters` a per-monster count of roaming steps: it steps while it has movement points and either its awareness is not `ROAMING` or it took fewer than `roam_speed` roaming steps this turn.

- [ ] **Step 4: Run the suite, expect green** (adjust `monster_turn_test.gd` tests that assumed full-speed wandering: give their heroes a light, or expect one roaming step); lint; commit "Monsters step by a strategy and roam slowly".

### Task 4: Showing awareness, docs

**Files:**
- Create: `user_interface/hud/awareness_marks.gd` + `.tscn` (a `Control` in the game scene's `UserInterface`, wired in `engine/game.tscn` by `@export` to the level)
- Create: an investigated-cell mark in `engine/agents/agent.tscn` (a `MeshInstance3D`, `top_level`, script `engine/agents/investigation_mark.gd`, on `engine/turns/tile_highlight.gdshader` or a copy in another colour)
- Modify: `CLAUDE.md` (Monsters, Turns, Blocks paragraphs), the spec where the build differed (see Rulings below)
- Test: `tests/integration/agents/awareness_marks_test.gd`

**Interfaces:**
- Consumes: `Agent.awareness`, `awareness_target`, `awareness_changed` (Task 2); `Character.shown`; `BoardObject.get_heads_up_anchor()`.
- Produces: `AwarenessMarks.mark_text(awareness: Agent.Awareness) -> String` (static: `"!"` hunting, `"?"` investigating, `""` roaming).

- [ ] **Step 1: Write the failing tests:** `test_mark_text_per_awareness` (the three strings); `test_a_mark_shows_only_for_a_shown_monster_that_is_not_roaming` (marks node in the tree with the level, a monster hunting and shown → its label visible with "!"; `shown = false` → hidden); `test_the_investigation_mark_sits_on_the_target_cell_only_while_investigating`.
- [ ] **Step 2: Run them, expect failures.**
- [ ] **Step 3: Implement.** `AwarenessMarks` keeps one `Label` per agent (by the level's characters in the `MONSTERS` group whose parent is an `Agent`), positions it each frame like `InputPrompt` (`unproject_position` of the heads-up anchor, hidden behind the camera), shows `mark_text`, pops (a scale tween) on entering `HUNTING`. The investigation mark follows `awareness_changed`: visible on `awareness_target`'s floor while `INVESTIGATING` and the monster is shown, hidden otherwise. Both run on every peer and read only replicated state.
- [ ] **Step 4: Run the suite, lint, script check, smoke run** (`<godot> --headless --path . --quit-after 300`, compare with main); update `CLAUDE.md` and the spec; commit "Show monster awareness over their heads and on the floor".

## Rulings made while planning

- Awareness is saved through the agent's existing `AgentSynchronizer` + `SynchronizerSerializer` (spawn properties) instead of `to_agent_data()`: the synchronizer already saves agent state this way, and older saves load with the defaults.
- No strategy file for the skeleton: a profile without `strategy` uses a shared `InvestigateStrategy`, so the default lives in code, not in each profile.
- A hero is on alert while any monster notices them (the spec says "hunts"; a noticed hero not hunted, because another is nearer, is still in a monster's notice and should look it).
- Light changes outside the turn manager's requests (equipping a torch through `CharacterEquipment`) do not trigger `update()`; the next step or ability does. Lights change only through abilities in play today.
- Nearest noticed hero by grid distance, not path length: noticed heroes are in sight, so the two rarely differ.
