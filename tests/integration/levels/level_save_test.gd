extends GdUnitTestSuite
## A saved dungeon comes back as it was: the structure spawner's NodeSerializer collects the tiles, and restoring
## removes them and spawns them again from the data (the level's registries follow, see Level._forget_tile)

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const DungeonRules = preload("res://tests/fixtures/dungeon_rules.gd")

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	DungeonRules.explore(_level, 1)

func after_test() -> void:
	await await_idle_frame()

func _structure_serializer() -> NodeSerializer:
	for node: Node in get_tree().get_nodes_in_group("SerializersNodes"):
		var serializer: NodeSerializer = node as NodeSerializer
		if serializer and _level.is_ancestor_of(serializer) and serializer.get("_spawner") is StructureSpawner: return serializer
	return null

## Each cell's tile with its status
func _describe() -> Dictionary[Vector2i, String]:
	var tiles: Dictionary[Vector2i, String] = DungeonRules.describe(_level)
	for cell: Vector2i in tiles: tiles[cell] += " %d" % _level.get_placed_tile(cell).status
	return tiles

func test_a_restored_dungeon_is_the_saved_one() -> void:
	var serializer: NodeSerializer = _structure_serializer()
	assert_object(serializer).is_not_null()
	var saved_tiles: Dictionary[Vector2i, String] = _describe()
	var saved: Dictionary[NodeSerializer.SpawnType, Variant] = serializer.collect_spawned_nodes()
	serializer.restore_state(saved)
	await await_idle_frame()
	await await_idle_frame()
	assert_dict(_describe()).is_equal(saved_tiles)
	# Every tile is a new one, registered once, with its connections
	var problems: PackedStringArray = DungeonRules.find_problems(_level, 42)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	# The removed tiles left nothing behind: one entry per tile with connections, every one of them alive
	var connections: Dictionary = _level.get("_tile_connections")
	var with_connections: int = _level.get_placed_tiles().filter(func(tile: Structure) -> bool: return not tile.get_connections().is_empty()).size()
	assert_int(connections.size()).is_equal(with_connections)
	for tile: Object in connections: assert_bool(is_instance_valid(tile)).is_true()
	var connectors: Dictionary = _level.get("_tile_connectors")
	for connector: Object in connectors.values(): assert_bool(is_instance_valid(connector) and not (connector as Node).is_queued_for_deletion()).is_true()
