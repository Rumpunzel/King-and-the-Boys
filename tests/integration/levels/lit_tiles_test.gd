extends GdUnitTestSuite
## Wall lights on a generated level built from model-free tiles: the host rolls each tile's light and sends it with the tile

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const TORCH: TileLight = preload("uid://cvimunviu8yb1")  # tests/fixtures/torch_tile_light.tres
const CANDLES: TileLight = preload("uid://dtgexy6ytp6us")  # tests/fixtures/candle_tile_light.tres
const LIT_DECORATIONS: TileDecorations = preload("uid://y703cko861sr")  # tests/fixtures/lit_decorations.tres
const STRAIGHT: String = "uid://cnebsw1r05wei"  # tests/fixtures/tiles/straight.tres
const CROSSING: String = "uid://0wxtdhri4q23"  # tests/fixtures/tiles/crossing.tres

var _level: Level

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)
	# A fixed dungeon, so the cells the tests look at are the same every run
	_level.generation_random.seed = 4
	_level.build_level()
	await await_idle_frame()

## A copy of the fixture tile [param profile_id] with wall lights to roll
func _lit_profile(profile_id: String) -> StructureProfile:
	var profile: StructureProfile = (load(profile_id) as StructureProfile).duplicate()
	profile.decorations = LIT_DECORATIONS
	return profile

func test_the_roll_is_the_same_for_the_same_seed() -> void:
	var straight: StructureProfile = _lit_profile(STRAIGHT)
	var lit: int = 0
	for x: int in 20:
		var cell: Vector2i = Vector2i(x, 3)
		var light: TileLight = LIT_DECORATIONS.roll_light(straight, _level.generation_random.seed, cell)
		assert_object(LIT_DECORATIONS.roll_light(straight, _level.generation_random.seed, cell)).is_same(light)
		if light:
			assert_object(light).is_same(TORCH)
			lit += 1
	# The chance is a half: some lit, some not
	assert_int(lit).is_between(1, 19)
	# A tile open on every side has no wall to hold a light
	for x: int in 20: assert_object(LIT_DECORATIONS.roll_light(_lit_profile(CROSSING), _level.generation_random.seed, Vector2i(x, 3))).is_null()
	# Another seed lights other tiles
	var other: Array[bool] = []
	var same: Array[bool] = []
	for x: int in 20:
		same.append(LIT_DECORATIONS.roll_light(straight, _level.generation_random.seed, Vector2i(x, 3)) != null)
		other.append(LIT_DECORATIONS.roll_light(straight, _level.generation_random.seed + 1, Vector2i(x, 3)) != null)
	assert_array(other).is_not_equal(same)
	# The fixture tiles hold no wall lights to roll from, so the dungeon is unlit
	for tile: Structure in _level.get_placed_tiles(): assert_object(tile.light).is_null()

func test_the_light_travels_in_the_spawn_data() -> void:
	var tile: Structure = _level.get_placed_tiles().front()
	tile.light = TORCH
	var data: Dictionary[StringName, Variant] = tile.to_structure_data()
	assert_str(data[Structure.LIGHT] as String).is_equal(ResourceId.of(TORCH))
	var copy: Structure = auto_free(Structure.from_structure_data(data))
	assert_object(copy.light).is_same(TORCH)
	tile.light = null
	assert_str(tile.to_structure_data()[Structure.LIGHT] as String).is_empty()

func test_tile_data_without_a_light_loads_unlit() -> void:
	var data: Dictionary[StringName, Variant] = (_level.get_placed_tiles().front() as Structure).to_structure_data()
	# As saved before tiles held lights
	data.erase(Structure.LIGHT)
	var copy: Structure = auto_free(Structure.from_structure_data(data))
	assert_object(copy.light).is_null()

## A hero of [param profile] (the fixture hero by default) on the start
func _spawn_hero(profile: CharacterProfile = null) -> Character:
	var hero_profile: CharacterProfile = profile if profile else ModelFreeWorld.load_hero_profile()
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var hero: Character = auto_free(hero_profile.create(-1, (spawn_points.front() as Node3D).global_transform))
	hero.level = _level
	add_child(hero)
	await await_idle_frame()
	return hero

## A placed cell and a direction from it towards a placed neighbour, through a passage or not as [param passage] asks
func _neighbours(passage: bool) -> Array:
	for tile: Structure in _level.get_placed_tiles():
		var cell: Vector2i = tile.get_grid_position()
		for direction: Level.Direction in Level.Direction.values():
			if not _level.get_placed_tile(cell + Level.direction_to_vector(direction)): continue
			if _level.is_passage(cell, direction) == passage: return [cell, direction]
	return []

func _expect_sight(hero: Character, extra: float) -> void:
	assert_float(hero.get_vision()).is_equal(hero.profile.vision + extra)
	assert_float(hero.get_dark_vision()).is_equal(hero.profile.dark_vision + extra)

func test_standing_on_a_lit_tile_widens_sight() -> void:
	var hero: Character = await _spawn_hero()
	_expect_sight(hero, 0.0)
	_level.get_placed_tile(hero.grid_cell).light = TORCH
	_expect_sight(hero, 1.0)

func test_a_light_next_door_widens_sight_through_a_passage() -> void:
	var hero: Character = await _spawn_hero()
	var through: Array = _neighbours(true)
	var cell: Vector2i = through[0]
	var direction: Level.Direction = through[1]
	hero.place_on_grid(cell, Vector2.ZERO, hero.facing)
	var next_door: Structure = _level.get_placed_tile(cell + Level.direction_to_vector(direction))
	next_door.light = TORCH
	_expect_sight(hero, 1.0)
	next_door.light = null
	# Two cells away the light does not reach
	var beyond: Structure = _level.get_placed_tile(cell + Level.direction_to_vector(direction) * 2)
	if beyond:
		beyond.light = TORCH
		_expect_sight(hero, 0.0)
		beyond.light = null
	# Nor through a wall
	var walled: Array = _neighbours(false)
	assert_array(walled).is_not_empty()
	hero.place_on_grid(walled[0] as Vector2i, Vector2.ZERO, hero.facing)
	_level.get_placed_tile((walled[0] as Vector2i) + Level.direction_to_vector(walled[1] as Level.Direction)).light = TORCH
	_expect_sight(hero, 0.0)

func test_candles_widen_no_sight() -> void:
	var hero: Character = await _spawn_hero()
	_level.get_placed_tile(hero.grid_cell).light = CANDLES
	_expect_sight(hero, 0.0)

func test_two_lights_around_count_once() -> void:
	var hero: Character = await _spawn_hero()
	var lit: int = 0
	for direction: Level.Direction in Level.Direction.values():
		if lit == 2 or not _level.is_passage(hero.grid_cell, direction): continue
		_level.get_placed_tile(hero.grid_cell + Level.direction_to_vector(direction)).light = TORCH
		lit += 1
	assert_int(lit).is_equal(2)
	_expect_sight(hero, 1.0)

func test_a_carried_torch_and_a_wall_torch_count_once() -> void:
	var lamp: ToggleLightAbility = ToggleLightAbility.new()
	lamp.light_source = TORCH.light_source
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.abilities = [lamp]
	var hero: Character = await _spawn_hero(profile)
	_expect_sight(hero, 1.0)
	_level.get_placed_tile(hero.grid_cell).light = TORCH
	_expect_sight(hero, 1.0)
