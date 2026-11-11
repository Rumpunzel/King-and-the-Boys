# game-icons.net

The full icon set of [game-icons.net](https://game-icons.net), one folder per artist, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/): using an icon means crediting its artist.

Scripts do not use these files directly. To give a script an icon, copy one into `tools/icons/<colour>/` (32 px, its fill set to the colour of that folder: red `#fc7f7f`, white `#e0e0e0`, green `#8eef97`, yellow `#ffdd65`, purple `#8045ff`), import it, point `@icon` at its `uid://`, and add it to `tools/icons/CREDITS.md`.

CI leaves this folder out of its import (`.github/actions/godot`).
