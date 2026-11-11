extends GdUnitTestSuite
## Arches and pillars on the real dungeon: each opening and corner is shared, so it must be dressed exactly once

const LEVEL: String = "res://data/levels/level.tscn"
const DOORWAY_ARCHES: String = "res://data/structures/props/dungeon_doorway_arches.tres"
const ROOM_PILLARS: String = "res://data/structures/props/dungeon_room_pillars.tres"
## The dungeon has no walls yet; the arch ruins stand in for them, so the shared edges are still checked
const WALLS: String = "res://data/structures/props/dungeon_ruined_arches.tres"

const DECORATIONS: String = "res://data/structures/tiles/dungeon_decorations.tres"

var _level: Level
var _doorway_arch_chance: float
var _walls: PropSet
var _wall_chance: float
var _corridor_arch_chance: float

func before_test() -> void:
	# Every doorway gets an arch, so the checks do not depend on the rolls
	var decorations: TileDecorations = load(DECORATIONS)
	_doorway_arch_chance = decorations.doorway_arch_chance
	decorations.doorway_arch_chance = 1.0
	_corridor_arch_chance = decorations.corridor_arch_chance
	_walls = decorations.walls
	_wall_chance = decorations.wall_chance
	decorations.walls = load(WALLS)
	decorations.wall_chance = 0.5
	seed(4321)
	_level = auto_free((load(LEVEL) as PackedScene).instantiate())
	# The dungeon draws from its own dice, not the global ones
	_level.generation_random.seed = 4321
	add_child(_level)
	_level.build_level()
	# Reveal the start's surroundings in rings, like exploring would; tiles further out stay placed, but hidden
	for ring: int in 3:
		for tile: Structure in _tiles_within(ring): tile.status = Structure.Status.REVEALED

func after_test() -> void:
	var decorations: TileDecorations = load(DECORATIONS)
	decorations.doorway_arch_chance = _doorway_arch_chance
	decorations.corridor_arch_chance = _corridor_arch_chance
	decorations.walls = _walls
	decorations.wall_chance = _wall_chance

func _tiles_within(radius: int) -> Array[Structure]:
	var tiles: Array[Structure] = []
	for x: int in range(-radius, radius + 1):
		for y: int in range(-radius, radius + 1):
			var tile: Structure = _level.get_placed_tile(Vector2i(x, y))
			if tile and tile.profile.decorations: tiles.append(tile)
	return tiles

## Every decoration prop from [param prop_set_path], by its position on the level's floor
func _props_of(prop_set_path: String) -> Array[Vector2]:
	var scenes: Array = (load(prop_set_path) as PropSet).props.keys().map(func(scene: PackedScene) -> String: return scene.resource_path)
	var found: Array[Vector2] = []
	for tile: Structure in _tiles_within(4):
		if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			var mesh: Node3D = prop.get_child(0)
			if scenes.has(mesh.scene_file_path): found.append(Vector2((prop as Node3D).global_position.x, (prop as Node3D).global_position.z))
	return found

func _count_near(spots: Array[Vector2], spot: Vector2) -> int:
	return spots.filter(func(other: Vector2) -> bool: return other.distance_to(spot) < 0.3).size()

func test_each_doorway_gets_one_arch() -> void:
	var arches: Array[Vector2] = _props_of(DOORWAY_ARCHES)
	var doorways: int = 0
	var arched: int = 0
	for tile: Structure in _tiles_within(3):
		if tile.shown_status != Structure.Status.REVEALED: continue
		for direction: Level.Direction in tile.get_connections():
			var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.DIRECTION_VECTORS[direction])
			if not neighbour: continue
			if (tile.profile.room_type != null) == (neighbour.profile.room_type != null): continue
			doorways += 1
			var opening: Vector3 = (tile.global_position + neighbour.global_position) * 0.5
			var count: int = _count_near(arches, Vector2(opening.x, opening.z))
			assert_int(count).override_failure_message("Doorway at %s" % opening).is_equal(1)
			arched += count
	assert_int(doorways).override_failure_message("The start should lie in a room with doorways").is_greater(0)
	assert_int(arched).override_failure_message("Some doorways should be arched").is_greater(0)

func test_pillars_stand_once_on_even_corners_inside_rooms() -> void:
	var pillars: Array[Vector2] = _props_of(ROOM_PILLARS)
	for pillar: Vector2 in pillars:
		assert_int(_count_near(pillars, pillar)).is_equal(1)
		var corner_index: Vector2 = pillar / _level.grid_size + Vector2.ONE * 0.5
		assert_vector(corner_index.round()).is_equal_approx(corner_index, Vector2.ONE * 0.01)
		assert_int(posmod(roundi(corner_index.x), 2) + posmod(roundi(corner_index.y), 2)).is_equal(0)
		for corner: Vector2i in TileDecorations.CORNERS:
			var cell: Structure = _level.get_placed_tile(Vector2i(corner_index.round()) - corner)
			assert_object(cell).is_not_null()
			assert_object(cell.profile.room_type).override_failure_message("Pillar at %s is not inside a room" % pillar).is_not_null()

func test_arches_stand_before_the_neighbour_is_revealed() -> void:
	var arches: Array[Vector2] = _props_of(DOORWAY_ARCHES)
	var beside_hidden: int = 0
	for arch: Vector2 in arches:
		var arch_cell: Vector2 = arch / _level.grid_size
		for cell: Vector2 in [arch_cell.floor(), arch_cell.ceil()]:
			var neighbour: Structure = _level.get_placed_tile(Vector2i(cell))
			if neighbour and neighbour.shown_status != Structure.Status.REVEALED: beside_hidden += 1
	assert_int(beside_hidden).override_failure_message("Some arches should lead into unrevealed tiles").is_greater(0)

func test_no_pillar_stands_beside_a_doorway_arch() -> void:
	var pillars: Array[Vector2] = _props_of(ROOM_PILLARS)
	for arch: Vector2 in _props_of(DOORWAY_ARCHES):
		for pillar: Vector2 in pillars: assert_float(pillar.distance_to(arch)).is_greater(0.9)

func test_walls_stand_once_on_closed_edges() -> void:
	# The stand-in walls are arch ruins, which also stand in openings
	var walls: Array[Vector2] = _props_of(WALLS).filter(func(spot: Vector2) -> bool: return not _is_opening(spot))
	assert_array(walls).is_not_empty()
	for wall: Vector2 in walls:
		assert_int(_count_near(walls, wall)).override_failure_message("Two walls at %s" % wall).is_equal(1)
		# A wall stands on the edge between two cells; neither may have an opening there
		var cell: Vector2 = wall / _level.grid_size
		var sides: Array[Vector2i] = [Vector2i(cell.floor()), Vector2i(cell.ceil())]
		for side: Vector2i in sides:
			var tile: Structure = _level.get_placed_tile(side)
			if not tile: continue
			var other: Vector2i = sides[1] if side == sides[0] else sides[0]
			assert_bool(tile.has_connection_to(other)).override_failure_message("Wall in the opening of %s at %s" % [tile.name, wall]).is_false()

## Whether [param spot] (an edge's middle) lies in an opening between two tiles
func _is_opening(spot: Vector2) -> bool:
	var cell: Vector2 = spot / _level.grid_size
	var first: Structure = _level.get_placed_tile(Vector2i(cell.floor()))
	return first != null and first.has_connection_to(Vector2i(cell.ceil()))

func test_architecture_drops_in_first_with_its_own_animation() -> void:
	var drop_animation: ModelAnimation = (load(DOORWAY_ARCHES) as PropSet).drop_animation
	assert_object(drop_animation).is_not_null()
	var architecture_count: int = 0
	for tile: Structure in _tiles_within(2):
		if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		var architecture_done: bool = false
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			var is_architecture: bool = prop.has_meta(TileDecorations.DROP_ANIMATION)
			# Architecture comes first, everything after it drops with the decorations' own animation
			assert_bool(is_architecture and architecture_done).is_false()
			if not is_architecture:
				architecture_done = true
				continue
			architecture_count += 1
			assert_object(prop.get_meta(TileDecorations.DROP_ANIMATION)).is_same(drop_animation)
	assert_int(architecture_count).is_greater(0)

func test_doorway_arches_face_the_room() -> void:
	# The ruins stand in for walls too, which face either way
	var walls: Array = (load(WALLS) as PropSet).props.keys()
	var scenes: Array = (load(DOORWAY_ARCHES) as PropSet).props.keys().filter(func(scene: PackedScene) -> bool: return not walls.has(scene)).map(
			func(scene: PackedScene) -> String: return scene.resource_path)
	var checked: int = 0
	for tile: Structure in _tiles_within(2):
		if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			if not scenes.has((prop.get_child(0) as Node).scene_file_path): continue
			var arch: Node3D = prop
			var front: Vector3 = arch.global_basis.z.normalized()
			var room: Structure = _level.get_placed_tile(_level.world_to_grid_position(arch.global_position + front * 0.5))
			assert_object(room).override_failure_message("No tile in front of the arch at %s" % arch.global_position).is_not_null()
			if not room: continue
			assert_object(room.profile.room_type).is_not_null()
			checked += 1
	assert_int(checked).is_greater(0)

## Like loading a save or joining mid-game: tiles arrive revealed already and are dressed as they get their level
func test_tiles_spawned_revealed_raise_their_pillars() -> void:
	var loaded: Level = auto_free((load(LEVEL) as PackedScene).instantiate())
	add_child(loaded)
	var room: StructureProfile = load("res://data/structures/tiles/room/room_crossing.tres")
	# Four room tiles around the even corner (0, 0)
	for cell: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		loaded._structure_spawner.spawn_at(room, Transform3D(Basis.IDENTITY, loaded.grid_to_world_position(cell)), 0, Structure.Status.REVEALED)
	var scenes: Array = (load(ROOM_PILLARS) as PropSet).props.keys().map(func(scene: PackedScene) -> String: return scene.resource_path)
	var pillars: Array[Vector2] = []
	for cell: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var tile: Structure = loaded.get_placed_tile(cell)
		assert_object(tile).is_not_null()
		if not tile or not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			if scenes.has((prop.get_child(0) as Node).scene_file_path): pillars.append(Vector2((prop as Node3D).global_position.x, (prop as Node3D).global_position.z))
	var corner: float = -loaded.grid_size * 0.5
	assert_int(_count_near(pillars, Vector2(corner, corner))).is_equal(1)

## The props on the edge of [param tile] towards [param neighbour_position], whichever side raised them
func _edge_props(tile: Structure, neighbour_position: Vector2i) -> Array[Model]:
	var props: Array[Model] = []
	var sides: Dictionary[Structure, Vector2i] = {tile: neighbour_position}
	var neighbour: Structure = _level.get_placed_tile(neighbour_position)
	if neighbour: sides[neighbour] = tile.get_grid_position()
	for side: Structure in sides:
		if not side.model or not side.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in side.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			if not prop.has_meta(TileDecorations.EDGE): continue
			var edge: Vector2i = prop.get_meta(TileDecorations.EDGE)
			if edge == sides[side]: props.append(prop as Model)
	return props

func test_a_turned_tile_keeps_its_edge_props_and_decides_open_edges() -> void:
	var decorations: TileDecorations = load(DECORATIONS)
	decorations.corridor_arch_chance = 1.0
	var turned: Structure = null
	for tile: Structure in _tiles_within(2):
		if tile.shown_status != Structure.Status.REVEALED or tile.profile.room_type: continue
		var connections: Array[Level.Direction] = tile.get_connections()
		var turned_connections: Array[Level.Direction] = []
		for connection: Level.Direction in connections: turned_connections.append(Level.turn_direction(connection, 1))
		connections.sort()
		turned_connections.sort()
		if connections != turned_connections:
			turned = tile
			break
	assert_object(turned).override_failure_message("A corridor near the start should change its shape when turned").is_not_null()
	# Tiles the turn builds decide their edges themselves once they are revealed
	var existing: Array[Vector2i] = []
	for direction: Level.Direction in Level.Direction.values():
		var cell: Vector2i = turned.get_grid_position() + Level.DIRECTION_VECTORS[direction]
		if _level.get_placed_tile(cell): existing.append(cell)
	var before: Array[Node] = _own_edge_props(turned)
	_level.rotate_tile(turned, 1, null)
	var new_props: Array[Model] = []
	for prop: Node in _own_edge_props(turned):
		if not before.has(prop): new_props.append(prop as Model)
	for direction: Level.Direction in Level.Direction.values():
		var neighbour_position: Vector2i = turned.get_grid_position() + Level.DIRECTION_VECTORS[direction]
		assert_int(_edge_props(turned, neighbour_position).size()).override_failure_message("Edge towards %s" % neighbour_position).is_less_equal(1)
	# The new props wait until the tile has turned into place; the kept ones turn with it
	for prop: Model in new_props: assert_bool(prop.visible).is_false()
	await await_millis(2000)
	for prop: Model in new_props: assert_bool(prop.visible).is_true()
	for prop: Node in _own_edge_props(turned):
		var edge: Vector2i = prop.get_meta(TileDecorations.EDGE)
		var edge_middle: Vector3 = (_level.grid_to_world_position(turned.get_grid_position()) + _level.grid_to_world_position(edge)) * 0.5
		var prop_position: Vector3 = (prop as Node3D).global_position
		assert_float(Vector2(prop_position.x, prop_position.z).distance_to(Vector2(edge_middle.x, edge_middle.z))).override_failure_message("Prop towards %s" % edge).is_less(0.5)
	var kept: int = 0
	for prop: Node in before: if is_instance_valid(prop) and prop.is_inside_tree(): kept += 1
	assert_int(kept + new_props.size()).is_greater(0)

## The arches and walls [param tile] raised itself
func _own_edge_props(tile: Structure) -> Array[Node]:
	var props: Array[Node] = []
	if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): return props
	for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
		if prop.has_meta(TileDecorations.EDGE): props.append(prop)
	return props
