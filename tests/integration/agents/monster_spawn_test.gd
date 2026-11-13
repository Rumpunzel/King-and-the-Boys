extends GdUnitTestSuite
## Monsters are characters driven by an [Agent]: the host spawns them through the level's [AgentSpawner] onto free spots, and a
## save brings them back where they stood

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level
var _start: Vector2i

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	_start = _level.world_to_grid_position(spawn_point.global_position)
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _agent_spawner() -> AgentSpawner:
	return _level.get("_agent_spawner")

func _monsters() -> Array[Character]:
	var monsters: Array[Character] = []
	for node: Node in _agent_spawner().get_children():
		var agent: Agent = node as Agent
		if agent and not agent.is_queued_for_deletion(): monsters.append(agent.character)
	return monsters

func _agent_serializer() -> NodeSerializer:
	for node: Node in get_tree().get_nodes_in_group("SerializersNodes"):
		var serializer: NodeSerializer = node as NodeSerializer
		if serializer and _level.is_ancestor_of(serializer) and serializer.get("_spawner") is AgentSpawner: return serializer
	return null

func test_a_monster_spawns_on_the_cell_it_is_given() -> void:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), _start, Level.Direction.LEFT)
	await await_idle_frame()
	var monsters: Array[Character] = _monsters()
	assert_int(monsters.size()).is_equal(1)
	var monster: Character = monsters.front()
	assert_int(monster.profile.group).is_equal(CharacterProfile.Groups.MONSTERS)
	assert_object(monster.level).is_same(_level)
	assert_bool(monster.is_in_group(Character.GROUP)).is_true()
	assert_that(monster.grid_cell).is_equal(_start)
	assert_int(monster.facing).is_equal(Level.Direction.LEFT)
	assert_int(monster.movement_points).is_equal(monster.profile.speed)

func test_monsters_fill_a_tile_spot_by_spot() -> void:
	var profile: CharacterProfile = ModelFreeWorld.load_monster_profile()
	var spot_count: int = _level.get_free_spots(_start).size()
	for _monster: int in spot_count: _level.spawn_monster(profile, _start)
	await await_idle_frame()
	var spots: Dictionary[Vector2, bool] = {}
	for monster: Character in _monsters():
		assert_that(monster.grid_cell).is_equal(_start)
		spots[monster.tile_spot] = true
	assert_int(spots.size()).is_equal(spot_count)
	assert_array(_level.get_free_spots(_start)).is_empty()

func test_a_restored_monster_stands_where_it_was_saved() -> void:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), _start, Level.Direction.UP)
	await await_idle_frame()
	var old_monster: Character = _monsters().front()
	var saved: Array = [old_monster.profile.resource_path, old_monster.variation, old_monster.grid_cell, old_monster.tile_spot, old_monster.facing]
	var serializer: NodeSerializer = _agent_serializer()
	assert_object(serializer).is_not_null()
	# Through the save file's encoding, as a save and a load would
	var collected: Dictionary[NodeSerializer.SpawnType, Variant] = serializer.collect_spawned_nodes()
	var decoded: Variant = Serializer.decode_data(Serializer.encode_data(collected))
	var loaded: Dictionary[NodeSerializer.SpawnType, Variant] = decoded
	serializer.restore_state(loaded)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(is_instance_valid(old_monster)).is_false()
	var monsters: Array[Character] = _monsters()
	assert_int(monsters.size()).is_equal(1)
	var monster: Character = monsters.front()
	assert_array([monster.profile.resource_path, monster.variation, monster.grid_cell, monster.tile_spot, monster.facing]).is_equal(saved)

func test_no_monster_spawns_where_no_tile_lies() -> void:
	var empty_cell: Vector2i = _start + Vector2i(_level.grid_extents.x * 3, 0)
	assert_object(_level.get_placed_tile(empty_cell)).is_null()
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), empty_cell)
	await await_idle_frame()
	assert_array(_monsters()).is_empty()
