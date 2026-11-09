extends GdUnitTestSuite

var _model: ModularCharacter

func before_test() -> void:
	_model = auto_free(EquipmentFixtures.make_model())
	add_child(_model)

func _with_none(body_part: ModularBodyPart) -> int:
	return body_part.get_mesh_count() + int(body_part.allows_none())

func _keys(combinations: EquipmentCombinations) -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	for combination: Dictionary in combinations.list(): keys[combination.key as String] = true
	return keys

func test_helmet_combinations_include_none_but_skip_empty_ones() -> void:
	var combinations: EquipmentCombinations = EquipmentCombinations.new(EquipmentFixtures.load_type("helmet"), _model)
	var expected: int = _with_none(_model.head_no_elements) * _with_none(_model.helmet_attachment)
	assert_int(combinations.count()).is_equal(expected)
	var keys: Dictionary[String, bool] = _keys(combinations)
	assert_int(keys.size()).is_equal(expected - 1)
	assert_bool(keys.has("01 00")).is_true()
	assert_bool(keys.has("00 00")).is_false()

func test_unvaried_parts_keep_their_mesh() -> void:
	var combinations: EquipmentCombinations = EquipmentCombinations.new(EquipmentFixtures.load_type("helmet"), _model)
	combinations.varied_parts = [ModularCharacter.Part.HELMET_ATTACHMENT]
	assert_int(combinations.count()).is_equal(_with_none(_model.helmet_attachment))
	combinations.varied_parts = []
	assert_int(combinations.count()).is_equal(1)

func test_gloves_vary_by_lower_arm_and_elbow_pair() -> void:
	var combinations: EquipmentCombinations = EquipmentCombinations.new(EquipmentFixtures.load_type("gloves"), _model)
	var dimensions: Array[Array] = combinations.get_dimensions()
	assert_int(dimensions.size()).is_equal(2)
	assert_int(dimensions[0].size()).is_equal(4)
	assert_int(dimensions[1].size()).is_equal(2)
	var expected: int = _model.arm_lower_left.get_mesh_count() * _with_none(_model.elbow_attach_left)
	assert_int(combinations.count()).is_equal(expected)
	var keys: Dictionary[String, bool] = _keys(combinations)
	# Bare lower arms without elbow pads show no gloves at all
	assert_int(keys.size()).is_equal(expected - 1)
	assert_bool(keys.has("00 00")).is_false()
	assert_bool(keys.has("05 03")).is_true()

func test_group_leaders_reach_numbers_their_partners_lack() -> void:
	var combinations: EquipmentCombinations = EquipmentCombinations.new(EquipmentFixtures.load_type("chest_armor"), _model)
	var expected: int = _model.torso.get_mesh_count() * _with_none(_model.shoulder_attach_left)
	assert_int(combinations.count()).is_equal(expected)
	var keys: Dictionary[String, bool] = _keys(combinations)
	# The bare torso without shoulder pads shows no armour at all
	assert_int(keys.size()).is_equal(expected - 1)
	var last_torso: String = _model.torso.get_mesh_numbers()[-1]
	assert_bool(keys.keys().any(func(combination_key: String) -> bool: return combination_key.begins_with(last_torso))).is_true()

func test_listing_shows_the_original_meshes_afterwards() -> void:
	_model.helmet_attachment.update_index(_model.helmet_attachment.find_mesh_index("02"))
	var before: String = EquipmentFixtures.mesh_path(_model.helmet_attachment)
	EquipmentCombinations.new(EquipmentFixtures.load_type("helmet"), _model).list()
	assert_str(EquipmentFixtures.mesh_path(_model.helmet_attachment)).is_equal(before)

func test_show_key_puts_a_stored_combination_back_on_the_model() -> void:
	var chest: EquipmentCombinations = EquipmentCombinations.new(EquipmentFixtures.load_type("chest_armor"), _model)
	assert_bool(chest.show_key("05 03")).is_true()
	assert_str(chest.get_shown_key()).is_equal("05 03")
	assert_bool(chest.show_key("25-00 13")).is_true()
	assert_str(chest.get_shown_key()).is_equal("25-00 13")
	assert_bool(chest.show_key("05")).is_false()

func test_empty_keys_are_recognized() -> void:
	assert_bool(EquipmentCombinations.is_empty_key("00 00")).is_true()
	assert_bool(EquipmentCombinations.is_empty_key("00-00 00")).is_true()
	assert_bool(EquipmentCombinations.is_empty_key("00 02")).is_false()
