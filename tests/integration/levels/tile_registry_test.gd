extends GdUnitTestSuite
## A tile that leaves the level (e.g. a save being loaded) leaves its registries, also while its bridges still wait to be
## shown after its reveal (the bridges themselves are checked with the real tiles, in connection_marks_test.gd)

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd

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

func test_a_removed_tile_is_followed_no_more() -> void:
	var tile: Structure = _revealed_tile_next_to_the_start()
	assert_object(tile).is_not_null()
	_remove(tile)
	# Not freed until the end of the frame, it could still change: the level no longer listens
	for signal_name: StringName in [&"status_changed", &"shown_status_changed", &"spawn_requested"]:
		for connection: Dictionary in tile.get_signal_connection_list(signal_name):
			var target: Callable = connection["callable"]
			assert_object(target.get_object()).is_not_same(_level)

func test_a_tile_removed_before_its_bridges_show_is_skipped() -> void:
	# Revealed in before_test: the bridges of these tiles wait half a second to show, bound to the cell
	var tile: Structure = _revealed_tile_next_to_the_start()
	assert_object(tile).is_not_null()
	var cell: Vector2i = tile.get_grid_position()
	_remove(tile)
	await await_millis(700)
	assert_object(_level.get_placed_tile(cell)).is_null()
	assert_object(_level.get_placed_tile(_start)).is_not_null()
