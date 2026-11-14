extends GdUnitTestSuite
## The game instances every scene the dungeon may show once behind the loading screen (see
## [code]engine/levels/scene_warm_up.gd[/code]), as a scene's first instance hitches; the warm-up finds them through the level's
## resources

const SceneWarmUp = preload("res://engine/levels/scene_warm_up.gd")
const LEVEL: String = "res://data/levels/level.tscn"

func test_the_dungeon_finds_its_props_monsters_and_centrepieces() -> void:
	var level: Level = auto_free((load(LEVEL) as PackedScene).instantiate())
	var paths: Array = SceneWarmUp.find_scenes(level).map(func(scene: PackedScene) -> String: return scene.resource_path)
	assert_array(paths).contains([
		"res://data/structures/props/lights/standing_torch.tscn",
		"res://data/characters/monsters/skeleton/skeleton_01.tscn",
		"res://data/things/centrepieces/sarcophagus_01.tscn",
	])

func test_the_warm_up_finishes_and_leaves_nothing_behind() -> void:
	var level: Level = auto_free((load(LEVEL) as PackedScene).instantiate())
	add_child(level)
	var child_count: int = level.get_child_count()
	await SceneWarmUp.warm_up(level)
	# Each instance is freed at once: gdUnit counts orphans too
	assert_int(level.get_child_count()).is_equal(child_count)
