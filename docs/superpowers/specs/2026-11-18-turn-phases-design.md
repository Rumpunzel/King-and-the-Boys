# Turn Phases and Staged Blocks

## Intent

The turn manager runs the monster turn as three awaits inside one function (`_run_monster_phase`), and a block happens all at once: rolled, chosen, struck and applied in one frame, with a flat pause afterwards. Peers only know "heroes" or "monsters". Before the 3D rolling dice come, and before rerolls (as in Blood Bowl), the turn and the block need structure: named phases every peer knows, and a block that goes through stages, each with room to breathe, so dice, rerolls and later skills (Dodge, Guard) have a place to hook in.

## Goals

- `TurnManager.Phase` names every part of a turn: `HEROES`, `HERO_BLOCKS`, `MONSTER_MOVES`, `MONSTER_BLOCKS`. The host walks them in order; the phase is replicated as today, so the HUD shows which part runs.
- A block's whole life moves out of the turn manager into its own class, `BlockSequence` (`engine/turns/block_sequence.gd`): it rolls, asks for a choice, strikes, applies, and paces each stage. The turn manager awaits it.
- Every peer knows the block under way and its stage through one replicated state (replacing `block_choice`): stage, attacker, defender, dice, chosen face, pinned, and, while choosing, the choice id and picker.
- Stages: `ROLLED` (the dice show, before anything is decided), `CHOOSING` (only with more than one die and a player to ask), `STRUCK` (the chosen face counts, the attacker strikes, the outcome follows when the strike lands), then the block ends (state cleared).
- Each stage the heroes can see gets a pause before the next; hidden blocks run without pauses, as now.

## Non-goals

- Rerolls, 3D dice, new skills: later. The stages are where they will go (a reroll is a step between `ROLLED`/`CHOOSING` and `STRUCK`).
- Changing any block rule (dice count, faces, pushes, who leads).

## Anti-goals

- Gameplay logic in the HUD: `CombatStatus` only shows the replicated state and forwards the die pressed.
- Pauses for things nobody sees, or banners for phases that do nothing.
- A state machine framework for a fixed sequence of awaits.

## Constraints

- Host is the referee; the block state is replicated, the strike stays an RPC to synced peers (so its timing holds the falls until it lands).
- Typed GDScript, strict warnings; `@icon` on the new class (white, systems); its `.uid` committed. `turn_manager.gd` stays well under 1000 lines (it should shrink).
- Loading a save stops a phase and drops a block under way (`stop_monster_phase`, `_cancel_choice` today).

## Approaches

- **A. Phases and stages inside the turn manager.** Smallest change, but the turn manager (717 lines of 1000) would keep growing with every block feature.
- **B. Phases in the turn manager, the block's life in its own class.** Chosen: the block is where dice, rerolls and skills will grow; the turn manager keeps turns only.
- **C. A state machine (the project's `StateMachine` nodes).** Rejected: the phases are a fixed order of coroutines, not reactions to input; states would only wrap the same awaits.

## Design

- **Phases.** `_run_monster_phase` becomes a walk: `_end_heroes_turn()`, then `HERO_BLOCKS` (`_block_on_shared_tiles(HEROES)`), `MONSTER_MOVES` (the monster loop, moved into its own function), `MONSTER_BLOCKS`, then `HEROES` and the next turn. A phase with nothing to do (no shared tile; no monster in sight acting) is still set, but gets no pause. On entering a phase that does something the heroes can see, the host pauses briefly (`_PHASE_PAUSE`, my call ~0.6 s) so its banner reads before the action. `is_heroes_turn()` (phase == `HEROES`) replaces the checks against `MONSTERS`.
- **BlockSequence** (`RefCounted`, made by the turn manager per block, holding it and the level): `run() -> Block` is a coroutine returning the applied `Block`, or `null` if dropped (save loaded, a figure gone). It faces the attacker, rolls (`Block.roll`), publishes `ROLLED`, pauses (in sight), asks (`CHOOSING`, the existing wait-for-answer with timeout and player check), re-checks `pinned`, picks, publishes `STRUCK` and sends the strike (the turn manager's `show_block` RPC), applies, closes both undo stacks, pauses for the strike and the push hop (in sight), clears the state. Pauses use tweens on the turn manager (they go with the node). The turn manager keeps the RPCs and replicated properties, as only nodes have them.
- **Replicated block state.** `TurnManager.block_state: Dictionary` (replaces `block_choice`, keys `BLOCK_*` constants, `block_state_changed` signal); `request_block_choice(choice_id, value)` stays and answers only while the stage is `CHOOSING` with that id. The host refuses every request but the choice while any block is under way (today: only while choosing), so a block in the heroes' turn also holds the other players briefly; a pass pressed meanwhile is kept by the `PlayerController` and sent once the block ended.
- **HUD.** `CombatStatus` reads `block_state`: dice at `ROLLED` (shown, not pressable), buttons at `CHOOSING` for the picker, the chosen die marked at `STRUCK`; a banner per phase ("Heroes strike", "Monsters move", "Monsters strike"). `block_shown` stays as the strike's moment on each peer, and the HUD still marks the chosen die from it: a hidden block runs all its stages in one frame, so peers may never see `STRUCK` in `block_state`.
- **Tests.** Existing block, formation, monster-turn and combat-status tests move to the new names (`Phase.MONSTERS` → not `HEROES`, `block_choice` → `block_state`); new ones check the phase order, that a block passes its stages in order, and the pauses only in sight.

## Left to the builder

- Exact pause lengths (tunable constants).
- Which helpers (`_ask`, `_get_choosing_player`, `_is_still_on`) move with the block into `BlockSequence`; who blocks whom (`_block_on_shared_tiles`, the monster loop) is turn logic and stays in the turn manager.
