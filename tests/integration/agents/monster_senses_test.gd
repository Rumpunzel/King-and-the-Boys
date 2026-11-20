extends "res://tests/fixtures/monster_test_suite.gd"
## Who notices whom (see MonsterSenses): a monster notices a hero only from the hero's own sight; a lit hero there whatever way it
## faces, an unlit one only on its tile or straight ahead of it. Lights a companion carries on the tile count; dark vision does not

func _notices(monster: Character, hero: Character) -> bool:
	return _turn_manager.get_senses().notices(monster, hero)

func test_a_lit_hero_is_noticed_by_a_monster_facing_away() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	assert_bool(hero.is_lit()).is_true()
	assert_bool(_notices(monster, hero)).is_true()

func test_an_unlit_hero_is_not_noticed_from_beyond_their_sight() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var monster: Character = await _spawn_monster_ahead(2, true)
	assert_bool(hero.is_lit()).is_false()
	# Within its perception and looking at the hero, but the hero can not see it
	assert_bool(_notices(monster, hero)).is_false()

func test_an_unlit_hero_is_noticed_by_a_monster_looking_at_them() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var monster: Character = await _spawn_monster_ahead(1, true)
	assert_bool(_notices(monster, hero)).is_true()
	monster.place_on_grid(monster.grid_cell, monster.tile_spot, Level.get_opposite(monster.facing))
	assert_bool(_notices(monster, hero)).is_false()

func test_an_unlit_hero_is_noticed_on_the_monsters_tile() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	assert_that(monster.grid_cell).is_equal(start)
	for facing: Level.Direction in Level.Direction.values():
		monster.place_on_grid(start, monster.tile_spot, facing)
		assert_bool(_notices(monster, hero)).is_true()

func test_a_hero_in_a_wall_light_is_lit() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	_level.get_placed_tile(hero.grid_cell).light = load(TORCH_TILE_LIGHT)
	var monster: Character = await _spawn_monster_ahead(2, false)
	assert_bool(hero.is_lit()).is_true()
	assert_bool(_notices(monster, hero)).is_true()

func test_a_hero_beside_a_torch_carrier_is_lit() -> void:
	var start: Vector2i = _start_cell()
	var carrier: Character = await _spawn_hero(start, _lit_profile())
	var hero: Character = await _spawn_hero(start)
	assert_bool(hero.is_lit()).is_true()
	assert_float(hero.get_vision()).is_equal(carrier.get_vision())

func test_dark_vision_does_not_make_a_hero_noticeable() -> void:
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.dark_vision = 16.0
	var hero: Character = await _spawn_hero(_start_cell(), profile)
	var monster: Character = await _spawn_monster_ahead(2, false)
	assert_bool(_notices(monster, hero)).is_false()

func test_a_lantern_put_out_stops_a_notice_from_behind() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	assert_bool(_notices(monster, hero)).is_true()
	_turn_manager.request_ability(hero.get_path(), ResourceId.of(LANTERN), hero.grid_cell, 0)
	assert_bool(LANTERN.is_lit(hero)).is_false()
	assert_bool(_notices(monster, hero)).is_false()

func test_a_turned_off_monster_notices_nothing() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_level.monsters_enabled = false
	assert_bool(_notices(monster, hero)).is_false()

func test_the_step_towards_a_cell_follows_passages_beyond_sight() -> void:
	var start: Vector2i = _start_cell()
	var target: Vector2i = _cells_at(start, 5)[0]
	var direction: int = _level.get_step_towards(start, target)
	assert_int(direction).is_not_equal(-1)
	# The step leads one step nearer: four steps from the target
	var next: Vector2i = _level.get_step_target(start, direction as Level.Direction)
	assert_bool(_cells_at(next, 4).has(target)).is_true()
	assert_int(_level.get_step_towards(start, start)).is_equal(-1)

func test_path_lengths_count_steps_along_passages() -> void:
	var start: Vector2i = _start_cell()
	var lengths: Dictionary[Vector2i, int] = _level.get_path_lengths(start, 5)
	assert_int(lengths[start]).is_equal(0)
	for steps: int in range(1, 6):
		for cell: Vector2i in _cells_at(start, steps): assert_int(lengths.get(cell, -1)).is_equal(steps)
	for cell: Vector2i in _cells_at(start, 6): assert_bool(lengths.has(cell)).is_false()
