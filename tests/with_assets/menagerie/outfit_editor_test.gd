extends GdUnitTestSuite

const EDITOR_SCENE: String = "res://addons/menagerie/outfit_editor.tscn"

var _editor: PanelContainer
var _knight: CharacterProfile
var _original_starting_equipment: Dictionary

func before_test() -> void:
	_knight = load(EquipmentFixtures.KNIGHT)
	_original_starting_equipment = EquipmentFixtures.clear_starting_equipment(_knight)
	_editor = auto_free((load(EDITOR_SCENE) as PackedScene).instantiate())
	add_child(_editor)
	_editor.call("_on_active_profile_changed", _knight)

func after_test() -> void:
	_editor.call("_on_active_profile_changed", null)
	EquipmentFixtures.restore_starting_equipment(_knight, _original_starting_equipment)
	# Replaced rows are freed at the end of the frame
	await get_tree().process_frame

func _slot_types(slot: EquipmentLook.Slot) -> Array[EquipmentType]:
	var slot_types: Array[EquipmentType] = []
	for equipment_type: EquipmentType in EquipmentType.find_all():
		if equipment_type.slot == slot: slot_types.append(equipment_type)
	return slot_types

func _choose(slot: EquipmentLook.Slot, type_name: String) -> EquipmentCatalog:
	var slot_types: Array[EquipmentType] = _slot_types(slot)
	var index: int = slot_types.find_custom(func(equipment_type: EquipmentType) -> bool: return equipment_type.name == type_name)
	_editor.call("_on_type_selected", index + 1, slot, slot_types)
	return EquipmentCatalog.find_for(slot_types[index])

func test_every_slot_with_types_gets_a_row() -> void:
	var rows: GridContainer = _editor.get("_rows")
	var slots_with_types: int = EquipmentLook.Slot.values().filter(func(slot: EquipmentLook.Slot) -> bool: return not _slot_types(slot).is_empty()).size()
	assert_int(rows.get_child_count()).is_equal(slots_with_types * rows.columns)

func test_choosing_a_type_wears_its_first_look() -> void:
	var catalog: EquipmentCatalog = _choose(EquipmentLook.Slot.TORSO, "Chest Armor")
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.TORSO)).is_same(catalog.get_look(catalog.get_first_key()))
	_editor.call("_on_type_selected", 0, EquipmentLook.Slot.TORSO, _slot_types(EquipmentLook.Slot.TORSO))
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.TORSO)).is_null()

func test_stepping_a_carousel_wears_the_next_look() -> void:
	var catalog: EquipmentCatalog = _choose(EquipmentLook.Slot.HEAD, "Helmet")
	var start: String = catalog.get_first_key()
	_editor.call("_step", EquipmentLook.Slot.HEAD, catalog, start, 1, 1)
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.HEAD)).is_same(catalog.get_look(catalog.step(start, 1, 1)))

func test_a_blocking_look_empties_the_slots_it_blocks() -> void:
	_choose(EquipmentLook.Slot.FACE, "Mask")
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.FACE)).is_not_null()
	_choose(EquipmentLook.Slot.HEAD, "Helmet")
	assert_object(_knight.get_starting_equipment_for(EquipmentLook.Slot.FACE)).is_null()
	_editor.call("_update")
	var rows: GridContainer = _editor.get("_rows")
	var face_option: OptionButton = rows.get_child(EquipmentLook.Slot.FACE * rows.columns + 1)
	assert_bool(face_option.disabled).is_true()
