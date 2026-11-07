extends GdUnitTestSuite
## Turn rules on a real generated level: movement points, walls, undo, tile spots, pass and turn end

const LEVEL_SCENE: String = "res://data/levels/level.tscn"
const HERO_PROFILE: String = "res://data/characters/people/dwarf.tres"
const OTHER_PLAYER_ID: int = 2

var _level: Level
var _turn_manager: TurnManager

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free((load(LEVEL_SCENE) as PackedScene).instantiate())
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()

func _spawn_hero(grid_cell: Vector2i) -> Character:
	var profile: CharacterProfile = load(HERO_PROFILE)
	var hero: Character = auto_free(profile.create(0, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(grid_cell))))
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

func _move(hero: Character, direction: int) -> void:
	_turn_manager.request_move(hero.get_path(), direction as Level.Direction)
	await await_idle_frame()

func _undo(hero: Character) -> void:
	_turn_manager.request_undo(hero.get_path())
	await await_idle_frame()

func test_profile_tile_spots_are_directions_times_extents() -> void:
	var tile_spots: Array[Vector2] = _level.get_placed_tile(_start_cell()).profile.get_tile_spots()
	assert_array(tile_spots).is_equal([Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])

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

func test_first_step_into_the_dungeon_changes_the_board() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var board_changes: Array[Character] = []
	_level.board_changed.connect(board_changes.append)
	await _move(hero, _open_direction(hero.grid_cell))
	assert_array(board_changes).contains_exactly([hero])

func test_undo_takes_back_any_number_of_steps() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	hero.movement_points = 8
	var start: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(start))
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
	# The first step changed the board: undo stops there
	await _undo(hero)
	assert_vector(hero.grid_cell).is_equal(first_cell)

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

func test_a_tile_queued_from_two_directions_is_one_board_change() -> void:
	var tile: Structure = _level.get_placed_tile(_cell_next_to_wall())
	var board_change_count: int = _level.get("_board_change_count")
	_level.call("_queue_discover", tile, Level.Direction.UP)
	_level.call("_queue_discover", tile, Level.Direction.RIGHT)
	assert_int(_level.get("_board_change_count")).is_equal(board_change_count + 1)

func test_grid_state_and_points_are_saved() -> void:
	await _spawn_hero(_start_cell())
	var second: Character = await _spawn_hero(_start_cell())
	var serializer: SynchronizerSerializer = second.get_node(^"CharacterSynchronizer/SynchronizerSerializer")
	var saved: Dictionary[StringName, Variant] = {}
	var collected: Dictionary[NodePath, Variant] = serializer.collect_properties()
	for property_path: NodePath in collected: saved[property_path.get_concatenated_subnames()] = collected[property_path]
	assert_dict(saved).contains_keys([&"grid_cell", &"tile_spot", &"facing", &"movement_points"])
	assert_vector(saved[&"tile_spot"] as Vector2).is_equal(second.tile_spot)

func test_turn_ends_once_everyone_passed() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var local_id: int = _turn_manager.multiplayer.get_unique_id()
	var other: Player = auto_free(Player.create(OTHER_PLAYER_ID, "Other"))
	var players: Dictionary = Lobby.get("_players")
	players[OTHER_PLAYER_ID] = other
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	assert_bool(_turn_manager.has_passed(local_id)).is_true()
	assert_int(_turn_manager.turn_number).is_equal(turn)
	await _move(hero, _open_direction(hero.grid_cell))
	assert_int(hero.movement_points).is_equal(hero.profile.speed)
	_turn_manager.request_pass(false)
	assert_bool(_turn_manager.has_passed(local_id)).is_false()
	await _move(hero, _open_direction(hero.grid_cell))
	_turn_manager.request_pass(true)
	# The other player leaves instead of passing
	players.erase(OTHER_PLAYER_ID)
	Lobby.player_disconnected.emit(other)
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)
	assert_bool(_turn_manager.has_passed(local_id)).is_false()
	assert_int(hero.movement_points).is_equal(hero.profile.speed)
