extends GdUnitTestSuite
## Weapons, shields and torches: meshes held in the hands of both bodies, a one-handed or a two-handed weapon in the main hand, a shield or
## a one-handed weapon (a torch, a second blade) in the off hand, and two-handed weapons leave no hand for either

const ELF: String = "res://data/characters/people/elf.tres"

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
	return [model.get("main_hand"), model.get("two_handed"), model.get("off_hand"), model.get("off_hand_weapon")]

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
		assert_str((hand_parts[3].get_parent() as BoneAttachment3D).bone_name).is_equal("LeftHand")
		assert_int(hand_parts[0].get_mesh_count()).is_equal(39)
		assert_int(hand_parts[1].get_mesh_count()).is_equal(49)
		assert_int(hand_parts[2].get_mesh_count()).is_equal(45)
		# Either hand holds the one-handed weapons
		assert_array(hand_parts[3].get_mesh_paths()).is_equal(hand_parts[0].get_mesh_paths())

func test_hand_parts_are_gear_not_body() -> void:
	for model: ModularModel in _models:
		var main_hand: Array[int] = model.get_slot_parts(EquipmentLook.Slot.MAIN_HAND)
		assert_int(main_hand.size()).is_equal(2)
		var off_hand: Array[int] = model.get_slot_parts(EquipmentLook.Slot.OFF_HAND)
		assert_int(off_hand.size()).is_equal(2)
		for part: int in main_hand + off_hand: assert_array(model.get_body_parts()).not_contains([part])

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
	for type_name: String in ["weapon", "two_handed_weapon", "shield", "off_hand_weapon", "dwarf_weapon", "dwarf_two_handed_weapon", "dwarf_shield", "dwarf_off_hand_weapon"]:
		var equipment_type: EquipmentType = EquipmentFixtures.load_type(type_name)
		assert_array(equipment_type.call("_get_configuration_warnings") as PackedStringArray).override_failure_message("%s: %s" % [type_name, equipment_type.call("_get_configuration_warnings")]).is_empty()

## The torch's fire, shown on [param hand] (a hand part's name) while it holds the torch
func _fire(model: ModularModel, hand: String = "off_hand_weapon") -> Node3D:
	var hand_part: ModularBodyPart = model.get(hand)
	for child: Node in hand_part.get_children():
		if not child.is_queued_for_deletion() and child.scene_file_path.ends_with("torch_fire.tscn"): return child as Node3D
	return null

func test_the_elf_carries_a_torch_and_the_rogue_a_lantern() -> void:
	var elf: CharacterProfile = load(ELF)
	var off_hand: EquipmentLook = elf.starting_off_hand
	assert_str(off_hand.type.name if off_hand else "").is_equal("Off-Hand Weapon")
	assert_str(off_hand.get_part_mesh(off_hand.type.parts[0]).resource_path).contains("torch")
	var rogue: CharacterProfile = load("res://data/characters/people/rogue.tres")
	assert_object(rogue.starting_off_hand).is_null()
	assert_bool(rogue.abilities.any(func(ability: Ability) -> bool: return ability is ToggleLightAbility)).is_true()

func test_a_torch_burns_while_held_only() -> void:
	var model: ModularModel = _models[0]
	var equipment: CharacterEquipment = _equipment_on(model)
	var torch: EquipmentLook = (load(ELF) as CharacterProfile).starting_off_hand
	assert_object(_fire(model)).is_null()
	assert_array(torch.get_light_sources()).override_failure_message("The torch is a light").is_not_empty()
	assert_bool(equipment.equip(torch)).is_true()
	assert_object(_fire(model)).is_not_null()
	assert_bool(_fire(model).visible).is_true()
	# On the back it does not burn
	model.stow_weapons()
	assert_bool(_fire(model).visible).is_false()
	model.draw_weapons()
	assert_bool(_fire(model).visible).is_true()
	# A shield brings no fire along
	assert_bool(equipment.equip(_look(model, "shield"))).is_true()
	assert_object(_fire(model)).is_null()

func test_a_second_weapon_goes_in_the_off_hand() -> void:
	for model: ModularModel in _models:
		var equipment: CharacterEquipment = _equipment_on(model)
		var hand_parts: Array[ModularBodyPart] = _hand_parts(model)
		assert_bool(equipment.equip(_look(model, "weapon", "05"))).is_true()
		assert_bool(equipment.equip(_look(model, "off_hand_weapon", "07"))).is_true()
		assert_str(EquipmentFixtures.mesh_path(hand_parts[0])).ends_with("_05.res")
		assert_str(EquipmentFixtures.mesh_path(hand_parts[3])).ends_with("_07.res")
		# The off hand holds a shield or a weapon, never both
		assert_bool(equipment.equip(_look(model, "shield", "03"))).is_true()
		assert_bool(hand_parts[3].visible).is_false()
		assert_bool(equipment.equip(_look(model, "off_hand_weapon", "07"))).is_true()
		assert_bool(hand_parts[2].visible).is_false()
		# A two-handed weapon puts it away like a shield
		assert_bool(equipment.equip(_look(model, "two_handed_weapon", "14"))).is_true()
		assert_bool(hand_parts[3].visible).is_false()

func test_a_torch_burns_in_either_hand() -> void:
	for model: ModularModel in _models:
		var equipment: CharacterEquipment = _equipment_on(model)
		assert_bool(equipment.equip(_look(model, "weapon", "39"))).is_true()
		assert_object(_fire(model, "main_hand")).is_not_null()
		assert_bool(equipment.equip(_look(model, "off_hand_weapon", "39"))).is_true()
		assert_object(_fire(model)).is_not_null()
		# Burning upwards, however the hand holds it
		await get_tree().process_frame
		assert_float(_fire(model).global_basis.y.normalized().dot(Vector3.UP)).is_equal_approx(1.0, 0.001)
