extends GdUnitTestSuite
## A tile that leaves the level (e.g. a save being loaded) leaves its registries with its connections, also while
## its connections still wait to be shown after its reveal

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level
var _start: Vector2i

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)
	_level.build_level()
	# As a character's sight would: the start and the tiles its passages lead to
	_start = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var start_tile: Structure = _level.get_placed_tile(_start)
	start_tile.reveal()
	for connection: Level.Direction in start_tile.get_connections():
		var neighbour: Structure = _level.get_placed_tile(_start + Level.direction_to_vector(connection))
		if neighbour: neighbour.reveal()

func after_test() -> void:
	# Removed tiles and their connections are freed at the end of the frame
	await await_idle_frame()

func _connectors() -> Dictionary:
	return _level.get("_tile_connectors")

func _connections() -> Dictionary:
	return _level.get("_tile_connections")

func _connector_position(tile: Structure, connection: Level.Direction) -> Vector3:
	return _level.call("_get_connector_position", tile.global_position, connection)

## A revealed tile other than the start, with a passage to a revealed neighbour that stays: the start
func _revealed_tile_next_to_the_start() -> Structure:
	var start_tile: Structure = _level.get_placed_tile(_start)
	for connection: Level.Direction in start_tile.get_connections():
		var tile: Structure = _level.get_placed_tile(_start + Level.direction_to_vector(connection))
		if tile and tile.shown_status == Structure.Status.REVEALED and tile.has_connection_to(_start): return tile
	return null

func _remove(tile: Structure) -> void:
	tile.get_parent().remove_child(tile)
	tile.queue_free()

func test_a_removed_tile_leaves_the_registries_with_its_connections() -> void:
	# The connections show half a second after the reveal
	await await_millis(700)
	var tile: Structure = _revealed_tile_next_to_the_start()
	assert_object(tile).is_not_null()
	var cell: Vector2i = tile.get_grid_position()
	var tile_connections: Array = _connections()[tile]
	assert_array(tile_connections).is_not_empty()
	# Its sides: connectors a neighbour still reaches stay (placed, as towards a cell not built yet), the others go
	var kept: Array[Vector3] = []
	var gone: Array[Vector3] = []
	for connection: Level.Direction in tile.get_connections():
		var neighbour: Structure = _level.get_placed_tile(cell + Level.direction_to_vector(connection))
		var side: Vector3 = _connector_position(tile, connection)
		if neighbour and neighbour.has_connection_to(cell): kept.append(side)
		else: gone.append(side)
	assert_array(kept).is_not_empty()
	# Between two revealed tiles: shown
	var towards_start: Vector3 = _connector_position(tile, Level.get_direction(cell, _start))
	assert_int((_connectors()[towards_start] as Structure).shown_status).is_equal(Structure.Status.REVEALED)
	var connector_count: int = _connectors().size()
	_remove(tile)
	assert_object(_level.get_placed_tile(cell)).is_null()
	assert_bool(_connections().has(tile)).is_false()
	for tile_connection: Node in tile_connections: assert_bool(tile_connection.is_queued_for_deletion()).is_true()
	assert_int(_connectors().size()).is_equal(connector_count - gone.size())
	for side: Vector3 in gone: assert_bool(_connectors().has(side)).is_false()
	for side: Vector3 in kept:
		var connector: Structure = _connectors()[side]
		assert_int(connector.shown_status).is_equal(Structure.Status.PLACED)

func test_a_removed_tile_is_followed_no_more() -> void:
	var tile: Structure = _revealed_tile_next_to_the_start()
	assert_object(tile).is_not_null()
	_remove(tile)
	# Not freed until the end of the frame, it could still change: the level no longer listens
	for signal_name: StringName in [&"status_changed", &"shown_status_changed", &"spawn_requested"]:
		for connection: Dictionary in tile.get_signal_connection_list(signal_name):
			var target: Callable = connection["callable"]
			assert_object(target.get_object()).is_not_same(_level)

func test_a_tile_removed_before_its_connections_show_is_skipped() -> void:
	# Revealed in before_test: the connections of these tiles wait half a second to show
	var tile: Structure = _revealed_tile_next_to_the_start()
	assert_object(tile).is_not_null()
	var cell: Vector2i = tile.get_grid_position()
	var start_tile: Structure = _level.get_placed_tile(_start)
	var towards_removed: Vector3 = _connector_position(start_tile, Level.get_direction(_start, cell))
	_remove(tile)
	await await_millis(700)
	assert_object(_level.get_placed_tile(cell)).is_null()
	# The start's own connections showed all the same
	var start_connections: Array = _connections().get(start_tile, [])
	assert_array(start_connections).is_not_empty()
	for tile_connection: Structure in start_connections: assert_int(tile_connection.shown_status).is_equal(Structure.Status.REVEALED)
	# The connector towards the removed tile was not shown by either side's pending callback
	var connector: Structure = _connectors()[towards_removed]
	assert_int(connector.shown_status).is_equal(Structure.Status.PLACED)
