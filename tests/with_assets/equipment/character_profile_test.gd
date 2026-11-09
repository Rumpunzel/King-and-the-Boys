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

## Starting slots store IDs, so their items are saved
func _helmet() -> EquipmentLook:
	return EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT), "profile_helmet.tres")

func _cape() -> EquipmentLook:
	return EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE), "profile_cape.tres")

func _mask() -> EquipmentLook:
	return EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("mask"), ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR, EquipmentFixtures.MASK), "profile_mask.tres")

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func test_every_slot_has_a_starting_field() -> void:
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		assert_bool(CharacterProfile.get_slot_property(slot) in _knight).override_failure_message("No field for slot %d" % slot).is_true()

func test_fields_list_items_in_slot_order() -> void:
	var helmet: EquipmentLook = _helmet()
	var cape: EquipmentLook = _cape()
	_knight.back = ResourceId.of(cape)
	_knight.head = ResourceId.of(helmet)
	assert_array(_knight.get_starting_equipment()).contains_exactly([helmet, cape])

func test_fields_reject_items_of_other_slots_and_untyped_items() -> void:
	var helmet: EquipmentLook = _helmet()
	_knight.head = ResourceId.of(helmet)
	_knight.torso = ResourceId.of(_cape())
	assert_str(_knight.torso).is_empty()
	_knight.head = ResourceId.of(_cape())
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.HEAD)).is_same(helmet)
	var untyped: EquipmentLook = EquipmentFixtures.save_item(EquipmentLook.new(), "untyped.tres")
	_knight.back = ResourceId.of(untyped)
	assert_str(_knight.back).is_empty()
	_knight.back = "uid://doesnotexist"
	assert_str(_knight.back).is_empty()

func test_blocking_starting_items_are_warned_about() -> void:
	_knight.head = ResourceId.of(_helmet())
	_knight.face = ResourceId.of(_mask())
	assert_bool(_has_warning("blocks FACE")).is_true()
	_knight.face = ""
	assert_bool(_has_warning("blocks")).is_false()

func _has_warning(text: String) -> bool:
	for warning: String in _knight._get_configuration_warnings():
		if warning.contains(text): return true
	return false

func test_editing_equipment_refreshes_previews() -> void:
	var cape: EquipmentLook = _cape()
	_knight.back = ResourceId.of(cape)
	assert_int(_changes).is_greater(0)
	_changes = 0
	cape.emit_changed()
	assert_int(_changes).override_failure_message("Editing a worn item does not reach the character").is_greater(0)
	_changes = 0
	cape.appearance.emit_changed()
	assert_int(_changes).override_failure_message("Editing a worn item's appearance does not reach the character").is_greater(0)
	_knight.back = ""
	_changes = 0
	cape.emit_changed()
	assert_int(_changes).override_failure_message("A removed item still refreshes the character").is_equal(0)

func test_previews_show_starting_equipment_and_drop_removed_items() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	_knight.head = ResourceId.of(_helmet())
	_knight.back = ResourceId.of(_cape())
	_knight.setup_model(model)
	assert_str(EquipmentFixtures.mesh_path(model.helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_str(EquipmentFixtures.mesh_path(model.back_attachment)).is_equal(EquipmentFixtures.CAPE)
	_knight.back = ""
	_knight.setup_model(model)
	assert_str(EquipmentFixtures.mesh_path(model.back_attachment)).is_not_equal(EquipmentFixtures.CAPE)

func test_items_preview_themselves_on_a_plain_character() -> void:
	var helmet: EquipmentLook = _helmet()
	assert_int(helmet.get_variation_count()).is_equal(1)
	var model: ModularCharacter = auto_free(helmet.create_model(0))
	assert_str(EquipmentFixtures.mesh_path(model.helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_object(model.back_attachment.mesh).is_null()

func test_unchecked_starting_looks_are_kept_but_warned_about() -> void:
	var unchecked: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE)
	unchecked.allowed = false
	var saved: EquipmentLook = EquipmentFixtures.save_item(unchecked, "unchecked_cape.tres")
	_knight.back = ResourceId.of(saved)
	assert_str(_knight.back).is_equal(ResourceId.of(saved))
	assert_bool(_has_warning("unchecked")).is_true()

func test_previews_keep_their_face_until_rerolled() -> void:
	var first: ModularCharacter = auto_free(_knight.create_model(0))
	add_child(first)
	var face: String = EquipmentFixtures.mesh_path(first.head) + EquipmentFixtures.mesh_path(first.hair)
	for attempt: int in 5:
		var rebuilt: ModularCharacter = auto_free(_knight.create_model(0))
		add_child(rebuilt)
		assert_str(EquipmentFixtures.mesh_path(rebuilt.head) + EquipmentFixtures.mesh_path(rebuilt.hair)).is_equal(face)
	var rerolled: bool = false
	for attempt: int in 20:
		_knight.setup_model(first, true)
		if EquipmentFixtures.mesh_path(first.head) + EquipmentFixtures.mesh_path(first.hair) != face: rerolled = true
	assert_bool(rerolled).override_failure_message("Rerolling never changed the face").is_true()
