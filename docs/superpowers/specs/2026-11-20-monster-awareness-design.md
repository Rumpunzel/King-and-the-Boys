# Monster Awareness: Noticing by Light and Facing

## Intent

Monster attacks feel random: today every monster notices any hero within its `perception` (3 cells along passages), whatever the light, whatever way it faces, so a skeleton walks out of the dark at a hero who never saw it coming. Attacks should follow from what the players did. Noticing becomes an interplay of light and vision: a lit hero is seen by what they see, an unlit one only by a monster looking at them. Players see each notice happen the moment they cause it, and the rogue's lantern becomes a real stealth tool. Roaming monsters slow down, so the dungeon feels patrolled rather than swarming.

## Goals

- **A monster notices a hero only from the hero's own sight**: the cells the hero sees by `get_vision()` (`Level.get_cells_in_sight(hero_cell, hero.get_vision())`). If you can see it, it can see you; a monster the hero can not see never notices them. Dark vision does not count (the dwarf's 16 cells of darkvision do not give him away).
- **Lit heroes are noticed by every monster inside their sight.** A hero is lit while carrying a light (`Character.get_light_sources()`: the elf's torch, the rogue's lit lantern), standing in a wall light's glow (`Structure.get_light_sources()` of the tiles they stand in the light of, as `Character._get_sight_lights()` uses), or standing on the tile of a companion who carries a light. A companion's light on the tile counts like a wall light for the hero's sight too (my call): a hero beside the torch carrier sees, and is seen, as far as the torch reaches.
- **Unlit heroes are noticed only by a monster inside their sight that also looks at them**: the hero stands on the monster's tile, or straight ahead of it (the cells in the direction it faces, in its row or column, that are in sight by the sight rule, along open passages and across rooms, within its `perception`). In the dark that is close: an unlit hero sees about 1.5 cells.
- **Awareness per monster**, replicated: `ROAMING` (noticed no one), `HUNTING` (notices a hero now; target cell = that hero's cell) or `INVESTIGATING` (lost the hero it hunted; target cell = where it last noticed them). A hunting monster that no longer notices any hero turns investigating; an investigating one that reaches its target cell and notices no one turns roaming; any monster that notices a hero hunts (the nearest noticed one, by steps along passages; among heroes as near, the one with the lower `block_priority`).
- **Noticing is checked after every change that could change it**, on the host: every step (a hero's, a monster's, an undo), a turned tile, a light lit or put out, a block's push. Also during the heroes' turn, so a "!" pops the moment a hero steps into a monster's notice.
- **Nothing that gets someone noticed can be taken back**: a new notice closes the noticed hero's undo stack (`TurnManager.close_undo`), as stepping onto an enemy's tile does, and the undo of the hero whose action caused it (a torch carrier stepping onto the knight's tile, the mystic's turned tile bringing a hero into view). So an undo never has to take a notice back. A held ability is checked when it is used, not while it is previewed (`request_ability_adjust`).
- **Noticed heroes are on alert** (`Character.alerted`, with the existing alert animations) from the moment they are noticed, and stay so while any monster notices them (as built: noticed, not only hunted, so a hero a monster sees but does not go for still reacts); it clears when none does (today it is set only in the monster phase and cleared as the next turn starts). A passed hero still shows the pass pose over the alert (my call: the pass must read, and the monster's "!" carries the danger; `Character._get_rest()` changes order).
- **Monsters face what decides their notice**: a monster's figure no longer turns to look at a chest or centrepiece on its tile (`Character._look_at_thing_on_tile()` skips monsters), so the facing players see is the `facing` noticing reads.
- **Roaming speed**: `CharacterProfile.roam_speed: int = 1`, a monster's moves per turn while roaming; hunting and investigating monsters move their full `speed`. A roaming monster that notices someone mid-turn may use the rest of its `speed` (my call: noticing is what lets it hurry).
- **A step strategy per monster**: `MonsterStrategy` (a `Resource` on `CharacterProfile`, `strategy`), asked by `AgentStateDefault.choose_step()` for each step given the monster and its awareness. The default, `InvestigateStrategy`, hunts and investigates towards the target cell (`Level.get_step_towards_in_sight`-style pathing along passages; stopping on a hero's tile as now) and roams as `_wander` does now (a random passage, not straight back). New strategies, later coordination between monsters included, are new resources reading the same awareness.
- **Players see awareness**: a "!" pops over a monster that starts hunting and stays while it hunts, a "?" while it investigates, with a faint mark on the floor of the cell it investigates; nothing while roaming. Shown on every peer, only for monsters this peer shows (`Character.shown`).
- Awareness is saved with the monster (as built: through the agent's `AgentSynchronizer` and its `SynchronizerSerializer`, like the agent's state, not its agent data), so older saves load roaming.

## Non-goals

- Other strategies (ambushers, guards, cowards), monsters coordinating, alerting each other, hearing noise or fights: later, on top of the strategy and awareness.
- Changes to blocks, the phases or how heroes see.
- The rogue's lantern stays as it is: under the general rule it is simply the only light a hero can put out.

## Anti-goals

- Hidden rules: whatever notices a hero must be readable from the board (the hero's light and sight, a monster's facing). No notice by dice.
- Gameplay in the UI: the marks only show the replicated awareness.
- A noticing rule spread over several places: one class answers "does this monster notice this hero".

## Constraints

- Host is the referee: noticing and awareness are decided on the host and replicated; peers only show them.
- Typed GDScript, strict warnings; `@icon` on each new class (white for systems: senses, strategies are data-ish, yellow); `.uid` files committed; `turn_manager.gd` stays well under 1000 lines (noticing lives outside it).
- Monsters off (`Level.monsters_enabled`) notice nothing. A monster in a hero's sight stands on a tile that hero revealed, so every notice is of a monster the players can see.
- Tests run on the model-free fixtures (`tests/fixtures/monster.tres`, its profile gets `roam_speed` and the default strategy).

## Approaches

- **A. Everything inside `AgentStateDefault`.** Smallest, but the one state becomes the place every later monster idea goes, and strategies would mean taking it apart again.
- **B. Awareness as states of the agent's state machine** (`Roaming`, `Hunting`, `Investigating`). Fits the `StateMachine` pattern, but that machine means "who controls this figure" (itself or a player); taking control would have to keep and restore awareness, and a strategy would be spread over three states.
- **C. One noticing rule, replicated awareness, a step strategy.** Chosen: the strategy seam exists from the start, the fairness rule lives in one testable place, the marks are pure display, and coordination later only needs a strategy reading the other monsters' awareness.

## Design

- **`MonsterSenses`** (host only, a `RefCounted` the turn manager holds with the level, `engine/agents/monster_senses.gd`): `is_lit(hero) -> bool`, `notices(monster, hero) -> bool` (the two rules above) and `update()`: for every visible monster, which visible heroes it notices; sets each monster's awareness (`HUNTING` the nearest noticed hero, else `INVESTIGATING` towards the last cell it noticed its target on if it was hunting, else unchanged), closes the undo of each hero newly noticed by any monster and of the hero whose action it follows (`update(actor)`, `null` for monster steps), and sets `alerted` on every hero some monster hunts (clearing it on the others). As built after play: "newly noticed" is per monster and hero, so a hero one monster hunts already who steps into a second one's notice loses the undo too; each hero's sight is worked out once per `update()`. The turn manager calls `update()` after each step in `try_step`, after undo, after a held ability's use (turned tiles), after each block, and when a hero's lights change (the level's light hook, `Level.follow_sight_of`). As built: `is_lit` is `Character.is_lit()`; light changes outside the turn manager's requests (equipping a torch) are noticed at the next step or ability, as lights change only through abilities in play; the monsters' moves also start with an `update()`.
- **Awareness on the monster**: `Agent.awareness` (enum `ROAMING`, `HUNTING`, `INVESTIGATING`) and `Agent.awareness_target: Vector2i`, replicated (a synchronizer on the agent, host authority), emitting `awareness_changed`. In `to_agent_data()` and back on load.
- **Moves**: `TurnManager._move_monsters` lets a monster step while it has movement points and, while roaming, has taken fewer than `roam_speed` steps this turn. Monsters keep facing the way they last stepped, so facing is set by their movement. As built after play: a monster also turns to face the hero it hunts as that hero catches its eye (its first step towards them along passages).
- **Strategy**: `MonsterStrategy.choose_step(agent: Agent) -> int` (as built: the agent holds its character and level) (`-1` to stop), `engine/agents/strategies/`; `InvestigateStrategy` the default, its file in `data/characters/monsters/strategies/`. On reaching an investigated cell it stops; the next `update()` makes it roam. As built: no strategy file; a profile without `strategy` uses a shared `InvestigateStrategy`.
- **Marks**: a HUD element per shown monster in the game scene's `UserInterface` (a `HeadsUpDisplay`, anchored at `BoardObject.get_heads_up_anchor()`, as `InputPrompt` is): "!" with a short pop on entering `HUNTING`, "?" while `INVESTIGATING`; the floor mark on the target cell a local visual each peer places from `awareness_target` (like `tile_highlight.gdshader`'s brackets, in another colour).
- **Today's alerts**: `_alert_heroes_seen_by` and `_clear_alerts` go; `MonsterSenses` owns `alerted`.

## Tests

- Senses (integration, generated level): a lit hero (torch) in sight of a monster facing away is noticed; an unlit one there is not, unless straight ahead within perception or on its tile; a hero in a wall light's glow is lit; the hero beside a torch carrier on one tile is lit; dark vision does not make a hero noticeable; a lantern put out stops a notice from behind.
- Awareness: hunting → investigating as the hero slips out of notice, with the last-noticed cell; investigating → roaming on reaching it with no one noticed; noticing a second hero hunts the nearest.
- A step that gets a hero noticed closes their undo; an unnoticed step stays undoable; a torch carrier stepping onto an unlit hero's tile and getting them noticed closes both undos.
- An unlit hero is not noticed by a monster facing them from beyond their own sight.
- A monster arriving on a centrepiece's tile keeps facing the way it stepped.
- Roaming monsters take `roam_speed` steps; hunting ones `speed`; one noticing mid-turn uses the rest.
- Awareness survives save and load; alerts follow being hunted.

## Left to the builder

- How `MonsterSenses` is wired to light changes and turned tiles (one `update()` hook, or the turn manager after each request).
- The marks' look (font, colours, pop), and the floor mark's.
- Whether `MonsterSenses` caches sight per turn: correctness first, the dungeon has tens of monsters at most.
