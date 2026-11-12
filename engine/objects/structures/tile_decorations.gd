@tool
@icon("uid://b7lkf7v36ct57")
class_name TileDecorations
extends Resource

## Props a revealed tile is dressed with:
## - clutter: some from [member edge_props] along its closed sides (no connection), some from [member corner_props] in corners
##   between two closed sides, chosen from the tile's grid position
## - architecture: arches over openings (whole ones where a corridor enters a room, facing it, ruins between corridor tiles), raised by the first
##   of the two tiles to be revealed once the other one exists, and pillars on every other grid corner inside rooms, raised by the last of its four
##   room tiles to be revealed
## - lights: now and then a torch, brazier or candles in the middle of a closed side, which then gets no other clutter
## - rooms: rugs under the middle of some room tiles (flat, so pieces stand on them), ambience such as sun beams, and dust over every
##   tile of some rooms (rolled per room, see [method Level.get_room_cells])
## - walls: mostly crumbling, along some closed sides; an edge is shared too, so the first of its tiles to be revealed decides it
## Purely visual: every peer reveals the same tiles and picks alike, so nothing is synced. Props keep clear of the tile spots
## pieces stand on, lose their collision and are each a [Model], so they drop in with [member drop_animation]

const NODE_NAME: StringName = &"Decorations"
## Name of the node holding a tile's paths, see [method create_paths]
const PATHS_NODE_NAME: StringName = &"Paths"
## How many frames dust waits for the rest of a room arriving tile by tile, see [method _add_room_dust]
const ROOM_WAIT_FRAMES: int = 120
## Meta of a tile's decorations: the grid positions of the neighbours whose shared edge (an opening or a wall) it decided
const DECIDED_EDGES: StringName = &"decided_edges"
## Meta of an arch or wall: the grid position of the neighbour across the edge it stands on, see [method redecide_edges]
const EDGE: StringName = &"edge"
## Meta of an arch: whether it was raised as a doorway (between a room and a corridor)
const DOORWAY: StringName = &"doorway"
## Meta of a prop: the [ModelAnimation] its prop set plays as it drops in, if not [member drop_animation]
const DROP_ANIMATION: StringName = &"drop_animation"
## The corners of a cell, as offsets from its grid position to the corner's index (see [method _add_pillars])
const CORNERS: Array[Vector2i] = Level.CELL_CORNERS

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
@export_group("Lights")
## Light sources: torches, braziers, candles; at most one per tile, in the middle of a closed side
@export var lights: PropSet
@export_range(0.0, 1.0) var light_chance: float = 0.2
@export_group("Rooms")
## Lie under the middle of room tiles, e.g. rugs; turned in quarter turns to the grid
@export var room_floors: PropSet
@export_range(0.0, 1.0) var room_floor_chance: float = 0.3
## Over the middle of some room tiles, e.g. sun beams
@export var room_ambience: PropSet
@export_range(0.0, 1.0) var room_ambience_chance: float = 0.2
## Over the middle of every tile of a dusty room, so the room reads as one
@export var room_dust: PropSet
## Chance of a room being dusty
@export_range(0.0, 1.0) var dusty_room_chance: float = 0.4
@export_group("Architecture")
## Span openings where a corridor enters a room, by [member doorway_arch_chance]
@export var doorway_arches: PropSet
@export_range(0.0, 1.0) var doorway_arch_chance: float = 0.6
## Span some openings between two corridor tiles, by [member corridor_arch_chance]; ruins rather than whole arches look right there
@export var corridor_arches: PropSet
@export_range(0.0, 1.0) var corridor_arch_chance: float = 0.15
## Stand on every other grid corner inside rooms, where no arch can stand (arches need a corridor on one side)
@export var room_pillars: PropSet
@export_group("Walls")
## Stand on some sides without a connection, by [member wall_chance]; modelled spanning along x
@export var walls: PropSet
@export_range(0.0, 1.0) var wall_chance: float = 0.5
@export_group("Connections")
## A worn path on the floor from the tile's middle to each of its openings, as a decal; its alpha gives the path its shape
@export var path_texture: Texture2D
## Tints [member path_texture]
@export var path_color: Color = Color(0.3, 0.22, 0.14, 0.6)
## Width of a path, in metres
@export_range(0.1, 2.0) var path_width: float = 0.7
## A plank or slab over the gap where two tiles open to each other; laid with its long side across the gap
@export var bridges: PropSet
@export_group("Animation")
## Played on each prop as it drops in, one after another, unless its prop set has its own [member PropSet.drop_animation]
@export var drop_animation: ModelAnimation = preload("uid://bf0msgn2okdfo")
## Seconds between two props dropping in
@export var drop_interval: float = 0.08

## Builds the props of [param tile], which must be in a [Level] and just revealed
func create(tile: Structure) -> Node3D:
	var decorations: Node3D = create_clutter(tile.profile.get_connections(0), tile.get_grid_position(), tile.level.grid_size)
	var clutter_count: int = decorations.get_child_count()
	var decided: Array[Vector2i] = []
	decorations.set_meta(DECIDED_EDGES, decided)
	_add_arches(decorations, tile, decided)
	_add_walls(decorations, tile, decided)
	_add_pillars(decorations, tile)
	# Architecture drops in first, so it does not land on the clutter
	for index: int in range(clutter_count, decorations.get_child_count()): decorations.move_child(decorations.get_child(index), index - clutter_count)
	_add_room_props(decorations, tile)
	return decorations

## Builds the clutter of a tile whose open sides are [param connections], as its model sees them (unrotated)
func create_clutter(connections: Array[Level.Direction], grid_position: Vector2i, tile_size: float) -> Node3D:
	var decorations: Node3D = Node3D.new()
	decorations.name = NODE_NAME
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(grid_position)
	var half_tile: float = tile_size * 0.5
	var lit_side: int = _add_light(decorations, connections, half_tile, random)
	for direction: Level.Direction in Level.Direction.values():
		var outward: Vector2 = Vector2(Level.DIRECTION_VECTORS[direction])
		var next_direction: Level.Direction = ((direction + 1) % Level.DIRECTION_VECTORS.size()) as Level.Direction
		for edge_prop: int in props_per_edge:
			var along: Vector2 = Vector2(-outward.y, outward.x) * random.randf_range(-edge_spread, edge_spread)
			if not connections.has(direction) and direction != lit_side and random.randf() < edge_chance:
				_add_prop(decorations, edge_props, _on_floor((outward * edge_distance + along) * half_tile) * _random_turn(random), random)
		var corner_roll: float = random.randf()
		if not connections.has(direction) and not connections.has(next_direction) and corner_roll < corner_chance:
			var corner: Vector2 = outward + Vector2(Level.DIRECTION_VECTORS[next_direction])
			_add_prop(decorations, corner_props, _on_floor(corner * edge_distance * half_tile) * _random_turn(random), random)
	return decorations

## Now and then a light source in the middle of a closed side
## @returns the side it stands on, or [code]-1[/code]
func _add_light(decorations: Node3D, connections: Array[Level.Direction], half_tile: float, random: RandomNumberGenerator) -> int:
	var closed: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values():
		if not connections.has(direction): closed.append(direction)
	var roll: float = random.randf()
	if not lights or closed.is_empty() or roll >= light_chance: return -1
	var side: Level.Direction = closed[random.randi() % closed.size()]
	_add_prop(decorations, lights, _on_floor(Vector2(Level.DIRECTION_VECTORS[side]) * edge_distance * half_tile) * _random_turn(random), random)
	return side

## A rug under the middle of some room tiles, and some ambience above it
func _add_room_props(decorations: Node3D, tile: Structure) -> void:
	if not tile.profile.room_type: return
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(tile.get_grid_position()) ^ hash(&"room")
	var quarter_turn: Basis = Basis(Vector3.UP, PI * 0.5 * (random.randi() % 4))
	if room_floors and random.randf() < room_floor_chance:
		_add_prop(decorations, room_floors, _to_model(tile, _on_floor(Vector2.ZERO), quarter_turn), random)
	if room_ambience and random.randf() < room_ambience_chance:
		_add_prop(decorations, room_ambience, _to_model(tile, _on_floor(Vector2.ZERO)), random)
	_add_room_dust(decorations, tile)

## Dust over [param tile] if its room is dusty. The room is rolled by its first cell, so it needs all its tiles: rooms are built whole,
## but loaded and joining peers get their tiles one by one, possibly over several frames, so the dust waits until the room is
## complete (at most [constant ROOM_WAIT_FRAMES] frames, then rolls with what is there)
func _add_room_dust(decorations: Node3D, tile: Structure, frames_left: int = ROOM_WAIT_FRAMES) -> void:
	if not room_dust or not is_instance_valid(decorations) or not is_instance_valid(tile) or not tile.level: return
	var cells: Array[Vector2i] = tile.level.get_room_cells(tile.get_grid_position())
	if frames_left > 0 and not tile.level.is_room_complete(cells) and tile.is_inside_tree():
		# A lambda per tile: one method bound twice counts as one connection
		tile.get_tree().process_frame.connect(func() -> void: _add_room_dust(decorations, tile, frames_left - 1), CONNECT_ONE_SHOT)
		return
	var room_random: RandomNumberGenerator = RandomNumberGenerator.new()
	room_random.seed = hash(cells.min()) ^ hash(&"dust")
	if room_random.randf() >= dusty_room_chance: return
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(tile.get_grid_position()) ^ hash(&"dust")
	_add_prop(decorations, room_dust, _to_model(tile, _on_floor(Vector2.ZERO)), random)
	# Late, the other props' drop is under way without it: it drops in on its own
	if frames_left < ROOM_WAIT_FRAMES and drop_animation: _drop_one(decorations.get_child(decorations.get_child_count() - 1) as Model)

## Hides the props of [param decorations] and drops them in one after another once [param after] (e.g. the tile's reveal) finished
func drop(decorations: Node3D, after: Tween = null) -> void:
	# A tween without steps is an error, and tiles may roll no props
	if not drop_animation or decorations.get_child_count() == 0: return
	for prop: Node in decorations.get_children(): (prop as Node3D).visible = false
	if after and after.is_running(): after.finished.connect(_drop_each.bind(decorations), CONNECT_ONE_SHOT)
	else: _drop_each(decorations)

## Every peer, after [param tile] turned by [param clockwise_turns]: the arches and walls it carries turned with its model and
## stay, now facing other neighbours, unless that edge holds a prop of the neighbour already or an arch no longer fits (a doorway
## arch between two corridors, or the other way round). Edges left open are decided again; neighbours keep their props.
## @returns the new props, hidden until [method drop_props]
func redecide_edges(tile: Structure, clockwise_turns: int) -> Array[Model]:
	var new_props: Array[Model] = []
	var decorations: Node3D = _get_decorations(tile)
	if not decorations: return new_props
	var grid_position: Vector2i = tile.get_grid_position()
	var decided_before: Array[Vector2i] = decorations.get_meta(DECIDED_EDGES, [] as Array[Vector2i])
	var decided: Array[Vector2i] = []
	for edge: Vector2i in decided_before: decided.append(_turn_edge(grid_position, edge, clockwise_turns))
	decorations.set_meta(DECIDED_EDGES, decided)
	for prop: Node in decorations.get_children():
		if not prop.has_meta(EDGE): continue
		var edge_before: Vector2i = prop.get_meta(EDGE)
		var edge: Vector2i = _turn_edge(grid_position, edge_before, clockwise_turns)
		prop.set_meta(EDGE, edge)
		if _still_fits(tile, prop, edge): continue
		decided.erase(edge)
		decorations.remove_child(prop)
		prop.queue_free()
	var first_new: int = decorations.get_child_count()
	_add_arches(decorations, tile, decided)
	_add_walls(decorations, tile, decided)
	for index: int in range(first_new, decorations.get_child_count()):
		var prop: Model = decorations.get_child(index)
		prop.visible = false
		new_props.append(prop)
	return new_props

## The neighbour position [param edge] of the tile on [param grid_position] faces after it turned by [param clockwise_turns]
static func _turn_edge(grid_position: Vector2i, edge: Vector2i, clockwise_turns: int) -> Vector2i:
	return grid_position + Vector2i(Level.turn_spot(Vector2(edge - grid_position), clockwise_turns).round())

## Whether the edge prop [param prop] of [param tile], turned to face [param edge], may stay there
static func _still_fits(tile: Structure, prop: Node, edge: Vector2i) -> bool:
	var neighbour: Structure = tile.level.get_placed_tile(edge)
	if not neighbour: return true
	var neighbour_decorations: Node3D = _get_decorations(neighbour)
	if neighbour_decorations:
		for neighbour_prop: Node in neighbour_decorations.get_children():
			if neighbour_prop.has_meta(EDGE) and neighbour_prop.get_meta(EDGE) == tile.get_grid_position(): return false
	if not prop.has_meta(DOORWAY): return true
	var is_doorway: bool = (tile.profile.room_type != null) != (neighbour.profile.room_type != null)
	return prop.get_meta(DOORWAY) == is_doorway

## A path decal from the middle of [param tile] to each opening of its shape, as its model sees it (unrotated); a child of
## the model, so it lifts and turns with the tile and shows its shape even while lifted
func create_paths(tile: Structure) -> Node3D:
	var paths: Node3D = Node3D.new()
	paths.name = PATHS_NODE_NAME
	if not path_texture: return paths
	var half_tile: float = tile.level.grid_size * 0.5
	for direction: Level.Direction in tile.profile.get_connections(0):
		var outward: Vector3 = Vector3(Level.DIRECTION_VECTORS[direction].x, 0.0, Level.DIRECTION_VECTORS[direction].y)
		var decal: Decal = Decal.new()
		decal.name = "Path %s" % Level.Direction.keys()[direction]
		decal.texture_albedo = path_texture
		decal.modulate = path_color
		# Thin, so it marks the floor and little of what stands on it
		decal.size = Vector3(path_width, 0.4, half_tile)
		decal.transform = Transform3D(Basis(Vector3.UP, atan2(outward.x, outward.z)), outward * half_tile * 0.5)
		paths.add_child(decal)
	return paths

## A bridge over the gap between the tile on [param grid_position] and its neighbour in [param direction], turned so its long
## side spans the gap; place it on the gap. Seeded by the two cells, so either side builds the same one on every peer.
## @returns [code]null[/code] without [member bridges]
func create_bridge(grid_position: Vector2i, direction: Level.Direction) -> Model:
	if not bridges: return null
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(grid_position) ^ hash(grid_position + Level.DIRECTION_VECTORS[direction]) ^ hash(&"bridge")
	var holder: Node3D = Node3D.new()
	var bridge: Model = _add_prop(holder, bridges, Transform3D.IDENTITY, random)
	if bridge: holder.remove_child(bridge)
	holder.free()
	if not bridge: return null
	var bounds: AABB = _get_bounds(bridge.get_child(0) as Node3D)
	var across_x: bool = Level.DIRECTION_VECTORS[direction].x != 0
	var long_x: bool = bounds.size.x >= bounds.size.z
	if across_x != long_x: bridge.basis = Basis(Vector3.UP, PI * 0.5)
	return bridge

## Drops in [param props] (e.g. from [method redecide_edges]) one after another
func drop_props(props: Array[Model]) -> void:
	var valid_props: Array[Model] = []
	for prop: Model in props:
		if is_instance_valid(prop): valid_props.append(prop)
	if valid_props.is_empty(): return
	var first_prop: Model = valid_props.front()
	if not first_prop.is_inside_tree(): return
	var tween: Tween = first_prop.create_tween()
	for prop: Model in valid_props:
		tween.tween_callback(_drop_one.bind(prop))
		tween.tween_interval(drop_interval)

static func _get_decorations(tile: Structure) -> Node3D:
	if not tile.model or not tile.model.has_node(NodePath(NODE_NAME)): return null
	return tile.model.get_node(NodePath(NODE_NAME)) as Node3D

## An arch over some openings: whole ones between a room and a corridor, ruins between two corridors. The first of the two tiles to
## be revealed decides, as soon as the other one exists (it need not be revealed); otherwise the other one decides once revealed
func _add_arches(decorations: Node3D, tile: Structure, decided: Array[Vector2i]) -> void:
	var grid_position: Vector2i = tile.get_grid_position()
	for direction: Level.Direction in tile.get_connections():
		var neighbour_position: Vector2i = grid_position + Level.DIRECTION_VECTORS[direction]
		var neighbour: Structure = tile.level.get_placed_tile(neighbour_position)
		# Whether it is a doorway depends on the neighbour, so it is decided once the neighbour exists
		if not neighbour or decided.has(neighbour_position) or _has_decided(neighbour, grid_position): continue
		decided.append(neighbour_position)
		var is_room: bool = tile.profile.room_type != null
		var is_doorway: bool = is_room != (neighbour.profile.room_type != null)
		if not is_doorway and is_room: continue
		# Seeded by the opening, so it does not matter which side raises the arch
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(grid_position) ^ hash(neighbour_position)
		if random.randf() >= (doorway_arch_chance if is_doorway else corridor_arch_chance): continue
		var arches: PropSet = doorway_arches if is_doorway else corridor_arches
		var arch: Model = _add_prop(decorations, arches, _on_edge(tile, direction, _facing_room(direction, is_room) if is_doorway else Basis.IDENTITY), random)
		if not arch: continue
		arch.set_meta(EDGE, neighbour_position)
		arch.set_meta(DOORWAY, is_doorway)

## A wall on some sides without a connection; a neighbour across, if any, may have decided the edge already
func _add_walls(decorations: Node3D, tile: Structure, decided: Array[Vector2i]) -> void:
	if not walls: return
	var grid_position: Vector2i = tile.get_grid_position()
	var connections: Array[Level.Direction] = tile.get_connections()
	for direction: Level.Direction in Level.Direction.values():
		if connections.has(direction): continue
		var neighbour_position: Vector2i = grid_position + Level.DIRECTION_VECTORS[direction]
		var neighbour: Structure = tile.level.get_placed_tile(neighbour_position)
		if decided.has(neighbour_position) or (neighbour and _has_decided(neighbour, grid_position)): continue
		decided.append(neighbour_position)
		# Seeded by the edge, so it does not matter which side decides
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(grid_position) ^ hash(neighbour_position) ^ hash(&"wall")
		if random.randf() >= wall_chance: continue
		# Either face may look into the tile, so crumbling ends vary
		var flip: Basis = Basis(Vector3.UP, PI) if random.randf() < 0.5 else Basis.IDENTITY
		var wall: Model = _add_prop(decorations, walls, _on_edge(tile, direction, flip), random)
		if wall: wall.set_meta(EDGE, neighbour_position)

## The middle of the tile's edge in [param direction] (in the level's axes), turned so a piece modelled along x spans the edge
static func _on_edge(tile: Structure, direction: Level.Direction, turn: Basis) -> Transform3D:
	var outward: Vector2 = Vector2(Level.DIRECTION_VECTORS[direction])
	var across: Basis = Basis(Vector3.UP, PI * 0.5) if outward.x != 0.0 else Basis.IDENTITY
	return _to_model(tile, _on_floor(outward * tile.level.grid_size * 0.5), across * turn)

## Turns a doorway arch so its front (+z, e.g. where torches hang) faces the room: the tile itself if [param is_room], else the neighbour
## in [param direction]
static func _facing_room(direction: Level.Direction, is_room: bool) -> Basis:
	var outward: Vector3 = Vector3(Level.DIRECTION_VECTORS[direction].x, 0.0, Level.DIRECTION_VECTORS[direction].y)
	# Before turning, [method _on_edge] lays the front along the edge's axis, pointing to the positive side
	var front: Vector3 = outward.abs()
	var towards_room: Vector3 = -outward if is_room else outward
	return Basis(Vector3.UP, PI) if front.dot(towards_room) < 0.0 else Basis.IDENTITY

## Whether [param tile] already decided its edge towards [param neighbour_position]
static func _has_decided(tile: Structure, neighbour_position: Vector2i) -> bool:
	if not tile.model or not tile.model.has_node(NodePath(NODE_NAME)): return false
	var decided: Array[Vector2i] = tile.model.get_node(NodePath(NODE_NAME)).get_meta(DECIDED_EDGES, [] as Array[Vector2i])
	return decided.has(neighbour_position)

## A pillar on each corner with an even index on both axes whose four cells are all room tiles, raised once the last of them is
## revealed; corners on a room's border are left to the doorway arches
func _add_pillars(decorations: Node3D, tile: Structure) -> void:
	if not room_pillars or not tile.profile.room_type: return
	var grid_position: Vector2i = tile.get_grid_position()
	for corner: Vector2i in CORNERS:
		var corner_index: Vector2i = grid_position + corner
		if posmod(corner_index.x, 2) != 0 or posmod(corner_index.y, 2) != 0: continue
		if not _is_last_room_tile_around(tile, corner_index): continue
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(corner_index) ^ hash(&"pillar")
		var spot: Vector2 = (Vector2(corner) - Vector2.ONE * 0.5) * tile.level.grid_size
		_add_prop(decorations, room_pillars, _to_model(tile, _on_floor(spot), _random_turn(random).basis), random)

## Whether all four cells around the corner [param corner_index] are room tiles and the others are revealed already
static func _is_last_room_tile_around(tile: Structure, corner_index: Vector2i) -> bool:
	for corner: Vector2i in CORNERS:
		var other: Structure = tile.level.get_placed_tile(corner_index - corner)
		if not other or not other.profile.room_type: return false
		if other != tile and other.shown_status != Structure.Status.REVEALED: return false
	return true

## A transform given in the level's axes, in the tile model's space (the tile is turned by its connections)
static func _to_model(tile: Structure, level_transform: Transform3D, level_basis: Basis = Basis.IDENTITY) -> Transform3D:
	var to_tile: Basis = tile.global_basis.inverse()
	return Transform3D(to_tile * level_basis * level_transform.basis, to_tile * level_transform.origin)

static func _on_floor(spot: Vector2) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(spot.x, 0.0, spot.y))

static func _random_turn(random: RandomNumberGenerator) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, random.randf() * TAU), Vector3.ZERO)

## Adds a prop picked from [param prop_set] at [param prop_transform], in the tile model's space
## @returns the prop, or [code]null[/code] if the set gave none
func _add_prop(decorations: Node3D, collection: PropSet, prop_transform: Transform3D, random: RandomNumberGenerator) -> Model:
	if not collection: return null
	# Scale and material come from the (sub-)collection the prop is taken from
	var prop_set: PropSet = collection.pick_collection(random)
	var scene: PackedScene = prop_set.pick(random)
	if not scene: return null
	var mesh: Node3D = scene.instantiate()
	# Decorations never block clicks or movement
	# Freed at once, so they never collide nor linger outside the tree; nested bodies go with their parent
	for body: Node in mesh.find_children("*", "CollisionObject3D", true, false):
		if not is_instance_valid(body): continue
		body.get_parent().remove_child(body)
		body.free()
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
	var animation: ModelAnimation = prop_set.drop_animation if prop_set.drop_animation else collection.drop_animation
	if animation: prop.set_meta(DROP_ANIMATION, animation)
	prop.add_child(mesh)
	decorations.add_child(prop)
	return prop

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
	prop.play_model_animation(prop.get_meta(DROP_ANIMATION, drop_animation) as ModelAnimation)
