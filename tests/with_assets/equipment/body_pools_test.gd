extends GdUnitTestSuite
## Body configurations roll parts from their pools, and every hero has one of their own

const HEROES: Array[String] = ["knight", "rogue", "mystic", "soldier", "elf"]

var _model: ModularCharacter

func before_test() -> void:
	_model = auto_free(EquipmentFixtures.make_model())
	add_child(_model)
	_model.facial_hair.gender = ModularBodyPartGendered.Gender.MALE

func _pool_config(pools: Dictionary[String, PackedStringArray]) -> ModelConfigurationRandom:
	var configuration: ModelConfigurationRandom = ModelConfigurationRandom.new()
	configuration.randomized_parts = PackedStringArray(["FACIAL_HAIR", "HAIR"])
	configuration.mesh_pools = pools
	return configuration

func _number(body_part: ModularBodyPart) -> String:
	return ModularBodyPart.get_mesh_number(body_part.mesh.resource_path) if body_part.visible and body_part.mesh else ModularBodyPart.EMPTY_MESH_NUMBER

func test_parts_roll_from_their_pool_only() -> void:
	var configuration: ModelConfigurationRandom = _pool_config({"FACIAL_HAIR": PackedStringArray(["00", "07"]), "HAIR": PackedStringArray(["03"])})
	var rolled: Dictionary[String, bool] = {}
	for roll: int in 60:
		configuration.configure(_model)
		rolled[_number(_model.facial_hair)] = true
		assert_str(_number(_model.hair)).is_equal("03")
	assert_array(rolled.keys()).contains_exactly_in_any_order(["00", "07"])

func test_parts_without_a_pool_roll_from_all() -> void:
	var configuration: ModelConfigurationRandom = _pool_config({"HAIR": PackedStringArray(["03"])})
	var rolled: Dictionary[String, bool] = {}
	for roll: int in 80:
		configuration.configure(_model)
		rolled[_number(_model.facial_hair)] = true
	assert_int(rolled.size()).is_greater(5)

func test_bodies_outside_the_pools_are_refused() -> void:
	var configuration: ModelConfigurationRandom = _pool_config({"FACIAL_HAIR": PackedStringArray(["07"])})
	var body: Dictionary = configuration.roll(_model)
	assert_bool(configuration.allows(_model, body)).is_true()
	body[ModularCharacter.Part.FACIAL_HAIR] = ""
	assert_bool(configuration.allows(_model, body)).override_failure_message("No facial hair is not in the pool").is_false()
	var other: ModelConfigurationRandom = _pool_config({"FACIAL_HAIR": PackedStringArray(["01"])})
	assert_bool(other.allows(_model, configuration.roll(_model))).is_false()

func test_the_server_rolls_anew_for_a_body_outside_the_pools() -> void:
	var knight: CharacterProfile = load(EquipmentFixtures.KNIGHT)
	var chosen: Dictionary = (load("res://data/characters/people/mystic_body.tres") as ModelConfigurationRandom).roll(_model)
	# Mystic beards are none of the knight's
	var data: Dictionary[StringName, Variant] = knight.create_character_data(0, Transform3D.IDENTITY, chosen)
	assert_dict(data[Character.BODY] as Dictionary).is_not_equal(chosen)
	var own: Dictionary = knight.model_configuration.roll(_model)
	assert_dict(knight.create_character_data(0, Transform3D.IDENTITY, own)[Character.BODY] as Dictionary).is_equal(own)

func test_every_hero_has_a_look_of_their_own() -> void:
	var facial_hair: Dictionary[String, PackedStringArray] = {}
	for hero: String in HEROES:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		assert_str(profile.model_configuration.resource_path).is_equal("res://data/characters/people/%s_body.tres" % hero)
		assert_array(profile.model_configuration.call("_get_configuration_warnings") as PackedStringArray).is_empty()
		for part_key: String in profile.model_configuration.mesh_pools:
			var part: ModularBodyPart = _model.get(part_key.to_lower())
			var options: PackedStringArray = profile.model_configuration.get_pool_options(part, part_key)
			assert_int(options.size()).override_failure_message("%s: %s names meshes that do not exist" % [hero, part_key]).is_equal(profile.model_configuration.mesh_pools[part_key].size())
		if profile.model_configuration.mesh_pools.has("FACIAL_HAIR"): facial_hair[hero] = profile.model_configuration.mesh_pools["FACIAL_HAIR"]
	# Beards with facial hair share none of it, apart from clean-shaven
	for hero: String in facial_hair:
		for other: String in facial_hair:
			if hero == other: continue
			for number: String in facial_hair[hero]:
				if number != ModularBodyPart.EMPTY_MESH_NUMBER: assert_array(facial_hair[other]).not_contains([number])
