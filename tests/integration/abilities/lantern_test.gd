extends GdUnitTestSuite
## A light the character turns on and off (the rogue's Lantern) on a generated level (no assets): it starts lit, widens sight,
## lighting it shows what it brings into sight, and toggling is free and stays done, leaving earlier steps undoable

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const LANTERN: ToggleLightAbility = preload("uid://s4o504byc2n0")  # tests/fixtures/lantern.tres

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
	_hero_profile.abilities = [LANTERN]
	add_child(_level)
	# A fixed dungeon, so a step that can be undone is always near
	_level.generation_random.seed = 4
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()

func after_test() -> void:
	_hero_profile.abilities = _original_abilities

## [param dark]: the hero spawns with the lantern out, so what it saw on arrival was without it
func _spawn_hero(dark: bool = false) -> Character:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var hero: Character = auto_free(_hero_profile.create(-1, (spawn_points.front() as Node3D).global_transform))
	hero.level = _level
	if dark: hero.toggled_ability_ids = [ResourceId.of(LANTERN)]
	_level.follow_sight_of(hero)
	add_child(hero)
	await await_idle_frame()
	hero.movement_points = 3
	return hero

func _toggle(hero: Character) -> void:
	_turn_manager.request_ability(hero.get_path(), ResourceId.of(LANTERN), hero.grid_cell, 0)

func _revealed_count() -> int:
	var placed_tiles: Dictionary = _level.get("_placed_tiles")
	return placed_tiles.values().filter(func(tile: Structure) -> bool: return tile.status == Structure.Status.REVEALED).size()

func test_the_lantern_starts_lit_and_widens_sight() -> void:
	var hero: Character = await _spawn_hero()
	assert_bool(LANTERN.is_lit(hero)).is_true()
	assert_array(hero.get_light_sources()).contains_exactly([LANTERN.light_source])
	assert_float(hero.get_vision()).is_equal(_hero_profile.vision + 3.0)
	assert_float(hero.get_dark_vision()).is_equal(_hero_profile.dark_vision + 1.0)

func test_putting_it_out_is_free_and_stays_done() -> void:
	var hero: Character = await _spawn_hero()
	var changes: Array[int] = [0]
	hero.light_sources_changed.connect(func() -> void: changes[0] += 1)
	_toggle(hero)
	assert_bool(LANTERN.is_lit(hero)).is_false()
	assert_array(hero.get_light_sources()).is_empty()
	assert_float(hero.get_vision()).is_equal(_hero_profile.vision)
	assert_int(hero.movement_points).is_equal(3)
	assert_int(hero.undo_steps).is_equal(0)
	_turn_manager.request_undo(hero.get_path())
	assert_bool(LANTERN.is_lit(hero)).is_false()
	assert_int(changes[0]).is_equal(1)

func test_toggling_leaves_the_steps_before_undoable() -> void:
	var hero: Character = await _spawn_hero()
	# Steps that reveal tiles can not be undone: step on until one can
	var before: Vector2i = hero.grid_cell
	for _attempt: int in 3:
		for direction: Level.Direction in Level.Direction.values():
			if hero.undo_steps > 0: break
			if _level.get_step_target(hero.grid_cell, direction) == hero.grid_cell: continue
			before = hero.grid_cell
			_turn_manager.request_move(hero.get_path(), direction)
	assert_int(hero.undo_steps).override_failure_message("No undoable step to test with").is_greater(0)
	var steps: int = hero.undo_steps
	_toggle(hero)
	assert_int(hero.undo_steps).is_equal(steps)
	_turn_manager.request_undo(hero.get_path())
	assert_object(hero.grid_cell).is_equal(before)
	assert_bool(LANTERN.is_lit(hero)).is_false()

func test_lighting_it_shows_what_it_brings_into_sight() -> void:
	var hero: Character = await _spawn_hero(true)
	var revealed_in_the_dark: int = _revealed_count()
	_toggle(hero)
	assert_bool(LANTERN.is_lit(hero)).is_true()
	assert_int(_revealed_count()).is_greater(revealed_in_the_dark)
	# What it showed stays shown: lighting it can not be undone
	assert_int(hero.undo_steps).is_equal(0)

func test_a_light_carried_twice_counts_once() -> void:
	_hero_profile.abilities = [LANTERN, LANTERN]
	var hero: Character = await _spawn_hero()
	assert_array(hero.get_light_sources()).contains_exactly([LANTERN.light_source])
	assert_float(hero.get_vision()).is_equal(_hero_profile.vision + 3.0)
