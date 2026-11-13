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
	_level.spawn_monster(load(SKELETON) as CharacterProfile, cell)
	for _frame: int in 3: await await_idle_frame()
	return ((_level.get("_agent_spawner") as AgentSpawner).get_children().back() as Agent).character

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
