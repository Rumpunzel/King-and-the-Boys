extends GdUnitTestSuite

var _knight: CharacterProfile
var _original_starting_equipment: Dictionary
var _changes: int = 0

func before_test() -> void:
	_knight = load(EquipmentFixtures.KNIGHT)
	_original_starting_equipment = EquipmentFixtures.clear_starting_equipment(_knight)
	_changes = 0
	_knight.changed.connect(_count_change)

func after_test() -> void:
	_knight.changed.disconnect(_count_change)
	EquipmentFixtures.restore_starting_equipment(_knight, _original_starting_equipment)

func _count_change() -> void:
	_changes += 1

func _helmet() -> EquipmentProfile:
	return EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)

func _cape() -> EquipmentProfile:
	return EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE)

func test_every_slot_has_a_starting_field() -> void:
	for slot: EquipmentProfile.Slot in EquipmentProfile.Slot.values():
		assert_bool(CharacterProfile.get_slot_property(slot) in _knight).override_failure_message("No field for slot %d" % slot).is_true()

func test_fields_list_items_in_slot_order() -> void:
	var helmet: EquipmentProfile = _helmet()
	var cape: EquipmentProfile = _cape()
	_knight.back = cape
	_knight.head = helmet
	assert_array(_knight.get_starting_equipment()).contains_exactly([helmet, cape])

func test_fields_reject_items_of_other_slots_and_untyped_items() -> void:
	var helmet: EquipmentProfile = _helmet()
	_knight.head = helmet
	_knight.torso = _cape()
	assert_object(_knight.torso).is_null()
	_knight.head = _cape()
	assert_object(_knight.head).is_same(helmet)
	var untyped: EquipmentProfile = EquipmentProfile.new()
	_knight.back = untyped
	assert_object(_knight.back).is_null()

func test_blocking_starting_items_are_warned_about() -> void:
	_knight.head = _helmet()
	_knight.face = EquipmentFixtures.make_item(EquipmentFixtures.load_type("mask"), ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR, EquipmentFixtures.MASK)
	assert_bool(_has_warning("blocks FACE")).is_true()
	_knight.face = null
	assert_bool(_has_warning("blocks")).is_false()

func _has_warning(text: String) -> bool:
	for warning: String in _knight._get_configuration_warnings():
		if warning.contains(text): return true
	return false

func test_editing_equipment_refreshes_previews() -> void:
	var cape: EquipmentProfile = _cape()
	_knight.back = cape
	assert_int(_changes).is_greater(0)
	_changes = 0
	cape.emit_changed()
	assert_int(_changes).override_failure_message("Editing a worn item does not reach the character").is_greater(0)
	_changes = 0
	cape.appearance.emit_changed()
	assert_int(_changes).override_failure_message("Editing a worn item's appearance does not reach the character").is_greater(0)
	_knight.back = null
	_changes = 0
	cape.emit_changed()
	assert_int(_changes).override_failure_message("A removed item still refreshes the character").is_equal(0)

func test_previews_show_starting_equipment_and_drop_removed_items() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	_knight.head = _helmet()
	_knight.back = _cape()
	_knight.setup_model(model)
	assert_str(EquipmentFixtures.mesh_path(model.helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_str(EquipmentFixtures.mesh_path(model.back_attachment)).is_equal(EquipmentFixtures.CAPE)
	_knight.back = null
	_knight.setup_model(model)
	assert_str(EquipmentFixtures.mesh_path(model.back_attachment)).is_not_equal(EquipmentFixtures.CAPE)

func test_items_preview_themselves_on_a_plain_character() -> void:
	var helmet: EquipmentProfile = _helmet()
	assert_int(helmet.get_variation_count()).is_equal(1)
	var model: ModularCharacter = auto_free(helmet.create_model(0))
	assert_str(EquipmentFixtures.mesh_path(model.helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_object(model.back_attachment.mesh).is_null()
