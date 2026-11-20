extends GdUnitTestSuite
## Who notices whom (see MonsterSenses): a monster notices a hero only from the hero's own sight; a lit hero there whatever way it
## faces, an unlit one only on its tile or straight ahead of it. Lights a companion carries on the tile count; dark vision does not

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const LANTERN: ToggleLightAbility = preload("uid://s4o504byc2n0")  # tests/fixtures/lantern.tres
const TORCH_TILE_LIGHT: String = "uid://cvimunviu8yb1"  # tests/fixtures/torch_tile_light.tres

var _level: Level
var _turn_manager: TurnManager

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	_turn_manager.choice_timeout = 0.0
	add_child(_turn_manager)
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _start_cell() -> Vector2i:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position(spawn_point.global_position)

## A hero of [param profile] (the fixture hero, unlit, unless given)
func _spawn_hero(cell: Vector2i, profile: CharacterProfile = null) -> Character:
	if not profile: profile = ModelFreeWorld.load_hero_profile()
	var hero: Character = auto_free(profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell))))
	_level.add_character(hero)
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

## The fixture hero with a lantern, lit from the start (vision +3)
func _lit_profile() -> CharacterProfile:
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.abilities = [LANTERN]
	return profile

func _spawn_monster(cell: Vector2i) -> Character:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var spawner: AgentSpawner = _level.get("_agent_spawner")
	var agents: Array[Node] = spawner.get_children()
	return (agents[-1] as Agent).character

## The direction of a straight passage of [param steps] steps from the start
func _straight_way(steps: int) -> Level.Direction:
	var start: Vector2i = _start_cell()
	for direction: Level.Direction in Level.Direction.values():
		var cell: Vector2i = start
		for _step: int in steps:
			if not _level.is_passage(cell, direction): break
			cell += Level.direction_to_vector(direction)
		if cell == start + Level.direction_to_vector(direction) * steps: return direction
	assert(false, "No straight passage of %d steps from the start" % steps)
	return Level.Direction.DOWN

## A monster [param steps] steps straight from the start, facing the start or away from it
func _spawn_monster_ahead(steps: int, facing_start: bool) -> Character:
	var way: Level.Direction = _straight_way(steps)
	var cell: Vector2i = _start_cell() + Level.direction_to_vector(way) * steps
	var monster: Character = await _spawn_monster(cell)
	assert_that(monster.grid_cell).is_equal(cell)
	monster.place_on_grid(cell, monster.tile_spot, Level.get_opposite(way) if facing_start else way)
	return monster

## @returns the cells exactly [param steps] steps from [param from] along passages
func _cells_at(from: Vector2i, steps: int) -> Array[Vector2i]:
	var distances: Dictionary[Vector2i, int] = {from: 0}
	var frontier: Array[Vector2i] = [from]
	for distance: int in steps:
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for direction: Level.Direction in Level.Direction.values():
				var neighbour: Vector2i = _level.get_step_target(cell, direction)
				if distances.has(neighbour): continue
				distances[neighbour] = distance + 1
				next_frontier.append(neighbour)
		frontier = next_frontier
	return frontier

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
