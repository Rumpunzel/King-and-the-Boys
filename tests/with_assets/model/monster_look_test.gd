extends GdUnitTestSuite
## A monster's model shows only on a tile this peer has revealed: one spawned on a face-down or unseen tile stays hidden until
## the tile is revealed

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const SKELETON: String = "res://data/characters/monsters/skeleton.tres"

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _spawn_skeleton(cell: Vector2i) -> Character:
	var spawner: AgentSpawner = _level.get("_agent_spawner")
	var created: Array[Agent] = []
	spawner.agent_created.connect(func(agent: Agent) -> void: created.append(agent), CONNECT_ONE_SHOT)
	_level.spawn_monster(load(SKELETON) as CharacterProfile, cell)
	assert_int(created.size()).is_equal(1)
	# Its grid update is applied at the end of the frame
	await await_idle_frame()
	return created[0].character

func test_a_monster_on_a_tile_not_revealed_stays_hidden_until_it_is() -> void:
	for wanted: Structure.Status in [Structure.Status.DISCOVERED, Structure.Status.PLACED]:
		var tile: Structure = null
		for placed: Structure in _level.get_placed_tiles():
			if placed.shown_status == wanted and not placed.get_connections().is_empty() and not _level.get_free_spots(placed.get_grid_position()).is_empty(): tile = placed
		assert_object(tile).override_failure_message("No tile with status %d" % wanted).is_not_null()
		var monster: Character = await _spawn_skeleton(tile.get_grid_position())
		assert_that(monster.grid_cell).is_equal(tile.get_grid_position())
		assert_bool(monster.shown).is_false()
		assert_bool(monster.model.visible).override_failure_message("Shows on a tile of status %d" % wanted).is_false()
		_level.call("_reveal_tile", tile)
		await await_idle_frame()
		assert_bool(monster.model.visible).is_true()

func test_a_monster_on_a_revealed_tile_shows() -> void:
	var start: Vector2i = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var monster: Character = await _spawn_skeleton(start)
	assert_bool(monster.model.visible).is_true()

func test_a_monster_stepping_out_of_sight_finishes_its_hop_then_hides() -> void:
	var start: Vector2i = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var monster: Character = await _spawn_skeleton(start)
	var way: int = -1
	for direction: Level.Direction in Level.Direction.values():
		var next: Structure = _level.get_placed_tile(start + Level.direction_to_vector(direction))
		if _level.is_passage(start, direction) and next.shown_status != Structure.Status.REVEALED: way = direction
	assert_int(way).override_failure_message("No unrevealed tile next to the start").is_not_equal(-1)
	var target: Vector2i = start + Level.direction_to_vector(way as Level.Direction)
	var spot: Vector2 = _level.get_free_spots(target, monster).front()
	monster.place_on_grid(target, spot, way as Level.Direction)
	await await_idle_frame()
	assert_bool(monster.shown).is_false()
	assert_bool(monster.is_figure_moving()).is_true()
	assert_bool(monster.model.visible).override_failure_message("Vanished before its hop").is_true()
	await monster.figure_arrived
	assert_bool(monster.model.visible).override_failure_message("Still shows after its hop").is_false()
