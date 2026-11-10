extends GdUnitTestSuite
## Abilities in turns on a generated level (no assets): limits, costs, undo, held abilities, turn-end effects

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const TestAbility = preload("res://tests/fixtures/test_ability.gd")
const TEST_ABILITY: Ability = preload("res://tests/fixtures/test_ability.tres")
const HELD_ABILITY: Ability = preload("res://tests/fixtures/held_test_ability.tres")
const LATER_ABILITY: Ability = preload("res://tests/fixtures/later_test_ability.tres")
const CHARGED_ABILITY: Ability = preload("res://tests/fixtures/charged_ability.tres")

var _level: Level
var _turn_manager: TurnManager
var _hero_profile: CharacterProfile
var _original_abilities: Array[Ability]
var _hero: Character

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_hero_profile = ModelFreeWorld.load_hero_profile()
	# The profile is cached: restored after each test
	_original_abilities = _hero_profile.abilities
	_hero_profile.abilities = [TEST_ABILITY, HELD_ABILITY, LATER_ABILITY, CHARGED_ABILITY]
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()
	_hero = await _spawn_hero()

func after_test() -> void:
	_hero_profile.abilities = _original_abilities

func _spawn_hero() -> Character:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var start_cell: Vector2i = _level.world_to_grid_position((spawn_points.front() as Node3D).global_position)
	var hero: Character = auto_free(_hero_profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(start_cell))))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

func _use(ability: Ability, argument: int = 0) -> void:
	_turn_manager.request_ability(_hero.get_path(), ResourceId.of(ability), _hero.grid_cell, argument)

func _begin(ability: Ability = HELD_ABILITY) -> void:
	_turn_manager.request_ability_begin(_hero.get_path(), ResourceId.of(ability), _hero.grid_cell)

func _effects() -> int:
	return _hero.get_meta(TestAbility.EFFECTS, 0)

func _open_direction(cell: Vector2i) -> int:
	for direction: Level.Direction in Level.Direction.values():
		if _level.get_step_target(cell, direction) != cell: return direction
	return -1

func test_a_use_costs_its_points_and_undo_refunds_them() -> void:
	var points: int = _hero.movement_points
	_use(TEST_ABILITY)
	assert_int(_effects()).is_equal(1)
	assert_int(_hero.movement_points).is_equal(points - 1)
	assert_int(_hero.undo_steps).is_equal(1)
	_turn_manager.request_undo(_hero.get_path())
	assert_int(_effects()).is_equal(0)
	assert_int(_hero.movement_points).is_equal(points)
	assert_int(_hero.undo_steps).is_equal(0)

func test_only_listed_abilities_are_used() -> void:
	_turn_manager.request_ability(_hero.get_path(), "res://tests/fixtures/hero.tres", _hero.grid_cell, 0)
	_turn_manager.request_ability(_hero.get_path(), "", _hero.grid_cell, 0)
	_hero_profile.abilities = [HELD_ABILITY]
	_use(TEST_ABILITY)
	assert_int(_effects()).is_equal(0)
	assert_int(_hero.undo_steps).is_equal(0)

func test_the_ability_decides_its_targets_and_arguments() -> void:
	_turn_manager.request_ability(_hero.get_path(), ResourceId.of(TEST_ABILITY), _hero.grid_cell + Vector2i.RIGHT, 0)
	_use(TEST_ABILITY, -1)
	assert_int(_effects()).is_equal(0)

func test_a_use_needs_the_points_it_costs() -> void:
	_hero.movement_points = 0
	_use(TEST_ABILITY)
	assert_int(_effects()).is_equal(0)

func test_uses_per_turn_are_limited_until_the_next_turn() -> void:
	_hero.movement_points = 8
	for _use_number: int in 3: _use(TEST_ABILITY)
	assert_int(_effects()).is_equal(2)
	_turn_manager.request_undo(_hero.get_path())
	_use(TEST_ABILITY)
	assert_int(_effects()).is_equal(2)
	_turn_manager._start_next_turn()
	_use(TEST_ABILITY)
	assert_int(_effects()).is_equal(3)

func test_charges_last_the_game_and_undo_refunds_them() -> void:
	for _turn: int in 2:
		_use(CHARGED_ABILITY)
		_use(CHARGED_ABILITY)
		_turn_manager._start_next_turn()
	assert_int(_hero.get_charges_left(CHARGED_ABILITY)).is_equal(0)
	_hero.movement_points = 8
	_use(TEST_ABILITY)
	_use(CHARGED_ABILITY)
	assert_int(_hero.undo_steps).is_equal(1)
	_hero.ability_uses = {ResourceId.of(CHARGED_ABILITY): 2}
	_use(CHARGED_ABILITY)
	assert_int(_hero.get_charges_left(CHARGED_ABILITY)).is_equal(0)
	_turn_manager.request_undo(_hero.get_path())
	assert_int(_hero.get_charges_left(CHARGED_ABILITY)).is_equal(1)

func test_passed_players_use_no_abilities() -> void:
	_turn_manager._set_passed(multiplayer.get_unique_id(), true)
	_use(TEST_ABILITY)
	_begin()
	assert_int(_effects()).is_equal(0)
	assert_str(_hero.active_ability_id).is_empty()

func test_undo_takes_back_steps_and_uses_newest_first() -> void:
	var start: Vector2i = _hero.grid_cell
	_hero.movement_points = 8
	var direction: int = _open_direction(start)
	assert_int(direction).is_not_negative()
	# The first step reveals tiles, which clears the stack; the way back changes nothing
	_turn_manager.request_move(_hero.get_path(), direction as Level.Direction)
	var moved_to: Vector2i = _hero.grid_cell
	_turn_manager.request_move(_hero.get_path(), Level.get_direction(moved_to, start))
	assert_vector(_hero.grid_cell).is_equal(start)
	var steps_before: int = _hero.undo_steps
	_use(TEST_ABILITY)
	assert_int(_hero.undo_steps).is_equal(steps_before + 1)
	_turn_manager.request_undo(_hero.get_path())
	assert_int(_effects()).is_equal(0)
	assert_vector(_hero.grid_cell).is_equal(start)
	_turn_manager.request_undo(_hero.get_path())
	assert_vector(_hero.grid_cell).is_equal(moved_to)

func test_a_held_ability_is_begun_adjusted_and_confirmed() -> void:
	var points: int = _hero.movement_points
	_use(HELD_ABILITY)
	assert_int(_effects()).is_equal(0)
	_begin()
	assert_bool(_hero.get_meta(TestAbility.BEGUN, false) as bool).is_true()
	assert_object(_hero.get_active_ability()).is_same(HELD_ABILITY)
	_turn_manager.request_ability_adjust(_hero.get_path(), 3)
	assert_int(_hero.get_meta(TestAbility.ARGUMENT, 0) as int).is_equal(3)
	assert_int(_hero.movement_points).is_equal(points)
	_use(HELD_ABILITY, 3)
	assert_int(_effects()).is_equal(1)
	assert_int(_hero.movement_points).is_equal(points - 1)
	assert_str(_hero.active_ability_id).is_empty()

func test_a_held_ability_blocks_steps_undo_and_other_abilities() -> void:
	_hero.movement_points = 8
	_use(TEST_ABILITY)
	_begin()
	var cell: Vector2i = _hero.grid_cell
	var direction: int = _open_direction(cell)
	_turn_manager.request_move(_hero.get_path(), direction as Level.Direction)
	_turn_manager.request_undo(_hero.get_path())
	_use(TEST_ABILITY)
	_begin(HELD_ABILITY)
	assert_vector(_hero.grid_cell).is_equal(cell)
	assert_int(_effects()).is_equal(1)
	assert_int(_hero.undo_steps).is_equal(1)
	assert_int(_hero.get_meta(TestAbility.CANCELLED, 0) as int).is_equal(0)

func test_adjusting_needs_the_points_the_choice_costs() -> void:
	_begin()
	_hero.movement_points = 0
	_turn_manager.request_ability_adjust(_hero.get_path(), 2)
	assert_bool(_hero.has_meta(TestAbility.ARGUMENT)).is_false()

func test_a_held_ability_that_can_not_be_used_is_cancelled() -> void:
	_begin()
	_use(HELD_ABILITY, -1)
	assert_int(_hero.get_meta(TestAbility.CANCELLED, 0) as int).is_equal(1)
	assert_str(_hero.active_ability_id).is_empty()
	assert_int(_effects()).is_equal(0)

func test_cancel_pass_and_turn_end_cancel_a_held_ability() -> void:
	_begin()
	_turn_manager.request_ability_cancel(_hero.get_path())
	assert_str(_hero.active_ability_id).is_empty()
	_begin()
	_turn_manager.request_pass(true)
	assert_str(_hero.active_ability_id).is_empty()
	_begin()
	_turn_manager._start_next_turn()
	assert_str(_hero.active_ability_id).is_empty()
	assert_int(_hero.get_meta(TestAbility.CANCELLED, 0) as int).is_equal(3)
	assert_int(_effects()).is_equal(0)

func test_turn_end_effects_resolve_when_the_turn_ends() -> void:
	_use(LATER_ABILITY)
	assert_int(_effects()).is_equal(0)
	_turn_manager._start_next_turn()
	assert_int(_effects()).is_equal(1)
	_turn_manager._start_next_turn()
	assert_int(_effects()).is_equal(1)

func test_an_undone_turn_end_effect_never_resolves() -> void:
	_use(LATER_ABILITY)
	_turn_manager.request_undo(_hero.get_path())
	_turn_manager._start_next_turn()
	assert_int(_effects()).is_equal(0)
