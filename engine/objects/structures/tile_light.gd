@tool
@icon("uid://dcdlmxnu8p5h7")
class_name TileLight
extends Resource
## A kind of wall light a tile may hold (a torch, a brazier, candles): the host rolls one per tile as it places it (see
## [method Level.roll_light]) and sends it with the tile, the decorations show it on a closed side, and it lights the way:
## heroes standing in it see as if they carried [member light_source], and it shows from afar along passages

## What stands on the closed side, picked like any prop set
@export var props: PropSet:
	set(new_props):
		props = new_props
		changed.emit()
## What a hero standing in the light gets, as if carrying it (see [method Character.get_vision]); none for a weak light (candles)
@export var light_source: LightSource:
	set(new_light_source):
		light_source = new_light_source
		changed.emit()
## Whether it lights the tiles opening onto its own too, so they stand in it and show with it from afar; candles light only their own
@export var lights_neighbours: bool = true:
	set(new_lights_neighbours):
		lights_neighbours = new_lights_neighbours
		changed.emit()
