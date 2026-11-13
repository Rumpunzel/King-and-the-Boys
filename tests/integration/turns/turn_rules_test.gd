extends GdUnitTestSuite
## Turn rules on a generated level built from model-free tiles (no assets): movement points, walls, undo, tile spots, reveals

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level
var _turn_manager: TurnManager
var _hero_profile: CharacterProfile

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_hero_profile = ModelFreeWorld.load_hero_profile()
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
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

## @returns a direction with a passage out of [param cell], or -1
func _open_direction(cell: Vector2i) -> int:
	for direction: Level.Direction in Level.Direction.values():
		if _level.get_step_target(cell, direction) != cell: return direction
	return -1

func _blocked_direction(cell: Vector2i) -> int:
	var tile: Structure = _level.get_placed_tile(cell)
	for direction: Level.Direction in Level.Direction.values():
		if not tile.has_connection(direction): return direction
	return -1

## @returns a placed, walkable tile next to a wall near the start
func _cell_next_to_wall() -> Vector2i:
	for radius: int in range(1, 6):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var cell: Vector2i = _start_cell() + Vector2i(x, y)
				var tile: Structure = _level.get_placed_tile(cell)
				if not tile or tile.get_connections().is_empty(): continue
				if _blocked_direction(cell) >= 0: return cell
	return _start_cell()

## Walks [param hero] towards unvisited cells until a step reveals or discovers tiles.
## @returns the cell the board-changing step came from
func _walk_until_board_changes(hero: Character) -> Vector2i:
	var board_changes: Array[Character] = []
	var record_board_change: Callable = func(character: Character) -> void: board_changes.append(character)
	_level.board_changed.connect(record_board_change)
	var visited: Array[Vector2i] = [hero.grid_cell]
	var previous_cell: Vector2i = hero.grid_cell
	for _guard: int in 40:
		hero.movement_points = 8
		previous_cell = hero.grid_cell
		await _move(hero, _open_direction_towards_new_cells(hero.grid_cell, visited))
		visited.append(hero.grid_cell)
		if not board_changes.is_empty(): break
	_level.board_changed.disconnect(record_board_change)
	assert_array(board_changes).is_not_empty()
	return previous_cell

func _open_direction_towards_new_cells(cell: Vector2i, visited: Array[Vector2i]) -> int:
	for direction: Level.Direction in Level.Direction.values():
		var target: Vector2i = _level.get_step_target(cell, direction)
		if target != cell and not visited.has(target): return direction
	return _open_direction(cell)

func _move(hero: Character, direction: int) -> void:
	_turn_manager.request_move(hero.get_path(), direction as Level.Direction)
	await await_idle_frame()

func _undo(hero: Character) -> void:
	_turn_manager.request_undo(hero.get_path())
	await await_idle_frame()

func test_pieces_share_a_tile_on_their_own_spots() -> void:
	var tile_spots: Array[Vector2] = _level.get_placed_tile(_start_cell()).profile.get_tile_spots()
	var first: Character = await _spawn_hero(_start_cell())
	var second: Character = await _spawn_hero(_start_cell())
	assert_vector(first.tile_spot).is_equal(tile_spots[0])
	assert_vector(second.tile_spot).is_equal(tile_spots[1])
	assert_bool(second.global_position.is_equal_approx(first.global_position)).is_false()
	# The center frees up for the next piece, the second keeps its corner
	first.hide_character()
	assert_vector(_level.get_free_spots(_start_cell()).front()).is_equal(tile_spots[0])
	assert_vector(second.tile_spot).is_equal(tile_spots[1])

func test_things_hold_the_first_spot() -> void:
	var placed_things: Dictionary[Vector2i, Thing] = _level.get("_placed_things")
	placed_things[_start_cell()] = auto_free(Thing.new())
	var tile_spots: Array[Vector2] = _level.get_placed_tile(_start_cell()).profile.get_tile_spots()
	assert_array(_level.get_free_spots(_start_cell())).is_equal(tile_spots.slice(1))
	placed_things.erase(_start_cell())

func test_full_tile_blocks_entry() -> void:
	var start: Vector2i = _start_cell()
	var direction: int = _open_direction(start)
	var target: Vector2i = _level.get_step_target(start, direction as Level.Direction)
	for _index: int in Level.Direction.size() + 1: await _spawn_hero(target)
	assert_array(_level.get_free_spots(target)).is_empty()
	var hero: Character = await _spawn_hero(start)
	await _move(hero, direction)
	assert_vector(hero.grid_cell).is_equal(start)
	assert_int(hero.movement_points).is_equal(hero.profile.speed)
	assert_int(hero.facing).is_equal(direction)

func test_steps_cost_movement_points() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	assert_int(hero.movement_points).is_equal(hero.profile.speed)
	var start: Vector2i = hero.grid_cell
	var direction: int = _open_direction(start)
	await _move(hero, direction)
	assert_vector(hero.grid_cell).is_equal(start + Level.direction_to_vector(direction as Level.Direction))
	assert_int(hero.movement_points).is_equal(hero.profile.speed - 1)
	for _guard: int in 32:
		if hero.movement_points <= 0: break
		await _move(hero, _open_direction(hero.grid_cell))
	var cell_without_points: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(hero.grid_cell))
	assert_vector(hero.grid_cell).is_equal(cell_without_points)

func test_walking_into_a_wall_only_turns() -> void:
	var hero: Character = await _spawn_hero(_cell_next_to_wall())
	var wall: int = _blocked_direction(hero.grid_cell)
	assert_int(wall).is_greater_equal(0)
	var cell: Vector2i = hero.grid_cell
	await _move(hero, wall)
	assert_vector(hero.grid_cell).is_equal(cell)
	assert_int(hero.movement_points).is_equal(hero.profile.speed)
	assert_int(hero.facing).is_equal(wall)

func test_board_changes_exactly_when_tile_statuses_rise() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var board_changes: Array[Character] = []
	_level.board_changed.connect(func(character: Character) -> void: board_changes.append(character))
	for _step: int in 6:
		hero.movement_points = 8
		var statuses_before: Dictionary[Vector2i, Structure.Status] = _tile_statuses()
		board_changes.clear()
		await _move(hero, _open_direction(hero.grid_cell))
		assert_bool(board_changes.is_empty()).is_equal(_tile_statuses() == statuses_before)

## @returns the status of every discovered or revealed tile; newly placed tiles are no board change
func _tile_statuses() -> Dictionary[Vector2i, Structure.Status]:
	var statuses: Dictionary[Vector2i, Structure.Status] = {}
	var placed_tiles: Dictionary[Vector2i, Structure] = _level.get("_placed_tiles")
	for cell: Vector2i in placed_tiles:
		if placed_tiles[cell].status > Structure.Status.PLACED: statuses[cell] = placed_tiles[cell].status
	return statuses

func test_undo_takes_back_any_number_of_steps() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = await _walk_until_board_changes(hero)
	hero.movement_points = 8
	var first_cell: Vector2i = hero.grid_cell
	var back: Level.Direction = Level.get_direction(first_cell, start)
	var out: Level.Direction = Level.get_direction(start, first_cell)
	# Walking over explored tiles does not change the board, so every step stays undoable
	await _move(hero, back)
	await _move(hero, out)
	await _move(hero, back)
	var points: int = hero.movement_points
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(first_cell)
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(start)
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(first_cell)
	assert_int(hero.movement_points).is_equal(points + 3)
	# The step onto first_cell changed the board: undo stops there
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(first_cell)

func test_retracing_a_path_changes_nothing_and_undoes_fully() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var path: Array[Vector2i] = [hero.grid_cell]
	for _step: int in 10:
		hero.movement_points = 30
		await _move(hero, _open_direction_towards_new_cells(hero.grid_cell, path))
		path.append(hero.grid_cell)
	var end_cell: Vector2i = hero.grid_cell
	var board_changes: Array[Character] = []
	_level.board_changed.connect(func(character: Character) -> void: board_changes.append(character))
	for index: int in range(path.size() - 2, -1, -1):
		await _move(hero, Level.get_direction(hero.grid_cell, path[index]))
	assert_array(board_changes).is_empty()
	for _index: int in path.size() - 1: await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(end_cell)

func test_undo_keeps_facing_the_way_the_step_went() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = await _walk_until_board_changes(hero)
	var first_cell: Vector2i = hero.grid_cell
	var back: Level.Direction = Level.get_direction(first_cell, start)
	await _move(hero, back)
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(first_cell)
	# The figure walks back while still facing the way it stepped
	assert_int(hero.facing).is_equal(back)

func test_quick_steps_stretch_one_move() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	hero.movement_points = 8
	var path: Array[Vector2i] = [hero.grid_cell]
	var step_duration: float = _hero_profile.move_animation.duration
	# Three steps right after each other: one move, redirected by each step, with at most one step's time left after it
	for step: int in 3:
		var direction: int = _open_direction_towards_new_cells(hero.grid_cell, path)
		_turn_manager.request_move(hero.get_path(), direction as Level.Direction)
		path.append(hero.grid_cell)
		await await_millis(int(step_duration * 1000.0 * 0.2))
	var target: Vector3 = _level.get_spot_position(hero.grid_cell, hero.tile_spot)
	var waited: float = step_duration * 0.4
	while not hero.global_position.is_equal_approx(target) and waited < step_duration * 4.0:
		await await_millis(50)
		waited += 0.05
	assert_vector(hero.global_position).is_equal_approx(target, Vector3.ONE * 0.01)
	# One after another, the steps would end 3 step durations after the first; the one move ends one after the last
	assert_float(waited + step_duration * 0.4).is_less(step_duration * 2.0)

func test_undo_steps_follow_the_host_stack() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = await _walk_until_board_changes(hero)
	assert_int(hero.undo_steps).is_zero()
	var first_cell: Vector2i = hero.grid_cell
	await _move(hero, Level.get_direction(first_cell, start))
	await _move(hero, Level.get_direction(start, first_cell))
	assert_int(hero.undo_steps).is_equal(2)
	await _undo(hero)
	assert_int(hero.undo_steps).is_equal(1)
	_turn_manager._start_next_turn()
	assert_int(hero.undo_steps).is_zero()

func test_undo_stops_at_a_board_change() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(start))
	var first_cell: Vector2i = hero.grid_cell
	await _move(hero, Level.get_direction(first_cell, start))
	_level.board_changed.emit(hero)
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(start)

func test_undo_can_not_reach_into_the_previous_turn() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(start))
	var first_cell: Vector2i = hero.grid_cell
	_turn_manager._start_next_turn()
	await _move(hero, Level.get_direction(first_cell, start))
	_turn_manager._start_next_turn()
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(start)

func test_undo_finds_another_spot_when_the_old_one_is_taken() -> void:
	var tile_spots: Array[Vector2] = _level.get_placed_tile(_start_cell()).profile.get_tile_spots()
	var hero: Character = await _spawn_hero(_start_cell())
	hero.movement_points = 8
	var start: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(start))
	var first_cell: Vector2i = hero.grid_cell
	await _move(hero, Level.get_direction(first_cell, start))
	await _move(hero, Level.get_direction(start, first_cell))
	# Someone takes the hero's old center spot on the start tile
	var other: Character = await _spawn_hero(start)
	assert_vector(other.tile_spot).is_equal(tile_spots[0])
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(start)
	assert_vector(hero.tile_spot).is_equal(tile_spots[1])

func test_a_step_reveals_tiles_at_once_and_shows_them_later() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	await _walk_until_board_changes(hero)
	var lagging_tiles: Array[Structure] = []
	for cell: Vector2i in _level.get("_placed_tiles"):
		var tile: Structure = _level.get_placed_tile(cell)
		if tile.shown_status < tile.status: lagging_tiles.append(tile)
	assert_array(lagging_tiles).is_not_empty()
	for _guard: int in 150:
		if lagging_tiles.all(func(tile: Structure) -> bool: return tile.shown_status == tile.status): break
		await await_millis(100)
	for tile: Structure in lagging_tiles: assert_int(tile.shown_status).is_equal(tile.status)

func test_walking_over_known_tiles_changes_nothing() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = await _walk_until_board_changes(hero)
	var first_cell: Vector2i = hero.grid_cell
	var board_changes: Array[Character] = []
	_level.board_changed.connect(func(character: Character) -> void: board_changes.append(character))
	await _move(hero, Level.get_direction(first_cell, start))
	await _move(hero, Level.get_direction(start, first_cell))
	assert_array(board_changes).is_empty()

func test_grid_state_and_points_are_saved() -> void:
	await _spawn_hero(_start_cell())
	var second: Character = await _spawn_hero(_start_cell())
	var serializer: SynchronizerSerializer = second.get_node(^"CharacterSynchronizer/SynchronizerSerializer")
	var saved: Dictionary[StringName, Variant] = {}
	var collected: Dictionary[NodePath, Variant] = serializer.collect_properties()
	for property_path: NodePath in collected: saved[property_path.get_concatenated_subnames()] = collected[property_path]
	assert_dict(saved).contains_keys([&"grid_cell", &"tile_spot", &"facing", &"movement_points"])
	assert_vector(saved[&"tile_spot"] as Vector2).is_equal(second.tile_spot)

## A second player keeps the turn open while the local one passes
func _add_other_player() -> Player:
	var other: Player = auto_free(Player.create(2, "Other"))
	var players: Dictionary = Lobby.get("_players")
	players[2] = other
	return other

func _remove_other_player() -> void:
	var players: Dictionary = Lobby.get("_players")
	players.erase(2)

func test_auto_pass_only_without_moves_left() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	_add_other_player()
	var local_id: int = _turn_manager.multiplayer.get_unique_id()
	# A peer that still sees the last turn's moves asks too early
	_turn_manager.request_auto_pass(hero.get_path())
	assert_bool(_turn_manager.has_passed(local_id)).is_false()
	hero.movement_points = 0
	_turn_manager.request_auto_pass(hero.get_path())
	assert_bool(_turn_manager.has_passed(local_id)).is_true()
	_remove_other_player()

func test_undo_takes_a_pass_back_only_when_it_undoes() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	_add_other_player()
	var local_id: int = _turn_manager.multiplayer.get_unique_id()
	var start: Vector2i = await _walk_until_board_changes(hero)
	await _move(hero, Level.get_direction(hero.grid_cell, start))
	_turn_manager.request_pass(true)
	await _undo(hero)
	assert_bool(_turn_manager.has_passed(local_id)).is_false()
	# Nothing left to undo: the pass stays
	_turn_manager.request_pass(true)
	await _undo(hero)
	assert_bool(_turn_manager.has_passed(local_id)).is_true()
	_remove_other_player()

func test_undo_steps_go_with_their_character() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = await _walk_until_board_changes(hero)
	await _move(hero, Level.get_direction(hero.grid_cell, start))
	var undo_stacks: Dictionary = _turn_manager.get("_undo_stacks")
	assert_bool(undo_stacks.has(hero)).is_true()
	hero.queue_free()
	await await_idle_frame()
	assert_bool(undo_stacks.has(hero)).is_false()

func _wait_until_shown(tiles: Array[Structure], timeout_millis: int) -> bool:
	for _guard: int in timeout_millis / 50:
		if tiles.all(func(tile: Structure) -> bool: return tile.shown_status == tile.status): return true
		await await_millis(50)
	return false

func _lagging_tiles() -> Array[Structure]:
	var lagging: Array[Structure] = []
	var placed_tiles: Dictionary[Vector2i, Structure] = _level.get("_placed_tiles")
	for cell: Vector2i in placed_tiles:
		if placed_tiles[cell].shown_status < placed_tiles[cell].status: lagging.append(placed_tiles[cell])
	return lagging

func test_reveals_wait_only_for_the_figure_that_caused_them() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var other: Character = await _spawn_hero(_start_cell())
	other.movement_points = 100
	await _walk_until_board_changes(hero)
	var lagging: Array[Structure] = _lagging_tiles()
	assert_array(lagging).is_not_empty()
	# The other figure keeps stepping back and forth the whole time
	# Lambdas copy local variables, so the flag is shared through an array
	var keep_stepping: Array[bool] = [true]
	var step_other: Callable = func() -> void:
		while keep_stepping[0] and is_instance_valid(other):
			_turn_manager.request_move(other.get_path(), _open_direction(other.grid_cell) as Level.Direction)
			await await_millis(150)
	step_other.call()
	var shown: bool = await _wait_until_shown(lagging, 8000)
	keep_stepping[0] = false
	await await_millis(200)
	assert_bool(shown).is_true()

func test_tiles_wait_for_the_step_that_raised_them() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	await _walk_until_board_changes(hero)
	assert_bool(await _wait_until_shown(_lagging_tiles(), 8000)).is_true()
	# A tile whose step has not reached this peer yet, as a client may see it.
	# The dungeon is random: not every one keeps a tile only placed, but each has one not yet revealed
	var tile: Structure = null
	var placed_tiles: Dictionary[Vector2i, Structure] = _level.get("_placed_tiles")
	for cell: Vector2i in placed_tiles:
		if placed_tiles[cell].status < Structure.Status.REVEALED and placed_tiles[cell].get_connections().size() > 0:
			tile = placed_tiles[cell]
			break
	assert_object(tile).is_not_null()
	tile.status_cause = hero.get_path()
	tile.status_cause_step = hero.step_count + 1
	tile.reveal()
	await await_millis(1000)
	assert_int(tile.shown_status).is_less(Structure.Status.REVEALED)
	hero.step_count += 1
	assert_bool(await _wait_until_shown([tile] as Array[Structure], 3000)).is_true()

func test_tiles_no_step_raised_show_at_once() -> void:
	# Spawning reveals the start: no step caused it
	await _spawn_hero(_start_cell())
	assert_array(_lagging_tiles()).is_empty()
