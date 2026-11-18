# Lobby: Hero Picking and Ready

First step of a wider UI overhaul.

## Intent

Players cannot choose their hero in the lobby: each gets a random one on joining and R rolls another. There is no real ready: every panel shows a Ready button that is always pressed and does nothing, and the host may start at any time.

Picking a hero should be a small show moment, not a chore: a player looks over the heroes quickly, sees the one they pick pose on stage, and sees what it is good at. Friends in one lobby take different heroes, which makes the pick part of forming the party. Ready lets guests say they are done, so the host starts only once everyone is.

## Goals

- A player picks a hero with one button per hero.
- Each hero can be taken by one player only. Taken heroes show as taken, with who took them.
- Clicking one's own hero again rerolls its look (body, hair, skin), as picking does today.
- The picked hero's strength, intelligence, agility and movement (`CharacterProfile.speed`) are always shown; abilities show briefly, with details in tooltips.
- In a multiplayer game guests have a Ready toggle. Ready locks their hero. The host's Start works only once every guest is ready.
- The host decides every pick and every ready; clients only ask.

## Non-goals

- Other parts of the UI overhaul (later steps).
- Auto-start once everyone is ready.
- Choosing equipment or body parts by hand in the lobby.
- More players than heroes: `Multiplayer.MAX_CONNECTIONS` is 4 (5 players), there are 6 heroes.

## Anti-goals

- Gameplay rules in UI scripts (project convention): the UI shows state and forwards intent.
- Two players briefly holding the same hero, or a pick flickering back.
- A guest changing hero after pressing Ready.

## Constraints

- Host is the referee (`CLAUDE.md`): requests are RPCs to `Multiplayer.HOST_ID`; the host checks them and changes replicated state.
- Typed GDScript with strict warnings; `@icon` on new `class_name`s (yellow for data); `uid://` references; new `.gd` files need their `.uid` committed.
- `Player` nodes are `MultiplayerSynchronizer`s owned by their own peer (`set_multiplayer_authority(player_id)`), replicating `player_name`, `_serialized_character` and `body`.
- Offline, `Player.is_local_player()` is true for every player and `Multiplayer.is_online()` is false.

## Approaches

- **A. Host-owned state on `Player` (picked).** `Player` gets a second synchronizer pinned to host authority (as `EquipmentSynchronizer` is inside a client-owned subtree) holding the hero and ready. Guests call `request_character()` / `request_ready()` on the host, which checks and sets. State lives where game start already reads it (`player.character`). Cost: two synchronizers on one node.
- **B. Roster on the `Lobby` autoload.** One host-owned map hero → player plus a ready set. The "one each" check sits in one place, but the hero is then kept in two places (Lobby and `Player`) that must agree.
- **C. Guests own, host corrects.** Keep today's ownership; the host sends corrections. Races and flicker; against the host-referee convention.

The user picked A.

## Design

### Hero roster (data)

The list of pickable heroes moves out of the UI (`CharacterSelection._available_characters` in `character_selection.tscn`) into a data resource, so the host can check picks against it: a small resource class (e.g. `HeroRoster`, `heroes: Array[CharacterProfile]`) saved as `data/characters/heroes.tres`, holding the six heroes in today's order. The order is the button order. Where the host and the UI get it from (a `GameConfig` field or a reference on `Lobby`) is the builder's call; it must not pull assets into scripts by `preload` (profiles hold model scenes), so it is set in a scene or loaded by UID at runtime.

### `Player` state

- `character` and a new `ready: bool` become host-owned. They replicate through a second `MultiplayerSynchronizer` child of `Player` whose authority is always `Multiplayer.HOST_ID`, while `player_name` and `body` stay on the player's own synchronizer.
- The character is synced by its `ResourceId` (replacing `_serialized_character`'s plain path); peers resolve it and accept only heroes in the roster.
- Clients ask with RPCs to the host:
  - `request_character(id)`: refused if the hero is not in the roster, is held by another player, or the asker is ready. Asking for one's own hero is accepted and counts as a reroll (see Body).
  - `request_ready(ready)`: only for guests in an online game.
- The host's own requests go through the same checks locally.
- **First pick:** when the host creates a player (joining or the host's own), it assigns a random free hero. R asks for a random free hero other than the current one.
- **Leaving:** a player's node goes away with them, so their hero is free again (in the lobby).
- **Picks are a lobby matter.** The game supports no fresh joins mid-game, only reconnecting to a game one was part of; a reconnecting player gets their own character back from their `PlayerController` (`PlayerControllerSpawner._on_player_created`). So the host assigns and checks heroes only while in the lobby; in the game scene it assigns no random hero and accepts no `request_character()`.
- When a request is refused, nothing changes; the UI needs no error beyond the unchanged state.

### Body

`body` stays owned by the player (rolled by their own peer with `CharacterProfile.roll_body()`), as today. The player's peer rolls a new body whenever the host confirms a hero for them, and whenever they click their own hero (a reroll needs no host state change: the click rolls locally; the host is not asked). The host already checks the body against the profile at game start (`create_character_data()`), so a body briefly rolled for the wrong hero is harmless.

### Ready and Start

- Ready exists only online, for guests. The host has no Ready; offline there is none.
- A ready guest's hero buttons are disabled until they unready.
- `LobbyHostMenu`'s Start is enabled only when every connected guest is ready (my call: "connected" means every peer in `multiplayer.get_peers()`, so a peer still exchanging player info, without a `Player` yet, holds Start back too), and shows the count ("Start (2 / 3 ready)" or similar). A guest joining resets nothing for others but is not ready, so Start waits again. Offline, Start is always enabled.
- The host rechecks on Start that every guest is ready (a click may race a guest unreadying).
- Ready is not carried into the game.

### Lobby UI

- The local player's panel replaces the random-only `CharacterSelection` with a row (or grid) of hero buttons, one per roster hero, showing portrait and name. Taken heroes are disabled and labelled with the holder's name; the own hero is highlighted. Clicking another free hero asks the host; clicking the own hero rerolls the look.
- Under the buttons: the current hero's name, Strength, Intelligence, Agility and Movement, and its abilities (icon or name) with `Ability.description` as tooltip.
- Below: the Ready toggle (guests online), replacing today's dummy `_ready_button` behaviour; other players' panels show their ready state read-only.
- The stage keeps working as now: a new hero rebuilds the preview and plays `selected_animation`; a new body redresses it (`LobbyMenu._update_preview`).
- Sketch:

```
 [Knight] [Mystic] [Elf] [Rogue] [Dwarf] [Bard (Anna)]
   KNIGHT
   STR 4  INT 2  AGI 3  MOV 3
   [Shield Wall] [Rally]        (hover: description)
                 [ Ready ]
```

### Tests

- Unit or integration tests (offline, two `Player`s by hand) for the host checks: a free hero is granted, a taken one refused, a ready player's change refused, own hero accepted, first pick and R give free heroes, a leaving player frees their hero, Start allowed only when all guests are ready.
- Manual multiplayer check with two instances (ENet): picks, greying, ready lock, Start gate, leaving.

## Left to the builder

- Names of the new class, RPCs and synchronizer node; where the roster is referenced from.
- Exact layout, styling and tooltip look of the hero buttons and stat block, within the existing lobby scenes.
- How stats are labelled (short or full names).
- Whether `CharacterSelection` / `CharacterPanel` are reshaped or replaced.
