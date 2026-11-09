@tool
class_name TileDecorations
extends Resource

## Props a revealed tile is dressed with:
## - clutter: some from [member edge_props] along its closed sides (no connection), some from [member corner_props] in corners
##   between two closed sides, chosen from the tile's grid position
## - architecture: arches over openings (always where a corridor enters a room, sometimes between corridor tiles) and pillars on
##   every other grid corner of rooms; both are shared with neighbours, so the second of them to be revealed raises them
## Purely visual: every peer reveals the same tiles and picks alike, so nothing is synced. Props keep clear of the tile spots
## pieces stand on, lose their collision and are each a [Model], so they drop in with [member drop_animation]

const NODE_NAME: StringName = &"Decorations"
## The corners of a cell, as offsets from its grid position to the corner's index (see [method _add_pillars])
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

@export_group("Clutter")
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
@export_group("Architecture")
## Span openings where a corridor enters a room
@export var doorway_arches: PropSet
## Span some openings between two corridor tiles, by [member corridor_arch_chance]; ruins rather than whole arches look right there
@export var corridor_arches: PropSet
@export_range(0.0, 1.0) var corridor_arch_chance: float = 0.25
## Stand on every other grid corner of rooms
@export var room_pillars: PropSet
@export_group("Animation")
## Played on each prop as it drops in, one after another
@export var drop_animation: ModelAnimation = preload("uid://bf0msgn2okdfo")
## Seconds between two props dropping in
@export var drop_interval: float = 0.08

## Builds the props of [param tile], which must be in a [Level] and just revealed
func create(tile: Structure) -> Node3D:
	var decorations: Node3D = create_clutter(tile.profile.get_connections(0), tile.get_grid_position(), tile.level.grid_size)
	_add_arches(decorations, tile)
	_add_pillars(decorations, tile)
	return decorations

## Builds the clutter of a tile whose open sides are [param connections], as its model sees them (unrotated)
func create_clutter(connections: Array[Level.Direction], grid_position: Vector2i, tile_size: float) -> Node3D:
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
				_add_prop(decorations, edge_props, _on_floor((outward * edge_distance + along) * half_tile) * _random_turn(random), random)
		var corner_roll: float = random.randf()
		if not connections.has(direction) and not connections.has(next_direction) and corner_roll < corner_chance:
			var corner: Vector2 = outward + Vector2(Level.DIRECTION_VECTORS[next_direction])
			_add_prop(decorations, corner_props, _on_floor(corner * edge_distance * half_tile) * _random_turn(random), random)
	return decorations

## Hides the props of [param decorations] and drops them in one after another once [param after] (e.g. the tile's reveal) finished
func drop(decorations: Node3D, after: Tween = null) -> void:
	# A tween without steps is an error, and tiles may roll no props
	if not drop_animation or decorations.get_child_count() == 0: return
	for prop: Node in decorations.get_children(): (prop as Node3D).visible = false
	if after and after.is_running(): after.finished.connect(_drop_each.bind(decorations), CONNECT_ONE_SHOT)
	else: _drop_each(decorations)

## An arch over each opening to an already revealed neighbour: always between a room and a corridor, sometimes between two corridors
func _add_arches(decorations: Node3D, tile: Structure) -> void:
	var grid_position: Vector2i = tile.get_grid_position()
	for direction: Level.Direction in tile.get_connections():
		var neighbour_position: Vector2i = grid_position + Level.DIRECTION_VECTORS[direction]
		var neighbour: Structure = tile.level.get_placed_tile(neighbour_position)
		# The neighbour raises the arch once it is revealed
		if not neighbour or neighbour.shown_status != Structure.Status.REVEALED: continue
		var is_room: bool = tile.profile.room_type != null
		var arches: PropSet = doorway_arches if is_room != (neighbour.profile.room_type != null) else null
		# Seeded by the opening, so it does not matter which side raises the arch
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(grid_position) ^ hash(neighbour_position)
		if not arches and not is_room and random.randf() < corridor_arch_chance: arches = corridor_arches
		if not arches: continue
		var outward: Vector2 = Vector2(Level.DIRECTION_VECTORS[direction])
		# Arches are modelled spanning along x
		var across: Basis = Basis(Vector3.UP, PI * 0.5) if outward.x != 0.0 else Basis.IDENTITY
		_add_prop(decorations, arches, _to_model(tile, _on_floor(outward * tile.level.grid_size * 0.5), across), random)

## A pillar on each corner of a room tile with an even index on both axes, raised by the first revealed room tile around it
func _add_pillars(decorations: Node3D, tile: Structure) -> void:
	if not room_pillars or not tile.profile.room_type: return
	var grid_position: Vector2i = tile.get_grid_position()
	for corner: Vector2i in CORNERS:
		var corner_index: Vector2i = grid_position + corner
		if posmod(corner_index.x, 2) != 0 or posmod(corner_index.y, 2) != 0: continue
		if _has_revealed_room_tile_around(tile, corner_index): continue
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(corner_index) ^ hash(&"pillar")
		var spot: Vector2 = (Vector2(corner) - Vector2.ONE * 0.5) * tile.level.grid_size
		_add_prop(decorations, room_pillars, _to_model(tile, _on_floor(spot), _random_turn(random).basis), random)

## Whether a room tile other than [param tile] around the corner [param corner_index] was revealed before, and so raised its pillar
static func _has_revealed_room_tile_around(tile: Structure, corner_index: Vector2i) -> bool:
	for corner: Vector2i in CORNERS:
		var other_position: Vector2i = corner_index - corner
		if other_position == tile.get_grid_position(): continue
		var other: Structure = tile.level.get_placed_tile(other_position)
		if other and other.profile.room_type and other.shown_status == Structure.Status.REVEALED: return true
	return false

## A transform given in the level's axes, in the tile model's space (the tile is turned by its connections)
static func _to_model(tile: Structure, level_transform: Transform3D, level_basis: Basis = Basis.IDENTITY) -> Transform3D:
	var to_tile: Basis = tile.global_basis.inverse()
	return Transform3D(to_tile * level_basis * level_transform.basis, to_tile * level_transform.origin)

static func _on_floor(spot: Vector2) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(spot.x, 0.0, spot.y))

static func _random_turn(random: RandomNumberGenerator) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, random.randf() * TAU), Vector3.ZERO)

## Adds a prop picked from [param prop_set] at [param prop_transform], in the tile model's space
func _add_prop(decorations: Node3D, prop_set: PropSet, prop_transform: Transform3D, random: RandomNumberGenerator) -> void:
	var scene: PackedScene = prop_set.pick(random) if prop_set else null
	if not scene: return
	var mesh: Node3D = scene.instantiate()
	# Decorations never block clicks or movement
	for body: Node in mesh.find_children("*", "CollisionObject3D", true, false): body.free()
	mesh.scale = prop_set.prop_scale
	if prop_set.material_override:
		var meshes: Array[MeshInstance3D] = Model.gather_all_geometry_instances_on(mesh)
		if mesh is MeshInstance3D: meshes.append(mesh as MeshInstance3D)
		for mesh_instance: MeshInstance3D in meshes: mesh_instance.material_override = prop_set.material_override
	if prop_set.center_props:
		var footprint: Vector3 = _get_bounds(mesh).get_center() * prop_set.prop_scale
		mesh.position = -Vector3(footprint.x, 0.0, footprint.z)
	# A [Model] around the prop, so model animations play on it
	var prop: Model = Model.new()
	prop.name = mesh.name
	prop.transform = prop_transform
	prop.add_child(mesh)
	decorations.add_child(prop)

## The bounds of every mesh in [param node], in its own space; works outside the tree
static func _get_bounds(node: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var meshes: Array[MeshInstance3D] = Model.gather_all_geometry_instances_on(node)
	if node is MeshInstance3D: meshes.append(node as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if not mesh_instance.mesh: continue
		var mesh_bounds: AABB = _relative_transform(mesh_instance, node) * mesh_instance.mesh.get_aabb()
		bounds = mesh_bounds if bounds.size == Vector3.ZERO else bounds.merge(mesh_bounds)
	return bounds

static func _relative_transform(descendant: Node3D, ancestor: Node3D) -> Transform3D:
	var relative: Transform3D = Transform3D.IDENTITY
	var current: Node = descendant
	while current != ancestor and current is Node3D:
		relative = (current as Node3D).transform * relative
		current = current.get_parent()
	return relative

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
