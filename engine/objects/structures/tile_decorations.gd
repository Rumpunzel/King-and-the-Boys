@tool
class_name TileDecorations
extends Resource

## Props a revealed tile is dressed with: small ones along its closed sides (no connection), bigger ones in corners between two
## closed sides. Purely visual: chosen from the tile's grid position, so every peer dresses a tile alike without syncing; props
## keep clear of the tile spots pieces stand on and lose their collision

const NODE_NAME: StringName = &"Decorations"

## Small props, e.g. rubble, bones, candles
@export var edge_props: Array[PackedScene] = []
## Larger props, e.g. barrels, crates
@export var corner_props: Array[PackedScene] = []
## The asset packs are life-sized; tiles are miniatures
@export var prop_scale: float = 0.6
## How many props a closed side may get, each by [member edge_chance]
@export_range(0, 4) var props_per_edge: int = 2
## Chance of each prop of a closed side
@export_range(0.0, 1.0) var edge_chance: float = 0.5
## Chance of a prop per corner between two closed sides
@export_range(0.0, 1.0) var corner_chance: float = 0.5
## How far out props stand, as a fraction of half the tile; tile spots lie at 0.5
@export_range(0.0, 1.0) var edge_distance: float = 0.8
## How far props on a side may stray from its middle, as a fraction of half the tile
@export_range(0.0, 1.0) var edge_spread: float = 0.3

## Builds the props of a tile whose open sides are [param connections], as its model sees them (unrotated)
func create(connections: Array[Level.Direction], grid_position: Vector2i, tile_size: float) -> Node3D:
	var decorations: Node3D = Node3D.new()
	decorations.name = NODE_NAME
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(grid_position)
	var half_tile: float = tile_size * 0.5
	for direction: Level.Direction in Level.Direction.values():
		var outward: Vector2 = Vector2(Level.DIRECTION_VECTORS[direction])
		var next_direction: Level.Direction = ((direction + 1) % Level.DIRECTION_VECTORS.size()) as Level.Direction
		for edge_prop: int in props_per_edge:
			var along: Vector2 = Vector2(-outward.y, outward.x) * random.randf_range(-edge_spread, edge_spread)
			if not connections.has(direction) and random.randf() < edge_chance and not edge_props.is_empty():
				_place(decorations, edge_props, (outward * edge_distance + along) * half_tile, random)
		var corner_roll: float = random.randf()
		if not connections.has(direction) and not connections.has(next_direction) and corner_roll < corner_chance and not corner_props.is_empty():
			var corner: Vector2 = outward + Vector2(Level.DIRECTION_VECTORS[next_direction])
			_place(decorations, corner_props, corner * edge_distance * half_tile, random)
	return decorations

func _place(decorations: Node3D, scenes: Array[PackedScene], spot: Vector2, random: RandomNumberGenerator) -> void:
	var scene: PackedScene = scenes[random.randi() % scenes.size()]
	var rotation: float = random.randf() * TAU
	if not scene: return
	var prop: Node3D = scene.instantiate()
	# Decorations never block clicks or movement
	for body: Node in prop.find_children("*", "CollisionObject3D", true, false): body.free()
	prop.position = Vector3(spot.x, 0.0, spot.y)
	prop.rotation.y = rotation
	prop.scale = Vector3.ONE * prop_scale
	decorations.add_child(prop)
