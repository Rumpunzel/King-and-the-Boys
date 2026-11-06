extends GdUnitTestSuite

var _character: Character
var _equipment: CharacterEquipment
var _helmet: EquipmentLook
var _mask: EquipmentLook
var _hat: EquipmentLook

func before_test() -> void:
	var knight: CharacterProfile = load(EquipmentFixtures.KNIGHT)
	_character = auto_free(knight.create(0, Transform3D()))
	# Out of the tree, every node a test creates counts as an orphan
	_enter_tree_with_level()
	_equipment = _character.equipment
	_equipment.unequip_all()
	_helmet = EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	_mask = EquipmentFixtures.make_item(EquipmentFixtures.load_type("mask"), ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR, EquipmentFixtures.MASK)
	_hat = EquipmentFixtures.make_item(EquipmentFixtures.load_type("hat"), ModularCharacter.Part.HEAD_COVERINGS_BASE_HAIR, EquipmentFixtures.HAT)

func after() -> void:
	EquipmentFixtures.remove_saved_items()

## Characters need a level once they enter the tree
func _enter_tree_with_level() -> void:
	var level: Level = auto_free(Level.new())
	add_child(level)
	_character.level = level
	add_child(_character)

func _model() -> ModularCharacter:
	return _character.model

func test_character_hands_its_model_to_equipment() -> void:
	assert_object(_equipment).is_not_null()
	assert_object(_equipment._model).is_same(_character.model)

func test_helmet_removes_mask_and_blocks_it() -> void:
	assert_bool(_equipment.equip(_mask)).is_true()
	assert_str(EquipmentFixtures.mesh_path(_model().head_coverings_no_facial_hair)).is_equal(EquipmentFixtures.MASK)
	assert_bool(_equipment.equip(_helmet)).is_true()
	assert_object(_equipment.get_equipped(EquipmentLook.Slot.FACE)).is_null()
	assert_str(EquipmentFixtures.mesh_path(_model().head_coverings_no_facial_hair)).is_not_equal(EquipmentFixtures.MASK)
	assert_bool(_equipment.equip(_mask)).is_false()

func test_replacing_an_item_clears_parts_the_new_type_does_not_use() -> void:
	_equipment.equip(_hat)
	_equipment.equip(_helmet)
	assert_object(_equipment.get_equipped(EquipmentLook.Slot.HEAD)).is_same(_helmet)
	assert_str(EquipmentFixtures.mesh_path(_model().head_coverings_base_hair)).is_not_equal(EquipmentFixtures.HAT)

func test_equipment_is_reapplied_after_a_model_rebuild() -> void:
	_equipment.equip(_helmet)
	var old_model: ModularCharacter = _model()
	_character.profile = _character.profile
	assert_object(_model()).is_not_same(old_model)
	assert_str(EquipmentFixtures.mesh_path(_model().helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	# The replaced model is freed at the end of the frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(old_model)).override_failure_message("The replaced model was never freed").is_false()

func test_unequip_resets_parts_and_frees_blocked_slots() -> void:
	_equipment.equip(_helmet)
	_equipment.unequip(EquipmentLook.Slot.HEAD)
	assert_str(EquipmentFixtures.mesh_path(_model().helmet_attachment)).is_not_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_bool(_equipment.equip(_mask)).is_true()

func test_belt_and_leg_armor_are_worn_together() -> void:
	var belt: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("belt"), ModularCharacter.Part.HIPS_ATTACHMENT, EquipmentFixtures.BELT)
	var trousers: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("leg_armor"), ModularCharacter.Part.HIPS, EquipmentFixtures.HIPS_MALE)
	assert_bool(_equipment.equip(belt) and _equipment.equip(trousers)).is_true()
	assert_str(EquipmentFixtures.mesh_path(_model().hips_attachment)).is_equal(EquipmentFixtures.BELT)
	assert_str(EquipmentFixtures.mesh_path(_model().hips)).is_equal(EquipmentFixtures.HIPS_MALE)

func test_equipped_ids_round_trip() -> void:
	var saved_helmet: EquipmentLook = EquipmentFixtures.save_item(_helmet, "helmet.tres")
	_equipment.equipped_ids = PackedStringArray([ResourceId.of(saved_helmet)])
	assert_object(_equipment.get_equipped(EquipmentLook.Slot.HEAD)).is_same(saved_helmet)
	assert_array(_equipment.equipped_ids).contains_exactly([ResourceId.of(saved_helmet)])

func test_plain_paths_from_older_saves_still_equip() -> void:
	var saved_helmet: EquipmentLook = EquipmentFixtures.save_item(_helmet, "helmet.tres")
	_equipment.equipped_ids = PackedStringArray([saved_helmet.resource_path])
	assert_object(_equipment.get_equipped(EquipmentLook.Slot.HEAD)).is_same(saved_helmet)

func test_equipment_stays_server_authoritative_inside_a_client_subtree() -> void:
	# A PlayerGhost hands its subtree to its player before the character enters the tree
	var knight: CharacterProfile = load(EquipmentFixtures.KNIGHT)
	var client_character: Character = auto_free(knight.create(0, Transform3D()))
	client_character.set_multiplayer_authority(5)
	client_character.level = _character.level
	add_child(client_character)
	var client_equipment: CharacterEquipment = client_character.equipment
	var synchronizer: MultiplayerSynchronizer = client_equipment.get_node("EquipmentSynchronizer")
	assert_int(client_character.get_multiplayer_authority()).is_equal(5)
	assert_int(client_equipment.get_multiplayer_authority()).is_equal(1)
	assert_int(synchronizer.get_multiplayer_authority()).is_equal(1)
	assert_bool(synchronizer.replication_config.has_property(NodePath(".:equipped_ids"))).is_true()

func test_equip_requests_only_accept_items_from_the_item_directory() -> void:
	var saved_helmet: EquipmentLook = EquipmentFixtures.save_item(_helmet, "helmet.tres")
	_equipment.request_equip(saved_helmet)
	assert_object(_equipment.get_equipped(EquipmentLook.Slot.HEAD)).is_same(saved_helmet)
	_equipment.unequip_all()
	for refused_path: String in [
			"user://evil.tres",
			EquipmentFixtures.KNIGHT,
			ResourceId.of(load(EquipmentFixtures.KNIGHT) as Resource),
			"uid://doesnotexist",
			EquipmentFixtures.SAVED_ITEMS + "/../../characters/people/knight.tres",
			EquipmentLook.ITEM_DIRECTORY + "/does_not_exist.tres",
		]:
		_equipment._request_equip(refused_path)
		assert_array(_equipment.equipped_ids).override_failure_message("%s was accepted" % refused_path).is_empty()
	_equipment._request_unequip(99)
	_equipment.request_equip(saved_helmet)
	_equipment.request_unequip(EquipmentLook.Slot.HEAD)
	assert_array(_equipment.equipped_ids).is_empty()
