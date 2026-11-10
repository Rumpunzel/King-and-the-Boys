extends GdUnitTestSuite
## The starting equipment fields' helpers; the EditorProperty itself cannot be made headless

var _knight: CharacterProfile
var _original_starting_equipment: Dictionary

func before_test() -> void:
	_knight = load(EquipmentFixtures.KNIGHT)
	_original_starting_equipment = EquipmentFixtures.clear_starting_equipment(_knight)

func after_test() -> void:
	EquipmentFixtures.restore_starting_equipment(_knight, _original_starting_equipment)

func _chest() -> EquipmentLook:
	return EquipmentSlotProperty.get_first_look(EquipmentFixtures.load_type("chest_armor"))

func _parts(carousels: Array[Array]) -> Array:
	return carousels.map(func(parts: Array) -> String: return ", ".join(parts.map(func(part: int) -> String: return ModularCharacter.Part.keys()[part])))

func _type_names(slot: EquipmentLook.Slot, profile: CharacterProfile) -> Array:
	return EquipmentSlotProperty.get_slot_types(slot, profile).map(func(equipment_type: EquipmentType) -> String: return equipment_type.name)

func test_slots_offer_only_their_types() -> void:
	assert_array(_type_names(EquipmentLook.Slot.HEAD, _knight)).contains_exactly_in_any_order(["Helmet", "Hood", "Hat"])
	assert_array(_type_names(EquipmentLook.Slot.MAIN_HAND, _knight)).contains_exactly_in_any_order(["Weapon", "Two-Handed Weapon"])
	assert_array(_type_names(EquipmentLook.Slot.OFF_HAND, _knight)).contains_exactly(["Shield"])

func test_dwarves_are_offered_dwarf_gear_only() -> void:
	var dwarf: CharacterProfile = load(EquipmentFixtures.DWARF)
	assert_array(_type_names(EquipmentLook.Slot.HEAD, dwarf)).contains_exactly(["Dwarf Headwear"])
	assert_array(_type_names(EquipmentLook.Slot.TORSO, dwarf)).contains_exactly(["Dwarf Outfit"])
	assert_array(_type_names(EquipmentLook.Slot.LEGS, dwarf)).is_empty()
	assert_array(_type_names(EquipmentLook.Slot.MAIN_HAND, dwarf)).contains_exactly_in_any_order(["Dwarf Weapon", "Dwarf Two-Handed Weapon"])

func test_choosing_a_type_starts_from_a_copy_of_its_first_look() -> void:
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(EquipmentFixtures.load_type("chest_armor"))
	var first: EquipmentLook = _chest()
	assert_object(first).is_not_same(catalog.get_look(catalog.get_first_key()))
	assert_str(first.name).is_equal(catalog.get_look(catalog.get_first_key()).name)

func test_every_part_gets_a_carousel_and_pairs_share_one() -> void:
	var carousels: Array[Array] = EquipmentSlotProperty.get_carousel_parts(_chest(), {})
	assert_array(_parts(carousels)).contains_exactly(["TORSO", "ARM_UPPER_LEFT, ARM_UPPER_RIGHT", "SHOULDER_ATTACH_LEFT, SHOULDER_ATTACH_RIGHT"])
	var split: Dictionary[int, bool] = {ModularCharacter.Part.SHOULDER_ATTACH_LEFT: true}
	assert_array(_parts(EquipmentSlotProperty.get_carousel_parts(_chest(), split))).contains_exactly(["TORSO", "ARM_UPPER_LEFT, ARM_UPPER_RIGHT", "SHOULDER_ATTACH_LEFT", "SHOULDER_ATTACH_RIGHT"])

func test_stepping_a_part_leaves_the_others_and_moves_its_partner() -> void:
	var chest: EquipmentLook = _chest()
	var torso: String = EquipmentSlotProperty.get_mesh_number(chest, ModularCharacter.Part.TORSO)
	var stepped: EquipmentLook = EquipmentSlotProperty.step_parts(chest, [ModularCharacter.Part.ARM_UPPER_LEFT, ModularCharacter.Part.ARM_UPPER_RIGHT], 1)
	assert_object(stepped).is_not_same(chest)
	assert_str(EquipmentSlotProperty.get_mesh_number(stepped, ModularCharacter.Part.TORSO)).is_equal(torso)
	var left: String = EquipmentSlotProperty.get_mesh_number(stepped, ModularCharacter.Part.ARM_UPPER_LEFT)
	assert_str(left).is_not_equal(EquipmentSlotProperty.get_mesh_number(chest, ModularCharacter.Part.ARM_UPPER_LEFT))
	assert_str(EquipmentSlotProperty.get_mesh_number(stepped, ModularCharacter.Part.ARM_UPPER_RIGHT)).is_equal(left)
	assert_object(stepped.appearance).override_failure_message("A step must not change the look it started from").is_not_same(chest.appearance)

func test_split_sides_differ_until_linked() -> void:
	var chest: EquipmentLook = _chest()
	var stepped: EquipmentLook = EquipmentSlotProperty.step_parts(chest, [ModularCharacter.Part.SHOULDER_ATTACH_LEFT], 1)
	var left: String = EquipmentSlotProperty.get_mesh_number(stepped, ModularCharacter.Part.SHOULDER_ATTACH_LEFT)
	assert_str(left).is_not_equal(EquipmentSlotProperty.get_mesh_number(stepped, ModularCharacter.Part.SHOULDER_ATTACH_RIGHT))
	assert_int(EquipmentSlotProperty.get_carousel_parts(stepped, {}).size()).override_failure_message("Differing sides must show apart").is_equal(4)
	var linked: EquipmentLook = EquipmentSlotProperty.match_part(stepped, ModularCharacter.Part.SHOULDER_ATTACH_RIGHT, ModularCharacter.Part.SHOULDER_ATTACH_LEFT)
	assert_str(EquipmentSlotProperty.get_mesh_number(linked, ModularCharacter.Part.SHOULDER_ATTACH_RIGHT)).is_equal(left)

func test_decorative_parts_can_show_none() -> void:
	var chest: EquipmentLook = _chest()
	var shoulders: Array = [ModularCharacter.Part.SHOULDER_ATTACH_LEFT, ModularCharacter.Part.SHOULDER_ATTACH_RIGHT]
	var seen_none: bool = false
	var look: EquipmentLook = chest
	for step_index: int in chest.type.get_mesh_options(ModularCharacter.Part.SHOULDER_ATTACH_LEFT).size():
		look = EquipmentSlotProperty.step_parts(look, shoulders, 1)
		if not look.get_part_mesh(ModularCharacter.Part.SHOULDER_ATTACH_LEFT):
			seen_none = true
			assert_str(EquipmentSlotProperty.describe_carousel(look, shoulders)).is_equal("Shoulder Attach 00")
	assert_bool(seen_none).is_true()

func test_carousels_name_the_part_and_its_number() -> void:
	var chest: EquipmentLook = _chest()
	var torso: String = EquipmentSlotProperty.get_mesh_number(chest, ModularCharacter.Part.TORSO)
	assert_str(EquipmentSlotProperty.describe_carousel(chest, [ModularCharacter.Part.TORSO])).is_equal("Torso %s" % torso)
	assert_str(EquipmentSlotProperty.describe_carousel(chest, [ModularCharacter.Part.SHOULDER_ATTACH_LEFT])).starts_with("Shoulder Attach Left ")

func test_a_blocking_look_names_itself_as_the_blocker() -> void:
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.FACE)).is_null()
	var helmet: EquipmentLook = EquipmentSlotProperty.get_first_look(EquipmentFixtures.load_type("helmet"))
	_knight.set_starting_equipment_for(EquipmentLook.Slot.HEAD, helmet)
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.FACE)).is_same(helmet)
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.TORSO)).is_null()
