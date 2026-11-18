# Turn Phases and Staged Blocks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Named, replicated turn phases walked in order by the host, and blocks run by their own `BlockSequence` through replicated, paced stages.

**Architecture:** `TurnManager.Phase` grows to `HEROES, HERO_BLOCKS, MONSTER_MOVES, MONSTER_BLOCKS`; `_run_monster_phase` walks them with a short pause on each phase the heroes can see. A `BlockSequence` (RefCounted, one per block) owns a block's life (roll, choice, strike, apply, pauses) and publishes its stage in `TurnManager.block_state` (replicated, replaces `block_choice`); the turn manager keeps the RPCs and replicated properties and awaits the sequence.

**Tech Stack:** Godot 4.6 GDScript (typed, strict warnings), gdUnit4, gdlint.

**Spec:** `docs/superpowers/specs/2026-11-18-turn-phases-design.md`

## Global Constraints

- Typed GDScript, strict warnings as errors; Variants from dictionaries go into typed variables first; a freed instance never goes into a typed variable (index loops + `is_instance_valid`).
- New `class_name` gets `@icon("uid://3xn0cgn4onrw")` (the turn family's, as `Block`); run `--import` once (segfault at exit is harmless) and commit the new `.uid`.
- gdlint: max 1000 lines per file, max 40 public methods; `turn_manager.gd` must shrink.
- Host is the referee: `block_state` and `phase` are replicated by `TurnSynchronizer` in `engine/game.tscn` (property path `.:block_choice` → `.:block_state`); the strike stays the `show_block` RPC to `_synced_peers`.
- Pauses are tweens on the turn manager (`create_tween().tween_interval()`), never timers; they only run when the block's or phase's cells are revealed (`is_in_sight`).
- No block rule changes. Run after every task: lint (`python -m gdtoolkit.linter .`), script check, unit + integration tests (commands in `CLAUDE.md`), grep the output for `SCRIPT ERROR`.

## Review Focus

- A save loaded while a block pauses at `ROLLED` (not only while choosing): the block is dropped, `block_state` is cleared, nothing is applied (test in Task 1).
- A figure of the block freed during the roll pause (its player leaves): `run()` returns `null`, no error (test in Task 1).
- A choice answer arriving while the stage is `ROLLED` or `STRUCK`, or naming an older choice id: ignored (test in Task 1).
- Another player's request (move, pass, undo) during any stage of a block in the heroes' turn: refused, and the turn does not end mid-block (test in Task 1).
- A monster phase where nothing is in sight: no phase pauses, it finishes within a few frames (test in Task 2).

---

### Task 1: BlockSequence and the replicated block state

**Files:**
- Create: `engine/turns/block_sequence.gd` (+ `.uid`)
- Modify: `engine/turns/turn_manager.gd`, `engine/game.tscn` (synchronizer path), `engine/player/player_controller.gd` (`block_choice` → `block_state`), `user_interface/hud/combat_status.gd` (rename only, behaviour in Task 3)
- Test: `tests/integration/turns/block_test.gd` (update + new), `tests/integration/turns/formation_test.gd`, `monster_turn_test.gd`, `combat_status_test.gd` (renames)

**Interfaces:**
- Produces, `BlockSequence extends RefCounted`:
  - `enum Stage { ROLLED, CHOOSING, STRUCK }`
  - keys of `block_state`: `const STAGE, ATTACKER, DEFENDER, DICE, CHOSEN, PINNED, CHOICE_ID, PICKER: StringName` (`ATTACKER`/`DEFENDER` are node paths, `DICE` an `Array[int]` of `Block.Face`, `CHOSEN` only from `STRUCK`, `CHOICE_ID`/`PICKER` only at `CHOOSING`)
  - `const _ROLL_PAUSE: float = 0.6`, `const _STRIKE_PAUSE: float = 0.8` (the old `_BLOCK_PAUSE`)
  - `func _init(turn_manager: TurnManager, level: Level, attacker: Character, defender: Character) -> void`
  - `var block: Block`
  - `func run() -> Block` — coroutine: face the attacker, `block.roll`, publish `ROLLED`, pause if in sight, ask if more than one die and a connected player picks (publish `CHOOSING`, wait ≤ `choice_timeout` while the player stays), `update_pinned`, pick, publish `STRUCK` with `CHOSEN`, `turn_manager.broadcast_block(block)`, `block.apply`, `turn_manager.blocked.emit(block)`, close both undo stacks, pause `_STRIKE_PAUSE` and wait for a pushed defender's hop if in sight, clear `block_state`. Returns `null` (state cleared, nothing applied) if cancelled or a figure is freed at any await.
  - `func answer(sender_id: int, choice_id: int, value: int) -> void` — counts only at `CHOOSING`, for the open id, from the picker, `0 <= value < dice.size()`
  - `func cancel() -> void`
  - choice ids count up in a `static var` so an id is never reused across sequences
- Produces, `TurnManager`:
  - `var block_state: Dictionary` (setter emits `signal block_state_changed`); `block_choice`, `block_choice_changed`, `CHOICE_*` removed
  - `func is_in_sight(cell: Vector2i) -> bool`, `func wait_for_figure(character: Character) -> void`, `func close_undo(character: Character) -> void`, `func broadcast_block(block: Block) -> void` (public versions of `_is_in_sight`, `_wait_for_figure`, `_close_undo`, the `show_block` loop)
  - `_block(attacker, defender) -> Block` keeps its signature: makes the sequence, holds it in `_block_sequence`, awaits `run()`
  - `request_block_choice(choice_id, value)` forwards to `_block_sequence.answer(_get_sender_id(), choice_id, value)`
  - `_cancel_choice()` becomes `_cancel_block()` (cancels the sequence, clears `block_state`)
  - removed: `_ask`, `_get_choosing_player`, `_is_still_on`, `_chosen`, `_choice_run`, `_choice_count`, `_step_blocks`, `_wait_for_block`, `_BLOCK_PAUSE` (the monster loop no longer waits per block: `try_step` awaits the sequence, pauses included)
  - every check of `block_choice.is_empty()` becomes `block_state.is_empty()` (requests wait during any stage)

- [ ] **Step 1: Write the failing tests in `block_test.gd`**
  - `test_a_block_goes_through_its_stages`: record `block_state[STAGE]` on each `block_state_changed` (and `{}` as `-1`); a one-die block in sight gives `[ROLLED, STRUCK, -1]`; with a choice (`choice_timeout = 30`, answered) `[ROLLED, CHOOSING, STRUCK, -1]`.
  - `test_a_block_in_sight_pauses_after_the_roll`: msec between `ROLLED` and `STRUCK` `>= roundi(BlockSequence._ROLL_PAUSE * 1000) - 50`.
  - `test_a_hidden_block_does_not_pause`: block on an unrevealed tile; `ROLLED` to cleared within 2 frames.
  - `test_loading_during_the_roll_drops_the_block`: during `ROLLED`, `stop_monster_phase()` → `block_state` empty at once, `_blocks` stays empty 30 frames later, positions and postures unchanged.
  - `test_a_figure_leaving_during_the_roll_drops_the_block`: `queue_free` the defender during `ROLLED`; no `blocked`, `block_state` empty, no script error.
  - `test_answers_count_only_while_choosing`: `request_block_choice` with the next choice id during `ROLLED` does nothing; then at `CHOOSING` an older id does nothing (adapt the existing check).
  - `test_requests_wait_during_any_stage`: during `ROLLED` of a hero's leaving block, `request_pass(true)` and another hero's `request_move` change nothing.
  - Update the existing tests: `block_choice` → `block_state`, `CHOICE_ID` → `BlockSequence.CHOICE_ID`, `CHOICE_PICKER` → `BlockSequence.PICKER`, `CHOICE_DICE` → `BlockSequence.DICE`; the `_BLOCK_PAUSE` timing test uses `BlockSequence._STRIKE_PAUSE`.
- [ ] **Step 2: Run the integration tests; expect compile failures / FAIL for the new names**
- [ ] **Step 3: Create `BlockSequence` and slim the turn manager as in Interfaces; rename in `game.tscn`, `player_controller.gd`, `combat_status.gd` (it reads `block_state` at `CHOOSING` where it read `block_choice`)**
- [ ] **Step 4: `--import`, then lint, script check, unit + integration tests: all pass, no `SCRIPT ERROR`**
- [ ] **Step 5: Commit** (`git add` the new `.gd` and `.uid`) — "Run blocks through a BlockSequence with replicated stages"

### Task 2: Named phases walked in order

**Files:**
- Modify: `engine/turns/turn_manager.gd`
- Test: `tests/integration/turns/monster_turn_test.gd`, and the `Phase.MONSTERS` uses in `block_test.gd`, `combat_status_test.gd`

**Interfaces:**
- Consumes: `is_in_sight` (Task 1)
- Produces: `enum Phase { HEROES, HERO_BLOCKS, MONSTER_MOVES, MONSTER_BLOCKS }`; `func is_heroes_turn() -> bool`; `const _PHASE_PAUSE: float = 0.6`
- `_run_monster_phase()`: `_end_heroes_turn()`, then for each of `HERO_BLOCKS`, `MONSTER_MOVES`, `MONSTER_BLOCKS`: set `phase`, await `_PHASE_PAUSE` only if the phase has something in sight (blocks: a tile with standing heroes and monsters that `is_in_sight`; moves: a monster on a revealed tile), run it (`_block_on_shared_tiles(HEROES)`, `_move_monsters()` = the loop moved out of `_run_monster_phase`, `_block_on_shared_tiles(MONSTERS)`), check the run counter after every await; then `phase = HEROES` and `_start_next_turn()`.
- Every `phase != Phase.HEROES` check becomes `not is_heroes_turn()`.

- [ ] **Step 1: Write the failing tests in `monster_turn_test.gd`**
  - `test_the_phases_run_in_order`: hero and monster on one revealed tile; record `phase_changed` across a pass: `[HERO_BLOCKS, MONSTER_MOVES, MONSTER_BLOCKS, HEROES]`.
  - `test_a_phase_in_sight_pauses_before_it_acts`: msec from `HERO_BLOCKS` to the first `blocked` `>= roundi(TurnManager._PHASE_PAUSE * 1000) - 50`.
  - `test_a_phase_with_nothing_in_sight_does_not_pause`: only a monster on an unrevealed tile; from pass to `HEROES` within 5 frames.
  - Replace `Phase.MONSTERS` checks with `not is_heroes_turn()` / the exact phase.
- [ ] **Step 2: Run; expect FAIL (unknown enum values)**
- [ ] **Step 3: Implement as in Interfaces**
- [ ] **Step 4: Lint, script check, unit + integration tests pass**
- [ ] **Step 5: Commit** — "Walk the monster turn through named phases"

### Task 3: HUD per stage and phase, docs

**Files:**
- Modify: `user_interface/hud/combat_status.gd`, `user_interface/hud/combat_status.tscn` (`_banner` typed `Label`), `CLAUDE.md` (Turns, Blocks), plan doc "Monsters and Combat Plan"
- Test: `tests/integration/turns/combat_status_test.gd`

**Interfaces:**
- Consumes: `block_state`, `BlockSequence.Stage`/keys (Task 1), `Phase` (Task 2)
- Produces: `static func banner_text(phase: TurnManager.Phase) -> String`: `HEROES` → `""` (banner hidden), `HERO_BLOCKS` → `"Heroes strike"`, `MONSTER_MOVES` → `"Monsters move"`, `MONSTER_BLOCKS` → `"Monsters strike"`
- `_on_block_state_changed`: `ROLLED` → title "X blocks Y", dice shown, not pressable; `CHOOSING` → as the old choice view (buttons for the picker, "Picking a die…" for others); `STRUCK`/cleared → nothing here. `_on_block_shown` keeps marking the chosen die and hiding after `dice_duration` (it also covers hidden blocks, whose stages peers may never see).

- [ ] **Step 1: Write the failing tests in `combat_status_test.gd`**: `banner_text` for all four phases; setting `block_state` to `ROLLED` shows the panel with every die disabled; `CHOOSING` for the local player enables them.
- [ ] **Step 2: Run; expect FAIL**
- [ ] **Step 3: Implement; update `CLAUDE.md` (phases, `BlockSequence`, `block_state`, requests waiting during any block) and the plan doc**
- [ ] **Step 4: Lint, script check, unit + integration tests pass; smoke run (`--quit-after 300`) shows no new errors**
- [ ] **Step 5: Commit** — "Show block stages and phase banners"; push and open the PR
