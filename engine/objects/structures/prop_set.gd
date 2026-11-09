@tool
class_name PropSet
extends Resource

## A collection of props tiles are dressed with (see [TileDecorations]), like a [DungeonTileSet] for tiles: each scene with its weight

## {prop scene: [PackedScene] -> weight: [float]}
@export var props: Dictionary[PackedScene, float] = {}
## The asset packs are life-sized; tiles are miniatures
@export var prop_scale: float = 0.6

## @returns a prop picked by weight, or [code]null[/code] for an empty set
func pick(random: RandomNumberGenerator) -> PackedScene:
	if props.is_empty(): return null
	var scenes: Array[PackedScene] = props.keys()
	return scenes[random.rand_weighted(PackedFloat32Array(props.values()))]
