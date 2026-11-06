extends GdUnitTestSuite

const EDITOR_SCENE: String = "res://addons/menagerie/equipment_editor.tscn"

var _editor: PanelContainer
var _model: ModularCharacter

func before_test() -> void:
	var scene: PackedScene = load(EDITOR_SCENE)
	_editor = auto_free(scene.instantiate())
	_model = auto_free(EquipmentFixtures.make_model())
	_editor.set("_model", _model)
	# Kept out of the tree, every row the panel builds would count as an orphan
	add_child(_editor)
	add_child(_model)

func after_test() -> void:
	# Catalogs made here have no file, so this saves nothing; it only clears what toggling queued
	CatalogSaver.flush()
	# Replaced part rows are freed at the end of the frame
	await get_tree().process_frame

func _use_type(type_name: String) -> EquipmentType:
	var equipment_type: EquipmentType = EquipmentFixtures.load_type(type_name)
	var types: Array[EquipmentType] = [equipment_type]
	_editor.set("_types", types)
	var option: OptionButton = _editor.get("_type_option")
	option.clear()
	option.add_item(equipment_type.name)
	option.select(0)
	_editor.call("_update")
	return equipment_type

## A catalog without a file, so nothing here is ever saved
func _use_catalog(equipment_type: EquipmentType) -> EquipmentCatalog:
	var catalog: EquipmentCatalog = EquipmentCatalog.new()
	catalog.type = equipment_type
	_editor.set("_catalog", catalog)
	_editor.call("_update_look_row")
	return catalog

func _show_helmet(head: String, attachment: String) -> void:
	_model.head_no_elements.update_index(_model.head_no_elements.find_mesh_index(head))
	_model.helmet_attachment.update_index(_model.helmet_attachment.find_mesh_index(attachment))
	_editor.call("_update_look_row")

func test_type_info_shows_slot_and_blocking() -> void:
	_use_type("helmet")
	var info: Label = _editor.get("_type_info_label")
	assert_str(info.text).contains("Slot: Head").contains("Blocks: Face")

func test_stepping_a_part_moves_its_linked_parts() -> void:
	_use_type("gloves")
	_editor.call("_step_part", ModularCharacter.Part.HAND_LEFT, 1)
	var hand_number: String = ModularBodyPart.get_mesh_number(EquipmentFixtures.mesh_path(_model.hand_left))
	for linked: ModularBodyPart in [_model.hand_right, _model.arm_lower_left, _model.arm_lower_right]:
		assert_str(ModularBodyPart.get_mesh_number(EquipmentFixtures.mesh_path(linked))).is_equal(hand_number)

func test_shown_combination_matches_the_captured_look_key() -> void:
	var helmet_type: EquipmentType = _use_type("helmet")
	_show_helmet("05", "10")
	var shown_key: String = _editor.call("_get_combination_key")
	assert_str(shown_key).is_equal("05 10")
	assert_str(helmet_type.get_combination_key_of(EquipmentLook.from_model(_model, helmet_type))).is_equal(shown_key)

func test_look_row_shows_whether_the_combination_is_in_the_catalog() -> void:
	var catalog: EquipmentCatalog = _use_catalog(_use_type("helmet"))
	_show_helmet("05", "10")
	var label: Label = _editor.get("_look_label")
	var allowed_check: CheckBox = _editor.get("_allowed_check")
	assert_str(label.text).is_equal("Helmet 05 10  (not in the catalog yet)")
	assert_bool(allowed_check.button_pressed).is_false()
	catalog.add(EquipmentLook.from_model(_model, catalog.type), "05 10", true)
	_editor.call("_update_look_row")
	assert_str(label.text).is_equal("Helmet 05 10")
	assert_bool(allowed_check.button_pressed).is_true()

func test_checking_adds_and_flips_the_shown_look() -> void:
	var catalog: EquipmentCatalog = _use_catalog(_use_type("helmet"))
	_show_helmet("05", "10")
	var changes: Array[int] = [0]
	_editor.connect("catalog_changed", func() -> void: changes[0] += 1)
	var allowed_check: CheckBox = _editor.get("_allowed_check")
	allowed_check.button_pressed = true
	var look: EquipmentLook = catalog.get_look("05 10")
	assert_object(look).is_not_null()
	assert_bool(look.allowed).is_true()
	assert_int(changes[0]).override_failure_message("A new look must rebuild lists of looks").is_equal(1)
	allowed_check.button_pressed = false
	assert_bool(look.allowed).is_false()
	assert_int(catalog.looks.size()).is_equal(1)

func test_empty_combinations_cannot_be_checked() -> void:
	_use_catalog(_use_type("helmet"))
	_model.head_no_elements.update_index(-1)
	_model.helmet_attachment.update_index(-1)
	_editor.call("_update_look_row")
	var allowed_check: CheckBox = _editor.get("_allowed_check")
	assert_bool(allowed_check.disabled).is_true()
