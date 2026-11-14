extends GdUnitTestSuite
## A thing shows the model variation it was created with: the host rolls it once (see ThingSpawner.spawn_at) and every peer
## creates the thing from the same spawn data, so all show the same model

## Four model variations
const FISH: String = "uid://buicitfb4e20w"  # data/things/fish/fish.tres

func test_a_thing_keeps_the_variation_it_was_created_with() -> void:
	var fish: ThingProfile = load(FISH)
	assert_int(fish.get_variation_count()).is_greater(1)
	for variation: int in fish.get_variation_count():
		var thing: Thing = auto_free(fish.create(variation, Transform3D.IDENTITY, Thing.Status.REVEALED))
		add_child(thing)
		assert_int(thing.variation).is_equal(variation)
		assert_int(thing.to_thing_data()[Thing.VARIATION]).is_equal(variation)
		var variations: Array = fish.get("_model_variations")
		assert_str(thing.model.scene_file_path).is_equal((variations[variation] as PackedScene).resource_path)

func test_a_thing_without_a_variation_rolls_one() -> void:
	var fish: ThingProfile = load(FISH)
	var thing: Thing = auto_free(fish.create(-1, Transform3D.IDENTITY, Thing.Status.REVEALED))
	add_child(thing)
	assert_int(thing.variation).is_between(0, fish.get_variation_count() - 1)
