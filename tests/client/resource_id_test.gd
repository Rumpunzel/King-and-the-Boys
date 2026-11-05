extends GdUnitTestSuite

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func test_files_are_named_by_uid() -> void:
	var helmet_type: EquipmentType = EquipmentFixtures.load_type("helmet")
	var id: String = ResourceId.of(helmet_type)
	assert_str(id).starts_with("uid://")
	assert_object(ResourceId.find(id)).is_same(helmet_type)
	assert_str(ResourceId.get_file_path(id)).is_equal(helmet_type.resource_path)

func test_resources_inside_files_are_named_and_found() -> void:
	var gloves: EquipmentType = EquipmentFixtures.load_type("gloves")
	var group: EquipmentPartGroup = gloves.part_groups[0]
	var id: String = ResourceId.of(group)
	assert_str(id).contains(ResourceId.SEPARATOR)
	assert_object(ResourceId.find(id)).is_same(group)
	assert_str(ResourceId.get_file_path(id)).is_equal(gloves.resource_path)

func test_runtime_resources_have_no_id() -> void:
	assert_str(ResourceId.of(EquipmentType.new())).is_empty()
	assert_str(ResourceId.of(null)).is_empty()

func test_unknown_ids_find_nothing_without_errors() -> void:
	assert_object(ResourceId.find("")).is_null()
	assert_object(ResourceId.find("uid://doesnotexist")).is_null()
	assert_object(ResourceId.find("res://does/not/exist.tres")).is_null()
	assert_str(ResourceId.get_file_path("uid://doesnotexist")).is_empty()

func test_plain_paths_still_find_their_resource() -> void:
	var helmet_type: EquipmentType = EquipmentFixtures.load_type("helmet")
	assert_object(ResourceId.find(helmet_type.resource_path)).is_same(helmet_type)

func test_only_ids_inside_the_item_directory_are_requestable() -> void:
	var saved: EquipmentProfile = EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE), "cape.tres")
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(saved))).is_true()
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(EquipmentFixtures.load_type("cape")))).is_true()
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(load(EquipmentFixtures.KNIGHT) as Resource))).is_false()
	assert_bool(CharacterEquipment.is_requestable(EquipmentFixtures.SAVED_ITEMS + "/../../characters/people/knight.tres")).is_false()
	assert_bool(CharacterEquipment.is_requestable("uid://doesnotexist")).is_false()
