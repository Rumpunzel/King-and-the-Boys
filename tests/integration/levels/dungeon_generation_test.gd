extends GdUnitTestSuite
## The generated dungeon over many seeds keeps its rules (see [code]tests/fixtures/dungeon_rules.gd[/code]), and a
## seed builds the same dungeon again. Every failure names its seed, so it can be built again. The model-free tiles
## have no connection restrictions; the real ones are checked in [code]tests/with_assets/levels/[/code].

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const DungeonRules = preload("res://tests/fixtures/dungeon_rules.gd")
const SEEDS: int = 10
const EXPLORATION_ROUNDS: int = 1

## A level built from [param generation_seed] and explored
func _build(generation_seed: int) -> Level:
	var level: Level = auto_free(ModelFreeWorld.create_level())
	level.generation_random.seed = generation_seed
	add_child(level)
	level.build_level()
	DungeonRules.explore(level, EXPLORATION_ROUNDS)
	return level

func _remove(level: Level) -> void:
	remove_child(level)
	level.queue_free()
	await await_idle_frame()

## Built once per seed: building and exploring is what takes the time
func test_every_seed_keeps_the_rules() -> void:
	for generation_seed: int in SEEDS:
		var level: Level = _build(generation_seed)
		var problems: PackedStringArray = DungeonRules.find_problems(level, generation_seed)
		assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
		await _remove(level)

func test_a_seed_builds_the_same_dungeon_again() -> void:
	for generation_seed: int in [7, 98765]:
		var first: Level = _build(generation_seed)
		var first_tiles: Dictionary[Vector2i, String] = DungeonRules.describe(first)
		await _remove(first)
		var second: Level = _build(generation_seed)
		assert_dict(DungeonRules.describe(second)).override_failure_message("Seed %d built another dungeon the second time" % generation_seed).is_equal(first_tiles)
		await _remove(second)

func test_other_seeds_build_other_dungeons() -> void:
	var first: Level = _build(1)
	var first_tiles: Dictionary[Vector2i, String] = DungeonRules.describe(first)
	await _remove(first)
	var second: Level = _build(2)
	assert_dict(DungeonRules.describe(second)).is_not_equal(first_tiles)
	await _remove(second)
