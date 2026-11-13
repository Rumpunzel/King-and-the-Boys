extends GdUnitTestSuite
## Turning tiles on a generated level (no assets): passages, connections, pieces on the tile, lifting, building after the turn

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level
var _hero_profile: CharacterProfile

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_hero_profile = ModelFreeWorld.load_hero_profile()
	add_child(_level)
	_level.build_level()
	await await_idle_frame()

func _spawn_hero(grid_cell: Vector2i) -> Character:
	var hero: Character = auto_free(_hero_profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(grid_cell))))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

func _start_cell() -> Vector2i:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position((spawn_points.front() as Node3D).global_position)

## @returns the placed tiles that are not part of the outer wall, nearest to the start first
func _inner_tiles() -> Array[Structure]:
	var placed_tiles: Dictionary = _level.get("_placed_tiles")
	var tiles: Array[Structure] = []
	for cell: Vector2i in placed_tiles:
		var tile: Structure = placed_tiles[cell]
		if tile.profile.resource_path != ModelFreeWorld.WALL_TILE: tiles.append(tile)
	var start: Vector2i = _start_cell()
	tiles.sort_custom(func(a: Structure, b: Structure) -> bool: return a.get_grid_position().distance_squared_to(start) < b.get_grid_position().distance_squared_to(start))
	return tiles

func _turned_connections(tile: Structure, clockwise_turns: int) -> Array[Level.Direction]:
	var turned: Array[Level.Direction] = []
	for connection: Level.Direction in tile.get_connections(): turned.append(Level.turn_direction(connection, clockwise_turns))
	turned.sort()
	return turned

func _sorted_connections(tile: Structure) -> Array[Level.Direction]:
	var connections: Array[Level.Direction] = tile.get_connections()
	connections.sort()
	return connections

## @returns a direction [param tile] opens into after [param clockwise_turns] that it does not open into now, matching [param wanted_neighbour]: "none", "closed"
func _new_opening(tile: Structure, clockwise_turns: int, wanted_neighbour: String) -> int:
	for direction: Level.Direction in _turned_connections(tile, clockwise_turns):
		if tile.get_connections().has(direction): continue
		var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.direction_to_vector(direction))
		if wanted_neighbour == "none" and not neighbour: return direction
		if wanted_neighbour == "closed" and neighbour and not neighbour.get_connections().has(Level.get_opposite(direction)): return direction
	return -1

func test_a_turned_tile_rebuilds_its_connections() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	for tile: Structure in _inner_tiles():
		if _turned_connections(tile, 1) == _sorted_connections(tile): continue
		var expected: Array[Level.Direction] = _turned_connections(tile, 1)
		_level.rotate_tile(tile, 1, hero)
		await await_idle_frame()
		assert_array(_sorted_connections(tile)).is_equal(expected)
		return
	fail("No tile changes its shape when turned")

func test_pieces_on_the_tile_turn_along() -> void:
	var first: Character = await _spawn_hero(_start_cell())
	var second: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _level.get_placed_tile(_start_cell())
	var spot: Vector2 = second.tile_spot
	var facing: Level.Direction = second.facing
	_level.rotate_tile(tile, 1, first)
	assert_vector(second.tile_spot).is_equal(Level.turn_spot(spot, 1))
	assert_int(second.facing).is_equal(Level.turn_direction(facing, 1))
	assert_vector(second.grid_cell).is_equal(_start_cell())
	assert_vector(first.tile_spot).is_not_equal(second.tile_spot)

func test_a_turned_piece_keeps_off_the_spot_a_corner_thing_holds() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _level.get_placed_tile(_start_cell())
	for spot: Vector2 in tile.profile.get_tile_spots():
		if spot.x != 0.0 and spot.y != 0.0: hero.place_on_grid(_start_cell(), spot, hero.facing)
	# A centrepiece on the corner a half turn carries the hero towards; it stays there as the tile turns
	var carried_to: Vector2 = Level.turn_spot(hero.tile_spot, 2)
	var corner: Vector2i = Vector2i(int(carried_to.x > 0.0), int(carried_to.y > 0.0))
	var corner_things: Dictionary = _level.get("_corner_things")
	var centrepiece: Thing = auto_free(Thing.new())
	corner_things[_start_cell() + corner] = centrepiece
	var held: Vector2 = Level.get_spot_towards(tile.profile.get_tile_spots(), Vector2(corner) * 2.0 - Vector2.ONE)
	assert_vector(held).is_equal(carried_to)
	_level.rotate_tile(tile, 2, hero)
	corner_things.erase(_start_cell() + corner)
	assert_vector(hero.tile_spot).is_not_equal(held)
	assert_bool(tile.profile.get_tile_spots().has(hero.tile_spot)).is_true()

func test_one_sided_openings_are_dead_ends() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	for tile: Structure in _inner_tiles():
		for clockwise_turns: int in range(1, 4):
			var direction: int = _new_opening(tile, clockwise_turns, "closed")
			if direction < 0: continue
			_level.rotate_tile(tile, clockwise_turns, hero)
			assert_bool(tile.has_connection(direction as Level.Direction)).is_true()
			assert_bool(_level.is_passage(tile.get_grid_position(), direction as Level.Direction)).is_false()
			assert_vector(_level.get_step_target(tile.get_grid_position(), direction as Level.Direction)).is_equal(tile.get_grid_position())
			return
	fail("No tile opens into a closed side when turned")

func test_lifted_tiles_have_no_passages() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var direction: Level.Direction = Level.Direction.UP
	for candidate: Level.Direction in Level.Direction.values():
		if _level.is_passage(_start_cell(), candidate): direction = candidate
	assert_bool(_level.is_passage(_start_cell(), direction)).is_true()
	var neighbour: Structure = _level.get_placed_tile(_start_cell() + Level.direction_to_vector(direction))
	neighbour.lifted_by = hero.get_path()
	assert_bool(neighbour.is_lifted()).is_true()
	assert_vector(_level.get_step_target(_start_cell(), direction)).is_equal(_start_cell())
	assert_bool(_level.is_passage(neighbour.get_grid_position(), Level.get_opposite(direction))).is_false()
	neighbour.lifted_by = NodePath()
	assert_bool(_level.is_passage(_start_cell(), direction)).is_true()

func test_setting_a_lifted_tile_down_forgets_its_turns() -> void:
	var tile: Structure = _level.get_placed_tile(_start_cell())
	tile.lifted_by = ^"Someone"
	tile.lift_turns = 2
	tile.lifted_by = NodePath()
	assert_int(tile.lift_turns).is_equal(0)

func test_new_openings_build_and_reveal() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var board_changes: Array[Character] = []
	_level.board_changed.connect(func(character: Character) -> void: board_changes.append(character))
	for tile: Structure in _inner_tiles():
		if tile.status != Structure.Status.REVEALED: continue
		# Standing on the tile builds and reveals what its passages lead to already
		hero.place_on_grid(tile.get_grid_position(), Vector2.ZERO, hero.facing)
		for clockwise_turns: int in range(1, 4):
			var direction: int = _new_opening(tile, clockwise_turns, "none")
			if direction < 0: continue
			var new_cell: Vector2i = tile.get_grid_position() + Level.direction_to_vector(direction as Level.Direction)
			board_changes.clear()
			_level.rotate_tile(tile, clockwise_turns, hero)
			await await_idle_frame()
			var new_tile: Structure = _level.get_placed_tile(new_cell)
			assert_object(new_tile).is_not_null()
			assert_array(board_changes).contains([hero])
			if _level.is_passage(tile.get_grid_position(), direction as Level.Direction):
				assert_int(new_tile.status).is_equal(Structure.Status.REVEALED)
			return
	fail("No revealed tile opens into an empty cell when turned")

func test_building_stops_at_a_closed_side_a_turned_tile_faces() -> void:
	# In an unbuilt corner, laid out by hand rather than found in the random dungeon: a dead end (as a turned tile) opening only
	# right, into a straight corridor running up and down, closed towards it
	var cell: Vector2i = Vector2i(-_level.grid_extents.x + 3, -_level.grid_extents.y + 3)
	var closed_neighbour: Vector2i = cell + Vector2i.RIGHT
	for nearby: Vector2i in [cell, closed_neighbour, closed_neighbour + Vector2i.UP, closed_neighbour + Vector2i.DOWN]:
		assert_object(_level.get_placed_tile(nearby)).is_null()
	var dead_end: Structure = _spawn_tile("res://tests/fixtures/tiles/dead_end.tres", cell, 0)
	var only_right: Array[Level.Direction] = [Level.Direction.RIGHT]
	for _turn: int in 3:
		if dead_end.get_connections() == only_right: break
		dead_end.clockwise_turns = posmod(dead_end.clockwise_turns + 1, 4)
	assert_array(dead_end.get_connections()).contains_exactly([Level.Direction.RIGHT])
	var straight: Structure = _spawn_tile("res://tests/fixtures/tiles/straight.tres", closed_neighbour, 0)
	if straight.get_connections().has(Level.Direction.LEFT): straight.clockwise_turns = 1
	assert_bool(straight.get_connections().has(Level.Direction.LEFT)).is_false()
	assert_bool(straight.get_connections().has(Level.Direction.UP)).is_true()
	_level._build_dungeon_from(cell)
	# Nothing is built through the straight's closed side, into the cells it leads to
	for beyond: Vector2i in [closed_neighbour + Vector2i.UP, closed_neighbour + Vector2i.DOWN]:
		assert_object(_level.get_placed_tile(beyond)).override_failure_message("Built through a closed side at %s" % beyond).is_null()

func _spawn_tile(profile_path: String, cell: Vector2i, clockwise_turns: int) -> Structure:
	_level._structure_spawner.spawn_at(load(profile_path) as StructureProfile, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell)), clockwise_turns, Structure.Status.PLACED)
	return _level.get_placed_tile(cell)

func test_a_cell_of_the_outer_wall_is_left_as_it_is() -> void:
	var wall_cell: Vector2i = Vector2i(_level.grid_extents.x, 0)
	var wall: Structure = _level.get_placed_tile(wall_cell)
	assert_object(wall).is_not_null()
	# As when a turned tile next to the wall opens towards it
	_level.spawn_at(wall_cell)
	assert_object(_level.get_placed_tile(wall_cell)).is_same(wall)

func test_a_revealed_tile_discovers_nothing_through_a_closed_side() -> void:
	# Two tiles in an unbuilt corner: a crossing, and beside it one closed all round
	var cell: Vector2i = Vector2i(-_level.grid_extents.x + 2, -_level.grid_extents.y + 2)
	var beside: Vector2i = cell + Vector2i.RIGHT
	assert_object(_level.get_placed_tile(cell)).is_null()
	assert_object(_level.get_placed_tile(beside)).is_null()
	var crossing: Structure = _spawn_tile(ModelFreeWorld.STARTING_TILE, cell, 0)
	_spawn_tile("res://tests/fixtures/tiles/solid.tres", beside, 0)
	assert_bool(crossing.get_connections().has(Level.Direction.RIGHT)).is_true()
	_level._reveal_tile(crossing)
	assert_int(_level.get_placed_tile(beside).status).is_less(Structure.Status.DISCOVERED)

func test_the_thing_on_a_turned_tile_turns_with_it_on_every_peer() -> void:
	var tile: Structure = _level.get_placed_tile(_start_cell())
	var chest: Thing = auto_free(Thing.new())
	chest.model = Model.new()
	add_child(chest)
	chest.global_position = tile.global_position
	var placed_things: Dictionary = _level.get("_placed_things")
	placed_things[_start_cell()] = chest
	var facing: Vector3 = chest.global_basis.z
	# A peer only receives the tile's turns (the thing's transform is sent as it spawns): it turns the thing itself
	tile.clockwise_turns = posmod(tile.clockwise_turns + 1, Level.Direction.size())
	placed_things.erase(_start_cell())
	assert_vector(chest.global_basis.z).is_equal_approx(facing.rotated(Vector3.UP, -PI * 0.5), Vector3.ONE * 0.001)
