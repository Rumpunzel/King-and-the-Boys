extends GdUnitTestSuite
## A saved dungeon comes back as it was: the structure spawner's NodeSerializer collects the tiles, the data goes
## through the save file's encoding, and restoring removes the tiles and spawns new ones from it (the level's
## registries follow, see Level._forget_tile)

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const DungeonRules = preload("res://tests/fixtures/dungeon_rules.gd")

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	DungeonRules.explore(_level, 1)
	# Reveals show at once (no step caused them); let the frame end
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _structure_serializer() -> NodeSerializer:
	for node: Node in get_tree().get_nodes_in_group("SerializersNodes"):
		var serializer: NodeSerializer = node as NodeSerializer
		if serializer and _level.is_ancestor_of(serializer) and serializer.get("_spawner") is StructureSpawner: return serializer
	return null

## Each cell's tile with its status and how it shows
func _describe() -> Dictionary[Vector2i, String]:
	var tiles: Dictionary[Vector2i, String] = DungeonRules.describe(_level)
	for cell: Vector2i in tiles:
		var tile: Structure = _level.get_placed_tile(cell)
		tiles[cell] += " %d %d" % [tile.status, tile.shown_status]
	return tiles

func test_a_restored_dungeon_is_the_saved_one() -> void:
	var serializer: NodeSerializer = _structure_serializer()
	assert_object(serializer).is_not_null()
	var saved_tiles: Dictionary[Vector2i, String] = _describe()
	var old_tiles: Array[Structure] = _level.get_placed_tiles()
	# Through the save file's encoding, as a save and a load would
	var collected: Dictionary[NodeSerializer.SpawnType, Variant] = serializer.collect_spawned_nodes()
	var decoded: Variant = Serializer.decode_data(Serializer.encode_data(collected))
	assert_bool(decoded is Dictionary[NodeSerializer.SpawnType, Variant]).override_failure_message("Decoded as %s" % type_string(typeof(decoded))).is_true()
	var loaded: Dictionary[NodeSerializer.SpawnType, Variant] = decoded
	serializer.restore_state(loaded)
	await await_idle_frame()
	await await_idle_frame()
	assert_dict(_describe()).is_equal(saved_tiles)
	# Every tile is a new one: the old ones are gone
	for old_tile: Structure in old_tiles: assert_bool(is_instance_valid(old_tile)).is_false()
	for tile: Structure in _level.get_placed_tiles(): assert_bool(old_tiles.has(tile)).is_false()
	var problems: PackedStringArray = DungeonRules.find_problems(_level, 42)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	# The removed tiles left no bridges behind
	var bridges: Dictionary = _level.get("_bridges")
	for bridge: Object in bridges.values(): assert_bool(is_instance_valid(bridge) and not (bridge as Node).is_queued_for_deletion()).is_true()
