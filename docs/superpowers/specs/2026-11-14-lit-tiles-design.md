# Lit tiles widen sight — design

## Why

Wall torches, braziers and candles are decorations today: each peer picks them for itself when a tile is revealed, so the host's
rules never know where a flame stands. Fire should matter: a hero standing by a torch sees as if holding one, and lit places show
from afar, so fires draw the players onward.

## Goals

- **Standing in the light:** a hero on a tile lit by a torch or brazier, or on a tile opening onto it (a passage, both sides open),
  sees as if carrying a torch: the light's `LightSource` modifiers apply (+1 vision, +1 darkvision, as the held torch). A light counts
  once (`Character.get_light_sources()` already lists each `LightSource` once), so a torch-bearer by a brazier still gets +1.
- **Beacons:** a lit tile a hero can see along passages within 6 cells is revealed even beyond the hero's vision. A torch or brazier
  also reveals the tiles it lights (its tile and the tiles opening onto it); a candle only its own tile.
- **Candles** widen no one's vision; they only light their own tile from a distance.

## Non-goals

- Torch-lit arches and glowing crystals do not count (arches are decided by whichever neighbour is revealed first).
- No lighting or putting out wall lights.
- No change to how the character's own light looks near flames.

## Anti-goals

- Light never shows anything around corners: beacons reveal only what the hero's sight could reach along passages (the existing
  sight rule, `Level._update_player_vision`, with a 6-cell reach), never tiles off that path, even ones a torch lights.
- No peer may show a light the host's rules do not know about, or the reverse.

## Approaches

- **A — compute it from the tile:** a seeded roll from the tile's position and shape, asked by both the rules and the decorations.
  Cheap, no syncing, but tied to the roll staying the same.
- **B — the host decides and sends it (picked):** sturdier, and ready for lights that change later (lit, put out, carried off).

## Decided

- The host rolls each tile's light as it places the tile (seeded by the level's seed and the cell, like monsters), from the
  dungeon's wall lights: none, or one light kind. The tile keeps it as replicated spawn state, saved with the tile.
- Each light kind is data: its prop scene, the `LightSource` a hero standing in it gets (none for candles), and whether it lights
  the tiles opening onto its own (torches and braziers do, candles do not).
- The decorations show the light the tile holds instead of rolling their own; which closed side it stands on stays a visual choice.
- The host applies both rules wherever it updates a hero's sight (`Level.update_sight()`, turned tiles).

## Left to the builder

- Names and where the light kinds live (e.g. a resource per kind next to `dungeon_lights.tres`).
- How `get_vision()`/`get_dark_vision()` take a tile's light into account (e.g. the level hands a hero the lights around its cell).
- The beacon reach as a level setting (6 cells by default).
- Tests: model-free lit tiles in `tests/fixtures/`, covering standing in the light, beacons (including no reveal around a corner),
  candles, and the roll being the same for the same seed.
