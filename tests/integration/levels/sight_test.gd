extends GdUnitTestSuite
## Sight on a generated level built from model-free tiles: a character sees the tile it stands on, even without vision

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd

var _level: Level
var _turn_manager: TurnManager

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)
	# A fixed dungeon: an unlucky one can hem the walk in to a handful of cells
	_level.generation_random.seed = 1
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()

func _spawn_hero(profile: CharacterProfile) -> Character:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var hero: Character = auto_free(profile.create(-1, Transform3D(Basis.IDENTITY, spawn_point.global_position)))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

## @returns a direction with a passage out of the hero's cell, towards an unvisited cell where there is one
func _next_direction(hero: Character, visited: Array[Vector2i]) -> Level.Direction:
	var open: Level.Direction = Level.Direction.values().front()
	for direction: Level.Direction in Level.Direction.values():
		var target: Vector2i = _level.get_step_target(hero.grid_cell, direction)
		if target == hero.grid_cell: continue
		if not visited.has(target): return direction
		open = direction
	return open

func test_a_character_without_vision_reveals_the_tile_it_stands_on() -> void:
	# As the knight: no vision beyond its own tile, in rooms and corridors alike
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.vision = 0.0
	var hero: Character = await _spawn_hero(profile)
	var visited: Array[Vector2i] = [hero.grid_cell]
	var unrevealed: Array[Vector2i] = []
	for _step: int in 12:
		hero.movement_points = 8
		_turn_manager.request_move(hero.get_path(), _next_direction(hero, visited))
		await await_idle_frame()
		if not visited.has(hero.grid_cell): visited.append(hero.grid_cell)
		if _level.get_placed_tile(hero.grid_cell).status < Structure.Status.REVEALED: unrevealed.append(hero.grid_cell)
	# It walked on, not only on the start
	assert_int(visited.size()).is_greater(5)
	assert_array(unrevealed).is_empty()
