extends GdUnitTestSuite
## Worn paths and bridges on the real dungeon: a path decal per opening of each revealed tile, a bridge wherever two tiles
## open to each other, and none into a lifted tile

const LEVEL: String = "res://data/levels/level.tscn"

var _level: Level

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free((load(LEVEL) as PackedScene).instantiate())
	_level.generation_random.seed = 4321
	add_child(_level)
	_level.build_level()
	for ring: int in 3:
		for tile: Structure in _tiles_within(ring): tile.status = Structure.Status.REVEALED
	await await_idle_frame()

func _tiles_within(radius: int) -> Array[Structure]:
	var tiles: Array[Structure] = []
	for x: int in range(-radius, radius + 1):
		for y: int in range(-radius, radius + 1):
			var tile: Structure = _level.get_placed_tile(Vector2i(x, y))
			if tile and tile.profile.decorations: tiles.append(tile)
	return tiles

func _bridges() -> Dictionary:
	return _level.get("_bridges")

func _bridge_between(tile: Structure, direction: Level.Direction) -> Model:
	return _bridges().get(_level._get_connector_position(tile.global_position, direction))

## Whether a bridge belongs between [param tile] and its neighbour in [param direction]: both open, and they are not one room
func _needs_bridge(tile: Structure, direction: Level.Direction) -> bool:
	var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.DIRECTION_VECTORS[direction])
	if not neighbour or (tile.profile.room_type and neighbour.profile.room_type == tile.profile.room_type): return false
	return tile.get_connections().has(direction) and neighbour.get_connections().has(Level.get_opposite(direction))

func test_each_opening_outside_rooms_has_a_path() -> void:
	var checked: int = 0
	for tile: Structure in _tiles_within(2):
		if tile.shown_status != Structure.Status.REVEALED or not tile.model: continue
		var paths: Node3D = tile.model.get_node_or_null(NodePath(TileDecorations.PATHS_NODE_NAME))
		assert_object(paths).override_failure_message("%s has no paths" % tile).is_not_null()
		# Room tiles go without, as the dungeon's decorations give them no path material
		var expected: int = 0 if tile.profile.room_type else tile.get_openings().size()
		assert_int(paths.get_child_count()).override_failure_message("Paths of %s" % tile).is_equal(expected)
		for path: Node in paths.get_children(): assert_object(path).is_instanceof(MeshInstance3D)
		if expected > 0: checked += 1
	assert_int(checked).is_greater(0)

func test_bridges_join_tiles_opening_to_each_other_outside_rooms() -> void:
	var bridged: int = 0
	for tile: Structure in _tiles_within(2):
		for direction: Level.Direction in Level.Direction.values():
			var bridge: Model = _bridge_between(tile, direction)
			assert_bool(bridge != null).override_failure_message("%s towards %s" % [tile, direction]).is_equal(_needs_bridge(tile, direction))
			if not bridge: continue
			bridged += 1
			assert_int(bridge.get_child_count()).override_failure_message("A bridge is laid from several planks").is_greater(1)
	assert_int(bridged).is_greater(0)

func test_a_lifted_tile_keeps_its_paths_and_loses_its_bridges() -> void:
	var tile: Structure = null
	var bridged: Array[Level.Direction] = []
	for candidate: Structure in _tiles_within(2):
		for direction: Level.Direction in Level.Direction.values(): if _bridge_between(candidate, direction): bridged.append(direction)
		if not bridged.is_empty() and candidate.model:
			tile = candidate
			break
		bridged.clear()
	assert_object(tile).override_failure_message("A tile near the start should have a bridge").is_not_null()
	tile.lifted_by = ^"Someone"
	for direction: Level.Direction in bridged: assert_object(_bridge_between(tile, direction)).is_null()
	assert_object(tile.model.get_node_or_null(NodePath(TileDecorations.PATHS_NODE_NAME))).is_not_null()
	tile.lifted_by = NodePath()
	await await_millis(2000)
	for direction: Level.Direction in bridged: assert_object(_bridge_between(tile, direction)).is_not_null()

func test_crystals_spread_along_their_edge() -> void:
	var decorations: TileDecorations = load("res://data/structures/tiles/dungeon_decorations.tres")
	var crystals: PropSet = load("res://data/structures/props/crystals.tres")
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 11
	# By the side facing right, turned any way: the edge runs along z
	var spot: Transform3D = Transform3D(Basis(Vector3.UP, 1.0), Vector3.ZERO)
	var cluster: Model = decorations.call("_add_prop", holder, crystals, spot, random, TileDecorations._along_edge(Level.Direction.RIGHT))
	assert_int(cluster.get_child_count()).is_between(crystals.piece_count.x, crystals.piece_count.y)
	var reach: float = 0.0
	for piece: Node in cluster.get_children():
		var place: Vector3 = spot * (piece as Node3D).position
		assert_float(absf(place.x)).is_less_equal(crystals.scatter_radius + 0.01)
		assert_float(absf(place.z)).is_less_equal(crystals.scatter_length + crystals.scatter_radius + 0.01)
		reach = maxf(reach, absf(place.z))
	assert_float(reach).override_failure_message("The crystals spread along the edge").is_greater(crystals.scatter_length * 0.4)
