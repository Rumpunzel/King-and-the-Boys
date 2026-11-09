@tool
class_name TileDecorations
extends Resource

## Props a revealed tile is dressed with: some from [member edge_props] along its closed sides (no connection), some from
## [member corner_props] in corners between two closed sides. Purely visual: chosen from the tile's grid position, so every peer
## dresses a tile alike without syncing; props keep clear of the tile spots pieces stand on and lose their collision.
## Each prop is a [Model], so it drops in with [member drop_animation] once the tile is revealed

const NODE_NAME: StringName = &"Decorations"

## Small props, e.g. rubble, bones, candles
@export var edge_props: PropSet
## Larger props, e.g. barrels, crates
@export var corner_props: PropSet
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
@export_group("Animation")
## Played on each prop as it drops in, one after another
@export var drop_animation: ModelAnimation = preload("uid://bf0msgn2okdfo")
## Seconds between two props dropping in
@export var drop_interval: float = 0.08

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
			if not connections.has(direction) and random.randf() < edge_chance:
				_place(decorations, edge_props, (outward * edge_distance + along) * half_tile, random)
		var corner_roll: float = random.randf()
		if not connections.has(direction) and not connections.has(next_direction) and corner_roll < corner_chance:
			var corner: Vector2 = outward + Vector2(Level.DIRECTION_VECTORS[next_direction])
			_place(decorations, corner_props, corner * edge_distance * half_tile, random)
	return decorations

## Hides the props of [param decorations] and drops them in one after another once [param after] (e.g. the tile's reveal) finished
func drop(decorations: Node3D, after: Tween = null) -> void:
	if not drop_animation: return
	for prop: Node in decorations.get_children(): (prop as Node3D).visible = false
	if after and after.is_running(): after.finished.connect(_drop_each.bind(decorations), CONNECT_ONE_SHOT)
	else: _drop_each(decorations)

func _drop_each(decorations: Node3D) -> void:
	# The tile may have been rebuilt while its reveal played
	if not is_instance_valid(decorations) or not decorations.is_inside_tree(): return
	var tween: Tween = decorations.create_tween()
	for prop: Node in decorations.get_children():
		tween.tween_callback(_drop_one.bind(prop))
		tween.tween_interval(drop_interval)

func _drop_one(prop: Model) -> void:
	prop.visible = true
	prop.play_model_animation(drop_animation)

func _place(decorations: Node3D, prop_set: PropSet, spot: Vector2, random: RandomNumberGenerator) -> void:
	var rotation: float = random.randf() * TAU
	var scene: PackedScene = prop_set.pick(random) if prop_set else null
	if not scene: return
	var mesh: Node3D = scene.instantiate()
	# Decorations never block clicks or movement
	for body: Node in mesh.find_children("*", "CollisionObject3D", true, false): body.free()
	mesh.rotation.y = rotation
	mesh.scale = Vector3.ONE * prop_set.prop_scale
	# A [Model] around the prop, so model animations play on it
	var prop: Model = Model.new()
	prop.name = mesh.name
	prop.position = Vector3(spot.x, 0.0, spot.y)
	prop.add_child(mesh)
	decorations.add_child(prop)
