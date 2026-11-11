extends GdUnitTestSuite
## A tile that leaves the level (e.g. a save being loaded) leaves its registries with its connections, also while
## its connections still wait to be shown after its reveal

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)
	_level.build_level()
	# As a character's sight would: the start and the tiles its passages lead to
	var start: Vector2i = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var start_tile: Structure = _level.get_placed_tile(start)
	start_tile.reveal()
	for connection: Level.Direction in start_tile.get_connections():
		var neighbour: Structure = _level.get_placed_tile(start + Level.direction_to_vector(connection))
		if neighbour: neighbour.reveal()

func after_test() -> void:
	# Removed tiles and their connections are freed at the end of the frame
	await await_idle_frame()

func _connectors() -> Dictionary:
	return _level.get("_tile_connectors")

func _connections() -> Dictionary:
	return _level.get("_tile_connections")

## A revealed tile with a passage to a revealed neighbour, other than the start
func _revealed_tile_with_revealed_neighbour() -> Structure:
	for tile: Structure in _level.get_placed_tiles():
		if tile.status != Structure.Status.REVEALED or tile.get_connections().is_empty(): continue
		for connection: Level.Direction in tile.get_connections():
			var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.direction_to_vector(connection))
			if neighbour and neighbour.status == Structure.Status.REVEALED and neighbour.has_connection_to(tile.get_grid_position()): return tile
	return null

func _remove(tile: Structure) -> void:
	tile.get_parent().remove_child(tile)
	tile.queue_free()

func test_a_removed_tile_leaves_the_registries_with_its_connections() -> void:
	await await_idle_frame()
	var tile: Structure = _revealed_tile_with_revealed_neighbour()
	assert_object(tile).is_not_null()
	var cell: Vector2i = tile.get_grid_position()
	var tile_connections: Array = _connections()[tile]
	var connector_count: int = _connectors().size()
	_remove(tile)
	assert_object(_level.get_placed_tile(cell)).is_null()
	assert_bool(_connections().has(tile)).is_false()
	for tile_connection: Node in tile_connections: assert_bool(tile_connection.is_queued_for_deletion()).is_true()
	# Connectors a neighbour still reaches stay, the others go
	assert_int(_connectors().size()).is_less(connector_count + 1)
	for connection: Level.Direction in tile.get_connections():
		var neighbour: Structure = _level.get_placed_tile(cell + Level.direction_to_vector(connection))
		var connector_position: Vector3 = _level.grid_to_world_position(cell) + Vector3(Level.direction_to_vector(connection).x, 0.0, Level.direction_to_vector(connection).y) * _level.grid_size * 0.5
		var kept: bool = neighbour != null and neighbour.has_connection_to(cell)
		assert_bool(_connectors().has(connector_position)).override_failure_message("Connector %s should be %s" % [connector_position, "kept" if kept else "gone"]).is_equal(kept)

func test_a_tile_removed_before_its_connections_show_is_skipped() -> void:
	# Revealed while building: the connections of these tiles wait half a second to show
	var tile: Structure = _revealed_tile_with_revealed_neighbour()
	assert_object(tile).is_not_null()
	var cell: Vector2i = tile.get_grid_position()
	var connections: Array[Level.Direction] = tile.get_connections()
	_remove(tile)
	await await_millis(700)
	assert_object(_level.get_placed_tile(cell)).is_null()
	# The neighbours' own connections showed all the same
	for connection: Level.Direction in connections:
		var neighbour: Structure = _level.get_placed_tile(cell + Level.direction_to_vector(connection))
		if not neighbour or neighbour.shown_status != Structure.Status.REVEALED: continue
		for tile_connection: Structure in _connections().get(neighbour, []):
			assert_int(tile_connection.shown_status).is_equal(Structure.Status.REVEALED)
