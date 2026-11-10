extends GdUnitTestSuite
## The Mystic's Turn Tile ability on a generated level (no assets): lifting, cost by angle, setting down, undo

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const TURN_TILE: RotateTileAbility = preload("res://data/abilities/turn_tile.tres")

var _level: Level
var _turn_manager: TurnManager
var _hero_profile: CharacterProfile
var _original_abilities: Array[Ability]

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_hero_profile = ModelFreeWorld.load_hero_profile()
	# The profile is cached: restored after each test
	_original_abilities = _hero_profile.abilities
	_hero_profile.abilities = [TURN_TILE]
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()

func after_test() -> void:
	_hero_profile.abilities = _original_abilities

func _spawn_hero(grid_cell: Vector2i) -> Character:
	var hero: Character = auto_free(_hero_profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(grid_cell))))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	hero.movement_points = 8
	return hero

func _start_cell() -> Vector2i:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position((spawn_points.front() as Node3D).global_position)

## Puts [param hero] on the tile nearest the start whose shape changes when turned; standing there reveals it
func _stand_on_turnable_tile(hero: Character) -> Structure:
	var placed_tiles: Dictionary = _level.get("_placed_tiles")
	var best: Structure = null
	for cell: Vector2i in placed_tiles:
		var tile: Structure = placed_tiles[cell]
		if tile.profile.resource_path == ModelFreeWorld.WALL_TILE: continue
		if RotateTileAbility._get_turned_connections(tile, 1) == RotateTileAbility._get_turned_connections(tile, 0): continue
		if not best or cell.distance_squared_to(_start_cell()) < best.get_grid_position().distance_squared_to(_start_cell()): best = tile
	assert_object(best).is_not_null()
	hero.place_on_grid(best.get_grid_position(), Vector2.ZERO, hero.facing)
	return best

func _begin(hero: Character, target: Vector2i) -> void:
	_turn_manager.request_ability_begin(hero.get_path(), ResourceId.of(TURN_TILE), target)

func _adjust(hero: Character, argument: int) -> void:
	_turn_manager.request_ability_adjust(hero.get_path(), argument)

func _set_down(hero: Character, argument: int) -> void:
	_turn_manager.request_ability(hero.get_path(), ResourceId.of(TURN_TILE), hero.grid_cell, argument)

func _turn(hero: Character, argument: int) -> void:
	_begin(hero, hero.grid_cell)
	_adjust(hero, argument)
	_set_down(hero, argument)

## Turns until a turn reveals nothing new, so it can be undone
func _turn_undoably(hero: Character) -> void:
	for _attempt: int in 8:
		_turn(hero, 1)
		if hero.undo_steps > 0: return
		hero.movement_points = 8
	fail("Every turn changed the board")

func test_each_net_quarter_turn_costs_a_point() -> void:
	var costs: Array[int] = []
	for argument: int in [0, 1, 2, 3, 4, -1]: costs.append(TURN_TILE.get_cost(null, Vector2i.ZERO, argument))
	var expected: Array[int] = [0, 1, 2, 1, 0, 1]
	assert_array(costs).is_equal(expected)

func test_the_mystic_lifts_turns_and_sets_down_their_tile() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _stand_on_turnable_tile(hero)
	var turns: int = tile.clockwise_turns
	# A straight corridor keeps its shape when turned halfway: then three quarter turns
	var argument: int = 2 if RotateTileAbility._get_turned_connections(tile, 2) != RotateTileAbility._get_turned_connections(tile, 0) else 3
	var expected: Array[Level.Direction] = RotateTileAbility._get_turned_connections(tile, argument)
	_begin(hero, hero.grid_cell)
	assert_bool(tile.lifted_by == hero.get_path()).is_true()
	assert_bool(_level.is_passage(hero.grid_cell, tile.get_connections().front() as Level.Direction)).is_false()
	_adjust(hero, 1)
	assert_int(tile.lift_turns).is_equal(1)
	_adjust(hero, argument)
	assert_int(tile.lift_turns).is_equal(argument)
	assert_int(hero.movement_points).is_equal(8)
	_set_down(hero, argument)
	assert_bool(tile.is_lifted()).is_false()
	assert_int(tile.clockwise_turns).is_equal(posmod(turns + argument, 4))
	assert_array(RotateTileAbility._get_turned_connections(tile, 0)).is_equal(expected)
	assert_int(hero.movement_points).is_equal(8 - TURN_TILE.get_cost(hero, hero.grid_cell, argument))
	assert_str(hero.active_ability_id).is_empty()

func test_only_the_own_tile_is_lifted() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	_stand_on_turnable_tile(hero)
	var other_cell: Vector2i = hero.grid_cell + Vector2i.RIGHT
	_begin(hero, other_cell)
	assert_str(hero.active_ability_id).is_empty()
	var other_tile: Structure = _level.get_placed_tile(other_cell)
	if other_tile: assert_bool(other_tile.is_lifted()).is_false()

func test_lifting_needs_a_point() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _stand_on_turnable_tile(hero)
	hero.movement_points = 0
	_begin(hero, hero.grid_cell)
	assert_bool(tile.is_lifted()).is_false()

func test_unpaid_angles_are_refused() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _stand_on_turnable_tile(hero)
	hero.movement_points = 1
	_begin(hero, hero.grid_cell)
	_adjust(hero, 2)
	assert_int(tile.lift_turns).is_equal(0)
	_adjust(hero, 3)
	assert_int(tile.lift_turns).is_equal(3)
	_set_down(hero, 3)
	assert_int(hero.movement_points).is_equal(0)

func test_setting_down_unturned_is_free() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _stand_on_turnable_tile(hero)
	var turns: int = tile.clockwise_turns
	_begin(hero, hero.grid_cell)
	_adjust(hero, 1)
	_adjust(hero, 0)
	_set_down(hero, 0)
	assert_bool(tile.is_lifted()).is_false()
	assert_int(tile.clockwise_turns).is_equal(turns)
	assert_int(hero.movement_points).is_equal(8)
	assert_str(hero.active_ability_id).is_empty()

func test_turning_into_the_same_shape_is_free() -> void:
	# The start tile is a crossing
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _level.get_placed_tile(_start_cell())
	assert_int(tile.get_connections().size()).is_equal(4)
	var turns: int = tile.clockwise_turns
	_turn(hero, 1)
	assert_int(tile.clockwise_turns).is_equal(turns)
	assert_int(hero.movement_points).is_equal(8)
	assert_bool(tile.is_lifted()).is_false()

func test_undo_turns_the_tile_back_and_refunds() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var tile: Structure = _stand_on_turnable_tile(hero)
	_turn_undoably(hero)
	var turns: int = tile.clockwise_turns
	var points: int = hero.movement_points
	_turn_manager.request_undo(hero.get_path())
	assert_int(tile.clockwise_turns).is_equal(posmod(turns - 1, 4))
	assert_int(hero.movement_points).is_equal(points + 1)
	assert_int(hero.undo_steps).is_equal(0)

func test_a_turn_that_reveals_tiles_can_not_be_undone() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var board_changes: Array[Character] = []
	_level.board_changed.connect(func(character: Character) -> void: board_changes.append(character))
	var turns: int = _stand_where_a_turn_opens_into_nothing(hero)
	assert_int(turns).is_greater(0)
	board_changes.clear()
	_turn(hero, turns)
	assert_array(board_changes).contains([hero])
	assert_int(hero.undo_steps).is_equal(0)

## Puts [param hero] on a revealed tile that opens into an empty cell when turned
## @returns the turns that do, or 0
func _stand_where_a_turn_opens_into_nothing(hero: Character) -> int:
	var placed_tiles: Dictionary = _level.get("_placed_tiles")
	for cell: Vector2i in placed_tiles.keys():
		var tile: Structure = placed_tiles[cell]
		if tile.profile.resource_path == ModelFreeWorld.WALL_TILE or tile.status != Structure.Status.REVEALED: continue
		hero.place_on_grid(cell, Vector2.ZERO, hero.facing)
		for turns: int in range(1, 4):
			for direction: Level.Direction in RotateTileAbility._get_turned_connections(tile, turns):
				if not _level.get_placed_tile(cell + Level.direction_to_vector(direction)): return turns
	return 0

func test_others_who_crossed_the_tile_forget_their_steps() -> void:
	var mystic: Character = await _spawn_hero(_start_cell())
	var other: Character = await _spawn_hero(_start_cell())
	var direction: Level.Direction = Level.Direction.UP
	for candidate: Level.Direction in Level.Direction.values():
		if _level.is_passage(_start_cell(), candidate): direction = candidate
	# Out and back: the way out reveals tiles, which clears the stack; the way back is kept
	for walker: Character in [mystic, other]:
		_turn_manager.request_move(walker.get_path(), direction)
		_turn_manager.request_move(walker.get_path(), Level.get_opposite(direction))
	assert_int(other.undo_steps).is_greater(0)
	var mystic_steps: int = mystic.undo_steps
	_level.rotate_tile(_level.get_placed_tile(_start_cell()), 1, mystic)
	assert_int(other.undo_steps).is_equal(0)
	assert_int(mystic.undo_steps).is_equal(mystic_steps)
