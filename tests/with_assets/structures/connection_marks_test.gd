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

func _opens_both_ways(tile: Structure, direction: Level.Direction) -> bool:
	var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.DIRECTION_VECTORS[direction])
	return neighbour != null and tile.get_connections().has(direction) and neighbour.get_connections().has(Level.get_opposite(direction))

func test_each_opening_has_a_path() -> void:
	var checked: int = 0
	for tile: Structure in _tiles_within(2):
		if tile.shown_status != Structure.Status.REVEALED or not tile.model: continue
		var paths: Node3D = tile.model.get_node_or_null(NodePath(TileDecorations.PATHS_NODE_NAME))
		assert_object(paths).override_failure_message("%s has no paths" % tile).is_not_null()
		assert_int(paths.get_child_count()).override_failure_message("Paths of %s" % tile).is_equal(tile.get_connections().size())
		for decal: Node in paths.get_children(): assert_object(decal).is_instanceof(Decal)
		checked += 1
	assert_int(checked).is_greater(0)

func test_bridges_join_tiles_opening_to_each_other() -> void:
	var bridged: int = 0
	for tile: Structure in _tiles_within(2):
		for direction: Level.Direction in Level.Direction.values():
			var bridge: Model = _bridge_between(tile, direction)
			assert_bool(bridge != null).override_failure_message("%s towards %s" % [tile, direction]).is_equal(_opens_both_ways(tile, direction))
			if bridge: bridged += 1
	assert_int(bridged).is_greater(0)

func test_a_lifted_tile_keeps_its_paths_and_loses_its_bridges() -> void:
	var tile: Structure = _level.get_placed_tile(Vector2i.ZERO)
	var bridged: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values(): if _bridge_between(tile, direction): bridged.append(direction)
	assert_array(bridged).is_not_empty()
	tile.lifted_by = ^"Someone"
	for direction: Level.Direction in bridged: assert_object(_bridge_between(tile, direction)).is_null()
	assert_object(tile.model.get_node_or_null(NodePath(TileDecorations.PATHS_NODE_NAME))).is_not_null()
	tile.lifted_by = NodePath()
	await await_millis(2000)
	for direction: Level.Direction in bridged: assert_object(_bridge_between(tile, direction)).is_not_null()
