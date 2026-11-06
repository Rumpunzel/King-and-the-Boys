extends GdUnitTestSuite

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func _save_items() -> Array[EquipmentLook]:
	var helmet_type: EquipmentType = EquipmentFixtures.load_type("helmet")
	var hood_type: EquipmentType = EquipmentFixtures.load_type("hood")
	var helmet: EquipmentLook = EquipmentFixtures.make_item(helmet_type, ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	helmet.name = "Zz Helmet"
	var hood: EquipmentLook = EquipmentFixtures.make_item(hood_type, ModularCharacter.Part.HEAD_COVERINGS_NO_HAIR, EquipmentFixtures.HOOD)
	var cape: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE)
	return [EquipmentFixtures.save_item(helmet, "helmet.tres"), EquipmentFixtures.save_item(hood, "hood.tres"), EquipmentFixtures.save_item(cape, "cape.tres")]

func test_pickers_only_list_items_of_their_slot() -> void:
	var saved: Array[EquipmentLook] = _save_items()
	var head_items: Array[EquipmentLook] = EquipmentSlotProperty.find_items(EquipmentFixtures.SAVED_ITEMS, EquipmentLook.Slot.HEAD)
	assert_array(head_items).contains_exactly_in_any_order([saved[0], saved[1]])
	assert_array(EquipmentSlotProperty.find_items(EquipmentFixtures.SAVED_ITEMS, EquipmentLook.Slot.BACK)).contains_exactly([saved[2]])

func test_items_are_grouped_by_type_name() -> void:
	_save_items()
	var head_items: Array[EquipmentLook] = EquipmentSlotProperty.find_items(EquipmentFixtures.SAVED_ITEMS, EquipmentLook.Slot.HEAD)
	var type_names: PackedStringArray = []
	for item: EquipmentLook in head_items: type_names.append(item.type.name)
	var sorted_names: PackedStringArray = type_names.duplicate()
	sorted_names.sort()
	assert_array(type_names).contains(["Helmet", "Hood"])
	assert_array(type_names).is_equal(sorted_names)

func test_items_are_grouped_by_the_mesh_of_their_types_first_part() -> void:
	var helmet: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	assert_str(EquipmentSlotProperty.get_base(helmet)).is_equal("No Head No Elements")
	var hood: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("hood"), ModularCharacter.Part.HEAD_COVERINGS_NO_HAIR, EquipmentFixtures.HOOD)
	assert_str(EquipmentSlotProperty.get_base(hood)).is_equal("Head Coverings No Hair 01")

func test_filter_matches_name_type_and_base_ignoring_case() -> void:
	var hood: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("hood"), ModularCharacter.Part.HEAD_COVERINGS_NO_HAIR, EquipmentFixtures.HOOD)
	hood.name = "Green Cowl"
	assert_bool(EquipmentSlotProperty.matches(hood, "")).is_true()
	assert_bool(EquipmentSlotProperty.matches(hood, " cowl ")).is_true()
	assert_bool(EquipmentSlotProperty.matches(hood, "HOOD")).is_true()
	assert_bool(EquipmentSlotProperty.matches(hood, "no hair 01")).is_true()
	assert_bool(EquipmentSlotProperty.matches(hood, "helmet")).is_false()
