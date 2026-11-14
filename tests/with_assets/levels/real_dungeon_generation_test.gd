extends GdUnitTestSuite
## The real dungeon tiles (with their connection restrictions: rooms, corridors) keep the generation rules too, see
## [code]tests/fixtures/dungeon_rules.gd[/code]; fewer seeds than the model-free test, as these load models

const DungeonRules = preload("uid://cgmlfyuplqyjq")  # tests/fixtures/dungeon_rules.gd
const LEVEL: String = "uid://bmwhs3lwb74ue"  # data/levels/level.tscn
const SEEDS: int = 4
const EXPLORATION_ROUNDS: int = 1

func test_every_seed_keeps_the_rules() -> void:
	for generation_seed: int in SEEDS:
		var level: Level = (load(LEVEL) as PackedScene).instantiate()
		level.generation_random.seed = generation_seed
		add_child(level)
		level.build_level()
		DungeonRules.explore(level, EXPLORATION_ROUNDS)
		var problems: PackedStringArray = DungeonRules.find_problems(level, generation_seed)
		assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
		remove_child(level)
		level.queue_free()
		await await_idle_frame()
