extends GdUnitTestSuite
## Tiles the dungeon grows by may hold a monster, rolled by the level's seed and the cell: the same seed places the same
## monsters, none near the start, each on its own spot, and each shows only once its tile is revealed

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const DungeonRules = preload("res://tests/fixtures/dungeon_rules.gd")
const MONSTERS: String = "res://tests/fixtures/monster_spawn_table.tres"
const SEEDS: Array[int] = [1, 7, 42, 1234, 99999]

var _level: Level

func after_test() -> void:
	await _drop_level()

func _build(generation_seed: int) -> void:
	await _drop_level()
	_level = ModelFreeWorld.create_level()
	_level.set(&"_monsters", load(MONSTERS))
	_level.set(&"_monster_chance", 0.5)
	_level.set(&"_room_monster_chance", 0.5)
	_level.generation_random.seed = generation_seed
	add_child(_level)
	_level.build_level()
	DungeonRules.explore(_level, 2)
	await await_idle_frame()

# Only one level at a time: building one looks for the single player spawn point
func _drop_level() -> void:
	if not _level: return
	remove_child(_level)
	_level.free()
	_level = null
	await await_idle_frame()

func _monsters() -> Array[Character]:
	var monsters: Array[Character] = []
	for node: Node in (_level.get("_agent_spawner") as AgentSpawner).get_children():
		var agent: Agent = node as Agent
		if agent: monsters.append(agent.character)
	return monsters

## Each monster by where it stands, with its profile, model variation and facing
func _describe() -> Dictionary[String, String]:
	var described: Dictionary[String, String] = {}
	for monster: Character in _monsters():
		described["%s %s" % [monster.grid_cell, monster.tile_spot]] = "%s %d %d" % [monster.profile.resource_path, monster.variation, monster.facing]
	return described

func _start() -> Vector2i:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position(spawn_point.global_position)

func test_the_same_seed_places_the_same_monsters() -> void:
	var placed_any: bool = false
	for generation_seed: int in SEEDS:
		await _build(generation_seed)
		var first: Dictionary[String, String] = _describe()
		placed_any = placed_any or not first.is_empty()
		await _build(generation_seed)
		assert_dict(_describe()).override_failure_message("Seed %d placed other monsters" % generation_seed).is_equal(first)
	assert_bool(placed_any).is_true()

func test_monsters_keep_away_from_the_start_on_spots_of_their_own() -> void:
	for generation_seed: int in SEEDS:
		await _build(generation_seed)
		var start: Vector2i = _start()
		var monsters: Array[Character] = _monsters()
		for monster: Character in monsters:
			var steps: int = absi(monster.grid_cell.x - start.x) + absi(monster.grid_cell.y - start.y)
			assert_int(steps).override_failure_message("Seed %d: a monster on %s, %d steps from the start" % [generation_seed, monster.grid_cell, steps]).is_greater(1)
		# One per spot: as many places as monsters
		assert_int(_describe().size()).override_failure_message("Seed %d: monsters share a spot" % generation_seed).is_equal(monsters.size())

func test_a_monster_shows_once_its_tile_is_revealed() -> void:
	await _build(42)
	var hidden: Character = null
	for monster: Character in _monsters():
		var tile: Structure = _level.get_placed_tile(monster.grid_cell)
		assert_bool(monster.shown).is_equal(tile.shown_status == Structure.Status.REVEALED)
		if not monster.shown: hidden = monster
	assert_object(hidden).override_failure_message("Seed 42 hides no monster").is_not_null()
	var hidden_tile: Structure = _level.get_placed_tile(hidden.grid_cell)
	# No step revealed it: it shows at once
	_level.call("_reveal_tile", hidden_tile)
	await await_idle_frame()
	assert_bool(hidden.shown).is_true()
