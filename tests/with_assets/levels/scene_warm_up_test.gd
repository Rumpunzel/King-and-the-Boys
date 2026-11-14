extends GdUnitTestSuite
## The game instances every scene the dungeon may show once behind the loading screen (see
## [code]engine/levels/scene_warm_up.gd[/code]), as a scene's first instance hitches; the warm-up finds them through the level's
## resources

const SceneWarmUp = preload("uid://6aqir8e2vhvx")  # engine/levels/scene_warm_up.gd
const LEVEL: String = "uid://bmwhs3lwb74ue"  # data/levels/level.tscn

func test_the_dungeon_finds_its_props_monsters_and_centrepieces() -> void:
	var level: Level = auto_free((load(LEVEL) as PackedScene).instantiate())
	var paths: Array = SceneWarmUp.find_scenes(level).map(func(scene: PackedScene) -> String: return scene.resource_path)
	assert_array(paths).contains([
		"res://data/structures/props/lights/standing_torch.tscn",
		"res://data/characters/monsters/skeleton/skeleton_01.tscn",
		"res://data/things/centrepieces/sarcophagus_01.tscn",
	])

func test_the_warm_up_instances_every_scene_and_keeps_none() -> void:
	var level: Level = auto_free((load(LEVEL) as PackedScene).instantiate())
	add_child(level)
	var scene_count: int = SceneWarmUp.find_scenes(level).size()
	assert_int(scene_count).is_greater(50)
	var warm_up: SceneWarmUp = SceneWarmUp.new(level)
	while not warm_up.step(): pass
	assert_int(warm_up.count).is_equal(scene_count)
	# Each instance was freed at once: gdUnit counts orphans too
