extends GdUnitTestSuite

func test_starter_types_load_without_warnings() -> void:
	for file_name: String in DirAccess.get_files_at(EquipmentFixtures.TYPES):
		var equipment_type: EquipmentType = load(EquipmentFixtures.TYPES.path_join(file_name))
		assert_object(equipment_type).override_failure_message("%s is no EquipmentType" % file_name).is_not_null()
		assert_array(equipment_type._get_configuration_warnings()).override_failure_message("%s warns" % file_name).is_empty()

func test_hip_attachment_is_its_own_waist_item() -> void:
	assert_array(EquipmentProfile.get_slot_parts(EquipmentProfile.Slot.LEGS)).not_contains([ModularCharacter.Part.HIPS_ATTACHMENT])
	assert_array(EquipmentProfile.get_slot_parts(EquipmentProfile.Slot.WAIST)).contains_exactly([ModularCharacter.Part.HIPS_ATTACHMENT])
	assert_int(EquipmentFixtures.load_type("belt").slot).is_equal(EquipmentProfile.Slot.WAIST)
	assert_array(EquipmentFixtures.load_type("leg_armor").parts).not_contains([ModularCharacter.Part.HIPS_ATTACHMENT])

func test_hoods_carry_helmet_attachments() -> void:
	assert_array(EquipmentFixtures.load_type("hood").parts).contains([ModularCharacter.Part.HELMET_ATTACHMENT])

func test_blocked_slot_parts_are_listed_once() -> void:
	var head_with_face: Array[ModularCharacter.Part] = EquipmentProfile.get_parts_for(EquipmentProfile.Slot.HEAD, [EquipmentProfile.Slot.FACE])
	assert_array(head_with_face).contains([ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR])
	var head_blocking_itself: Array[ModularCharacter.Part] = EquipmentProfile.get_parts_for(EquipmentProfile.Slot.HEAD, [EquipmentProfile.Slot.HEAD])
	assert_int(head_blocking_itself.size()).is_equal(EquipmentProfile.get_slot_parts(EquipmentProfile.Slot.HEAD).size())

func test_gloves_link_arms_with_hands_and_pair_elbows() -> void:
	var links: Array[Array] = EquipmentFixtures.load_type("gloves").get_links()
	assert_int(links.size()).is_equal(2)
	assert_array(links[0]).contains_exactly_in_any_order([ModularCharacter.Part.ARM_LOWER_LEFT, ModularCharacter.Part.ARM_LOWER_RIGHT, ModularCharacter.Part.HAND_LEFT, ModularCharacter.Part.HAND_RIGHT])
	assert_array(links[1]).contains_exactly([ModularCharacter.Part.ELBOW_ATTACH_LEFT, ModularCharacter.Part.ELBOW_ATTACH_RIGHT])

func test_combination_key_has_one_number_per_link() -> void:
	var gloves: EquipmentType = EquipmentFixtures.load_type("gloves")
	var part_numbers: Dictionary = {
		ModularCharacter.Part.ARM_LOWER_LEFT: "05", ModularCharacter.Part.ARM_LOWER_RIGHT: "05",
		ModularCharacter.Part.HAND_LEFT: "05", ModularCharacter.Part.HAND_RIGHT: "07",
		ModularCharacter.Part.ELBOW_ATTACH_LEFT: "03", ModularCharacter.Part.ELBOW_ATTACH_RIGHT: "03",
	}
	assert_str(gloves.get_combination_key(part_numbers)).is_equal("05-07 03")
	assert_str(gloves.get_combination_key({})).is_equal("none none")
	assert_str(gloves.get_combination_name("05 03")).is_equal("Gloves 05 03")

func test_combination_key_survives_renaming_items_and_types() -> void:
	var hat_type: EquipmentType = EquipmentFixtures.load_type("hat").duplicate()
	var hat: EquipmentProfile = EquipmentFixtures.make_item(hat_type, ModularCharacter.Part.HEAD_COVERINGS_BASE_HAIR, EquipmentFixtures.HAT)
	var key: String = hat_type.get_combination_key_of(hat)
	assert_str(key).is_equal("01 none")
	hat.name = "Renamed"
	hat_type.name = "Cap"
	assert_str(hat_type.get_combination_key_of(hat)).is_equal(key)

func test_type_warns_about_foreign_and_doubly_grouped_parts() -> void:
	var equipment_type: EquipmentType = EquipmentFixtures.make_type(EquipmentProfile.Slot.HEAD)
	equipment_type.parts.append(ModularCharacter.Part.TORSO)
	var group: EquipmentPartGroup = EquipmentPartGroup.new()
	group.parts = [ModularCharacter.Part.HELMET_ATTACHMENT, ModularCharacter.Part.HELMET_ATTACHMENT]
	equipment_type.part_groups = [group]
	assert_int(equipment_type._get_configuration_warnings().size()).is_equal(2)

func test_item_takes_slot_and_blocking_from_its_type() -> void:
	var helmet: EquipmentProfile = EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	assert_int(helmet.slot).is_equal(EquipmentProfile.Slot.HEAD)
	assert_array(helmet.blocked_slots).contains_exactly([EquipmentProfile.Slot.FACE])
	assert_str(helmet.get_group_name()).is_equal("Helmet")
	assert_array(helmet._get_configuration_warnings()).is_empty()

func test_item_warns_about_parts_its_type_does_not_use() -> void:
	var wrong: EquipmentProfile = EquipmentFixtures.make_item(EquipmentFixtures.load_type("hat"), ModularCharacter.Part.HEAD_NO_ELEMENTS, EquipmentFixtures.HAT)
	assert_int(wrong._get_configuration_warnings().size()).is_equal(1)
