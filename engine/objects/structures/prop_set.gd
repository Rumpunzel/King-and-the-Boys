@tool
class_name PropSet
extends Resource

## A collection of props tiles are dressed with (see [TileDecorations]), like a [DungeonTileSet] for tiles: each scene with its weight

## {prop scene: [PackedScene] -> weight: [float]}
@export var props: Dictionary[PackedScene, float] = {}
## The asset packs are life-sized; tiles are miniatures. Per axis, so architecture can be fitted to a tile (e.g. a narrower arch
## that stays tall enough to walk through)
@export var prop_scale: Vector3 = Vector3.ONE * 0.6
## Centres each prop's footprint on its spot, for pieces pivoted at one end (e.g. Synty walls and arches)
@export var center_props: bool = false
## Given to every mesh of the props, e.g. a pack's texture atlas for FBX imports that carry no texture of their own
@export var material_override: Material

## @returns a prop picked by weight, or [code]null[/code] for an empty set
func pick(random: RandomNumberGenerator) -> PackedScene:
	if props.is_empty(): return null
	var scenes: Array[PackedScene] = props.keys()
	return scenes[random.rand_weighted(PackedFloat32Array(props.values()))]
