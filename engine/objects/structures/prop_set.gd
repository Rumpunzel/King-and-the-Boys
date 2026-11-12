@tool
@icon("uid://dsi6g62c3spch")
class_name PropSet
extends Resource

## A collection of props tiles are dressed with (see [TileDecorations]), like a [DungeonTileSet] for tiles: each scene with its weight.
## A prop may be put together from several pieces (see [member arrangement]), e.g. a cluster of crystals or planks into a bridge.

## Stored by number in prop set files: only append
enum Arrangement {
	## One piece
	SINGLE,
	## Pieces strewn around the spot, each turned its own way; along an edge, they spread along it
	SCATTER,
	## Pieces side by side across their long side, e.g. planks into a bridge
	ROW,
}

## {prop scene: [PackedScene] -> weight: [float]}
@export var props: Dictionary[PackedScene, float] = {}
## Picked like props, by weight, e.g. another pack's props, which need their own scale or material
@export var collections: Dictionary[PropSet, float] = {}
## The asset packs are life-sized; tiles are miniatures. Per axis, so architecture can be fitted to a tile (e.g. a narrower arch
## that stays tall enough to walk through)
@export var prop_scale: Vector3 = Vector3.ONE * 0.6
## Centres each prop's footprint on its spot, for pieces pivoted at one end (e.g. Synty walls and arches)
@export var center_props: bool = false
## Given to every mesh of the props, e.g. a pack's texture atlas for FBX imports that carry no texture of their own
@export var material_override: Material
## Played on its props as they drop in, instead of the decorations' own (see [member TileDecorations.drop_animation]), e.g. a heavy
## fall from above for architecture
@export var drop_animation: ModelAnimation
@export_group("Arrangement")
## How a prop is put together from this collection's pieces
@export var arrangement: Arrangement = Arrangement.SINGLE
## How many pieces a prop has, at least and at most (not for [constant Arrangement.SINGLE])
@export var piece_count: Vector2i = Vector2i(1, 1)
## Pieces vary in size by up to this share, both ways
@export_range(0.0, 1.0) var size_jitter: float = 0.0
## [constant Arrangement.SCATTER]: how far pieces stray from their place, in metres
@export_range(0.0, 2.0) var scatter_radius: float = 0.3
## [constant Arrangement.SCATTER]: how far pieces spread to either side along the edge they stand by, evenly, in metres
@export_range(0.0, 2.0) var scatter_length: float = 0.0
## [constant Arrangement.ROW]: the space between two pieces, in metres
@export_range(0.0, 1.0) var row_gap: float = 0.02
## [constant Arrangement.ROW]: each piece turns by up to this many degrees, so the row looks laid by hand
@export_range(0.0, 45.0) var row_turn_degrees: float = 4.0
## [constant Arrangement.ROW]: each piece shifts lengthwise by up to this many metres
@export_range(0.0, 1.0) var row_shift: float = 0.05

## @returns the collection the next prop comes from: this one, or by weight one of [member collections] (and so on)
func pick_collection(random: RandomNumberGenerator) -> PropSet:
	if collections.is_empty(): return self
	var own_weight: float = 0.0
	for weight: float in props.values(): own_weight += weight
	var weights: PackedFloat32Array = [own_weight]
	weights.append_array(PackedFloat32Array(collections.values()))
	var picked: int = random.rand_weighted(weights)
	if picked == 0: return self
	var collection: PropSet = collections.keys()[picked - 1]
	return collection.pick_collection(random)

## @returns a prop of this collection's own [member props] picked by weight, or [code]null[/code] if it has none
func pick(random: RandomNumberGenerator) -> PackedScene:
	if props.is_empty(): return null
	var scenes: Array[PackedScene] = props.keys()
	return scenes[random.rand_weighted(PackedFloat32Array(props.values()))]
