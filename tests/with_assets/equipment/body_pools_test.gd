extends GdUnitTestSuite
## Body configurations roll parts from their pools, and every hero has one of their own

const HEROES: Array[String] = ["knight", "rogue", "mystic", "soldier", "elf"]
const KNIGHT_BODY: String = "uid://5hbsrnqf3fcd"  # data/characters/people/knight_body.tres
const ELF: String = "uid://4knh77xf2vfl"  # data/characters/people/elf.tres

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
	# By mesh, not visibility: gear may hide a part (a helmet the beard) that still has its mesh
	return ModularBodyPart.get_mesh_number(body_part.mesh.resource_path) if body_part.mesh else ModularBodyPart.EMPTY_MESH_NUMBER

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
	var chosen: Dictionary = (load("uid://bxrtwssk6b5uw") as ModelConfigurationRandom).roll(_model)  # data/characters/people/mystic_body.tres
	# Mystic beards are none of the knight's
	var data: Dictionary[StringName, Variant] = knight.create_character_data(0, Transform3D.IDENTITY, chosen)
	assert_dict(data[Character.BODY] as Dictionary).is_not_equal(chosen)
	var own: Dictionary = knight.model_configuration.roll(_model)
	assert_dict(knight.create_character_data(0, Transform3D.IDENTITY, own)[Character.BODY] as Dictionary).is_equal(own)

func test_every_hero_has_a_look_of_their_own() -> void:
	for hero: String in HEROES:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		assert_str(profile.model_configuration.resource_path).is_equal("res://data/characters/people/%s_body.tres" % hero)
		# Pools are of the meshes of the hero's gender
		_model.set_gender(profile.model_configuration.gender)
		for part_key: String in profile.model_configuration.mesh_pools:
			var part: ModularBodyPart = _model.get(part_key.to_lower())
			var options: PackedStringArray = profile.model_configuration.get_pool_options(part, part_key)
			assert_int(options.size()).override_failure_message("%s: %s names meshes that do not exist" % [hero, part_key]).is_equal(profile.model_configuration.mesh_pools[part_key].size())


func test_switching_meshes_off_and_on_again_drops_the_pool() -> void:
	var configuration: ModelConfigurationRandom = _pool_config({})
	var all_numbers: PackedStringArray = PackedStringArray(["00", "01", "02", "03"])
	assert_bool(configuration.is_in_pool("HAIR", "02")).override_failure_message("Without a pool every mesh is in").is_true()
	configuration.mesh_pools = configuration.with_pool_number("HAIR", "02", false, all_numbers)
	assert_array(configuration.mesh_pools["HAIR"]).contains_exactly(["00", "01", "03"])
	assert_bool(configuration.is_in_pool("HAIR", "02")).is_false()
	configuration.mesh_pools = configuration.with_pool_number("HAIR", "02", true, all_numbers)
	assert_bool(configuration.mesh_pools.has("HAIR")).is_false()
	configuration.mesh_pools = configuration.with_pool("HAIR", PackedStringArray(), all_numbers)
	assert_array(configuration.mesh_pools["HAIR"]).is_empty()
	configuration.mesh_pools = configuration.with_pool("HAIR", all_numbers, all_numbers)
	assert_bool(configuration.mesh_pools.has("HAIR")).is_false()

func test_the_editor_lists_each_body_part_of_the_configured_body() -> void:
	var bodies: Array[PackedScene] = BodyPoolsProperty.find_bodies()
	var knight_body: ModelConfigurationRandom = load(KNIGHT_BODY)
	var human: PackedScene = bodies[BodyPoolsProperty.guess_body(knight_body, bodies)]
	assert_object(human).is_same(load(EquipmentFixtures.MODULAR_CHARACTER))
	var random_dwarf: ModelConfigurationRandom = load("uid://d4l2t2lakts58")  # data/characters/dwarves/random_dwarf.tres
	var dwarf: PackedScene = bodies[BodyPoolsProperty.guess_body(random_dwarf, bodies)]
	assert_object(dwarf).is_same(load(EquipmentFixtures.DWARF_CHARACTER))
	var model_parts: ModularModelParts = ModularModelParts.of(human)
	var part_keys: Array = model_parts.get_body_parts().map(func(part: int) -> String: return model_parts.get_part_key(part))
	assert_array(part_keys).contains(["HEAD", "EYEBROW", "FACIAL_HAIR", "HAIR", "EARS"])
	assert_array(model_parts.get_mesh_numbers(ModularCharacter.Part.FACIAL_HAIR).slice(0, 2)).contains_exactly(["00", "01"])

func test_a_body_describes_what_its_parts_show() -> void:
	_model.reset()
	_model.hair.update_index(_model.hair.find_mesh_index("12"))
	var described: String = _model.describe_body()
	assert_str(described).contains("Hair 12")
	assert_str(described).contains("Facial Hair none")
	assert_int(described.split(" · ").size()).is_equal(_model.get_body_parts().size())

func test_the_preview_steps_through_a_part_s_pool_and_keeps_the_choice() -> void:
	var knight: CharacterProfile = load(EquipmentFixtures.KNIGHT)
	var model: ModularCharacter = auto_free(knight.create_model(0) as ModularCharacter)
	add_child(model)
	knight.setup_model(model)
	var options: PackedStringArray = knight.get_body_options(model, ModularCharacter.Part.FACIAL_HAIR)
	assert_array(options).contains_exactly(knight.model_configuration.mesh_pools["FACIAL_HAIR"])
	knight.set_preview_body_part(model, ModularCharacter.Part.FACIAL_HAIR, options[1])
	assert_str(_number(model.facial_hair)).is_equal(options[1])
	# A rebuilt preview keeps it
	var rebuilt: ModularCharacter = auto_free(knight.create_model(0) as ModularCharacter)
	add_child(rebuilt)
	knight.setup_model(rebuilt)
	assert_str(_number(rebuilt.facial_hair)).is_equal(options[1])
	# Parts that are not randomized offer all their meshes
	assert_int(knight.get_body_options(model, ModularCharacter.Part.EARS).size()).is_equal(model.ears.get_mesh_count() + (1 if model.ears.allows_none() else 0))

func test_a_body_without_facial_hair_meshes_keeps_to_any_pool() -> void:
	# A female body has no facial hair, so the knight's pool (without "00") rolls none for it
	var knight_body: ModelConfigurationRandom = (load(KNIGHT_BODY) as ModelConfigurationRandom).duplicate()
	knight_body.gender = ModularBodyPartGendered.Gender.FEMALE
	assert_bool(knight_body.mesh_pools["FACIAL_HAIR"].has(ModularBodyPart.EMPTY_MESH_NUMBER)).is_false()
	var body: Dictionary = knight_body.roll(_model)
	assert_str(body[ModularCharacter.Part.FACIAL_HAIR] as String).is_empty()
	assert_bool(knight_body.allows(_model, body)).is_true()

func test_a_body_turns_female_and_back_keeping_its_mesh_numbers() -> void:
	_model.eyebrow.update_index(_model.eyebrow.find_mesh_index("05"))
	_model.facial_hair.update_index(_model.facial_hair.find_mesh_index("03"))
	_model.set_gender(ModularBodyPartGendered.Gender.FEMALE)
	assert_str(_model.torso.mesh.resource_path).contains("/female/")
	assert_str(_model.eyebrow.mesh.resource_path).contains("/female/")
	assert_str(_number(_model.eyebrow)).is_equal("05")
	assert_object(_model.facial_hair.mesh).override_failure_message("Female bodies have no facial hair").is_null()
	# A number the other gender lacks falls back to the first mesh
	_model.set_gender(ModularBodyPartGendered.Gender.MALE)
	_model.eyebrow.update_index(_model.eyebrow.find_mesh_index("09"))
	_model.set_gender(ModularBodyPartGendered.Gender.FEMALE)
	assert_str(_number(_model.eyebrow)).is_equal("01")
	_model.set_gender(ModularBodyPartGendered.Gender.MALE)
	assert_str(_model.torso.mesh.resource_path).contains("/male/")
	assert_str(_model.torso.mesh.resource_path).not_contains("/female/")

func test_a_body_turning_female_keeps_what_its_helmet_hides_hidden() -> void:
	_model.head_no_elements.update_index(0)
	assert_bool(_model.eyebrow.visible).is_false()
	_model.set_gender(ModularBodyPartGendered.Gender.FEMALE)
	assert_str(_model.eyebrow.mesh.resource_path).contains("/female/")
	assert_bool(_model.eyebrow.visible).is_false()
	assert_bool(_model.head.visible).is_false()
	assert_bool(_model.head_no_elements.visible).is_true()
	_model.set_gender(ModularBodyPartGendered.Gender.MALE)

func test_a_preview_rolls_anew_once_its_body_no_longer_fits() -> void:
	var elf: CharacterProfile = load(ELF)
	var model: ModularCharacter = auto_free(elf.create_model(0))
	add_child(model)
	elf.setup_model(model)
	# E.g. the gender changed in Menagerie: the next model is male, the cached body female
	model.set_gender(ModularBodyPartGendered.Gender.MALE)
	assert_bool(model.is_complete_body(elf._preview_body)).is_false()
	elf.setup_model(model)
	assert_bool(model.is_complete_body(elf._preview_body)).is_true()
	elf._preview_body = {}

func test_the_elf_is_female_wherever_her_body_is_built() -> void:
	var elf: CharacterProfile = load(ELF)
	assert_int(elf.model_configuration.gender).is_equal(ModularBodyPartGendered.Gender.FEMALE)
	var model: ModularCharacter = auto_free(elf.create_model(0))
	add_child(model)
	assert_int(model.torso.gender).is_equal(ModularBodyPartGendered.Gender.FEMALE)
	# The body a player rolls in the lobby names female meshes, and the server takes it
	var body: Dictionary = elf.roll_body(0)
	assert_str(ResourceId.get_file_path(body[ModularCharacter.Part.EYEBROW] as String)).contains("/female/")
	assert_dict(elf.create_character_data(0, Transform3D.IDENTITY, body)[Character.BODY] as Dictionary).is_equal(body)
	# Dressed, her gear shows its female meshes
	elf.dress_model(model, body)
	assert_str(model.torso.mesh.resource_path).contains("/female/")
	# The pools' editor lists the female meshes
	var scene: PackedScene = load("uid://c6oheyitbnlpu")  # data/characters/people/modular_character.tscn
	assert_array(ModularModelParts.of(scene, ModularBodyPartGendered.Gender.FEMALE).get_mesh_numbers(ModularCharacter.Part.EYEBROW)).has_size(7)
	assert_array(ModularModelParts.of(scene).get_mesh_numbers(ModularCharacter.Part.EYEBROW)).has_size(10)
