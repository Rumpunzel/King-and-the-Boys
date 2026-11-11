extends GdUnitTestSuite
## Weapons and shields: meshes held in the hands of both bodies, a one-handed or a two-handed weapon in the main hand, and two-handed
## weapons leave no hand for a shield

var _models: Array[ModularModel]

func before_test() -> void:
	_models = [EquipmentFixtures.make_model(), EquipmentFixtures.make_dwarf_model()]
	for model: ModularModel in _models:
		auto_free(model)
		add_child(model)

## The catalog look [param combination_key] of the type [param type_name], for [param model]'s body
func _look(model: ModularModel, type_name: String, combination_key: String = "01") -> EquipmentLook:
	var prefix: String = "dwarf_" if model is DwarfCharacter else ""
	return EquipmentCatalog.find_for(EquipmentFixtures.load_type(prefix + type_name)).get_look(combination_key)

func _hand_parts(model: ModularModel) -> Array[ModularBodyPart]:
	return [model.get("main_hand"), model.get("two_handed"), model.get("off_hand")]

func _equipment_on(model: ModularModel) -> CharacterEquipment:
	var equipment: CharacterEquipment = auto_free(CharacterEquipment.new())
	equipment.apply_to(model)
	return equipment

func test_both_bodies_hold_weapons_in_their_hands() -> void:
	for model: ModularModel in _models:
		var hand_parts: Array[ModularBodyPart] = _hand_parts(model)
		for hand_part: ModularBodyPart in hand_parts:
			assert_object(hand_part).is_not_null()
			assert_bool(hand_part.allows_none()).is_true()
			assert_bool(hand_part.visible).override_failure_message("Hands start empty").is_false()
		assert_str((hand_parts[0].get_parent() as BoneAttachment3D).bone_name).is_equal("RightHand")
		assert_str((hand_parts[1].get_parent() as BoneAttachment3D).bone_name).is_equal("RightHand")
		assert_str((hand_parts[2].get_parent() as BoneAttachment3D).bone_name).is_equal("LeftHand")
		assert_int(hand_parts[0].get_mesh_count()).is_equal(38)
		assert_int(hand_parts[1].get_mesh_count()).is_equal(49)
		assert_int(hand_parts[2].get_mesh_count()).is_equal(45)

func test_hand_parts_are_gear_not_body() -> void:
	for model: ModularModel in _models:
		var main_hand: Array[int] = model.get_slot_parts(EquipmentLook.Slot.MAIN_HAND)
		assert_int(main_hand.size()).is_equal(2)
		assert_int(model.get_slot_parts(EquipmentLook.Slot.OFF_HAND).size()).is_equal(1)
		for part: int in main_hand: assert_array(model.get_body_parts()).not_contains([part])

func test_a_weapon_and_a_shield_fill_both_hands() -> void:
	for model: ModularModel in _models:
		var equipment: CharacterEquipment = _equipment_on(model)
		var hand_parts: Array[ModularBodyPart] = _hand_parts(model)
		assert_bool(equipment.equip(_look(model, "weapon", "05"))).is_true()
		assert_bool(equipment.equip(_look(model, "shield", "03"))).is_true()
		assert_str(EquipmentFixtures.mesh_path(hand_parts[0])).ends_with("_05.res")
		assert_str(EquipmentFixtures.mesh_path(hand_parts[2])).ends_with("weapon_shield_03.res")
		assert_bool(hand_parts[1].visible).is_false()
		equipment.unequip(EquipmentLook.Slot.MAIN_HAND)
		assert_bool(hand_parts[0].visible).is_false()
		assert_bool(hand_parts[2].visible).override_failure_message("The shield stays").is_true()

func test_a_two_handed_weapon_takes_both_hands() -> void:
	for model: ModularModel in _models:
		var equipment: CharacterEquipment = _equipment_on(model)
		var hand_parts: Array[ModularBodyPart] = _hand_parts(model)
		equipment.equip(_look(model, "weapon"))
		equipment.equip(_look(model, "shield"))
		# It replaces the one-handed weapon and puts the shield away
		assert_bool(equipment.equip(_look(model, "two_handed_weapon", "14"))).is_true()
		assert_bool(hand_parts[0].visible).is_false()
		assert_str(EquipmentFixtures.mesh_path(hand_parts[1])).ends_with("_14.res")
		assert_bool(hand_parts[2].visible).is_false()
		assert_object(equipment.get_equipped(EquipmentLook.Slot.OFF_HAND)).is_null()
		# No shield while both hands hold it
		assert_bool(equipment.equip(_look(model, "shield"))).is_false()
		# A one-handed weapon frees the off hand again
		assert_bool(equipment.equip(_look(model, "weapon"))).is_true()
		assert_bool(hand_parts[1].visible).is_false()
		assert_bool(equipment.equip(_look(model, "shield"))).is_true()

func test_weapons_fit_their_own_body_only() -> void:
	var human: ModularModel = _models[0]
	var dwarf: ModularModel = _models[1]
	assert_bool(_look(dwarf, "weapon").type.fits(human)).is_false()
	assert_bool(_look(human, "weapon").type.fits(dwarf)).is_false()
	assert_bool(_equipment_on(dwarf).equip(_look(human, "shield"))).is_false()

func test_weapon_types_are_valid() -> void:
	for type_name: String in ["weapon", "two_handed_weapon", "shield", "dwarf_weapon", "dwarf_two_handed_weapon", "dwarf_shield"]:
		var equipment_type: EquipmentType = EquipmentFixtures.load_type(type_name)
		assert_array(equipment_type.call("_get_configuration_warnings") as PackedStringArray).override_failure_message("%s: %s" % [type_name, equipment_type.call("_get_configuration_warnings")]).is_empty()
