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

func _count() -> int:
	return _editor.call("_count_combinations")

## Walks every combination like Create Combinations does, without saving
func _collect_names() -> Dictionary[String, bool]:
	var dimensions: Array[Array] = _editor.call("_get_dimensions")
	var options: Array[Array] = []
	for dimension: Array in dimensions:
		var dimension_options: PackedStringArray = _editor.call("_get_options", dimension)
		options.append(Array(dimension_options))
	var counters: Array[int] = []
	counters.resize(dimensions.size())
	counters.fill(0)
	var names: Dictionary[String, bool] = {}
	while true:
		if _editor.call("_apply_combination", dimensions, options, counters): names[_editor.call("_get_combination_name")] = true
		if not _editor.call("_advance", options, counters): break
	return names

func _with_none(body_part: ModularBodyPart) -> int:
	return body_part.get_mesh_count() + int(body_part.allows_none())

func test_helmet_combinations_include_none_for_both_parts() -> void:
	_use_type("helmet")
	var expected: int = _with_none(_model.head_no_elements) * _with_none(_model.helmet_attachment)
	assert_int(_count()).is_equal(expected)
	var names: Dictionary[String, bool] = _collect_names()
	assert_int(names.size()).is_equal(expected)
	assert_bool(names.has("Helmet 01 none")).is_true()

func test_unchecked_parts_keep_their_mesh() -> void:
	_use_type("helmet")
	var check_boxes: Dictionary = _editor.get("_vary_check_boxes")
	var head_check_box: CheckBox = check_boxes[ModularCharacter.Part.HEAD_NO_ELEMENTS]
	head_check_box.button_pressed = false
	assert_int(_count()).is_equal(_with_none(_model.helmet_attachment))

func test_gloves_vary_by_lower_arm_and_elbow_pair() -> void:
	_use_type("gloves")
	var dimensions: Array[Array] = _editor.call("_get_dimensions")
	assert_int(dimensions.size()).is_equal(2)
	assert_int(dimensions[0].size()).is_equal(4)
	assert_int(dimensions[1].size()).is_equal(2)
	var expected: int = _model.arm_lower_left.get_mesh_count() * _with_none(_model.elbow_attach_left)
	assert_int(_count()).is_equal(expected)
	var names: Dictionary[String, bool] = _collect_names()
	assert_int(names.size()).is_equal(expected)
	assert_bool(names.has("Gloves 05 03")).is_true()

func test_group_leaders_reach_numbers_their_partners_lack() -> void:
	_use_type("chest_armor")
	var expected: int = _model.torso.get_mesh_count() * _with_none(_model.shoulder_attach_left)
	assert_int(_count()).is_equal(expected)
	var names: Dictionary[String, bool] = _collect_names()
	assert_int(names.size()).is_equal(expected)
	var last_torso: String = _model.torso.get_mesh_numbers()[-1]
	assert_bool(names.keys().any(func(item_name: String) -> bool: return item_name.begins_with("Chest Armor %s" % last_torso))).is_true()

func test_stepping_a_part_moves_its_linked_parts() -> void:
	_use_type("gloves")
	_editor.call("_step_part", ModularCharacter.Part.HAND_LEFT, 1, null)
	var hand_number: String = ModularBodyPart.get_mesh_number(EquipmentFixtures.mesh_path(_model.hand_left))
	for linked: ModularBodyPart in [_model.hand_right, _model.arm_lower_left, _model.arm_lower_right]:
		assert_str(ModularBodyPart.get_mesh_number(EquipmentFixtures.mesh_path(linked))).is_equal(hand_number)

func test_shown_combination_matches_the_saved_item_key() -> void:
	var helmet_type: EquipmentType = _use_type("helmet")
	_model.head_no_elements.update_index(_model.head_no_elements.find_mesh_index("05"))
	_model.helmet_attachment.update_index(_model.helmet_attachment.find_mesh_index("10"))
	var captured: EquipmentProfile = EquipmentProfile.from_model(_model, helmet_type)
	var shown_key: String = _editor.call("_get_combination_key")
	assert_str(shown_key).is_equal("05 10")
	assert_str(helmet_type.get_combination_key_of(captured)).is_equal(shown_key)

func test_type_info_shows_slot_blocking_and_exclusions() -> void:
	var helmet_type: EquipmentType = _use_type("helmet")
	var info: Label = _editor.get("_type_info_label")
	assert_str(info.text).contains("Slot: Head").contains("Blocks: Face")
	var excluded: PackedStringArray = helmet_type.excluded_combinations
	helmet_type.excluded_combinations = ["01 01"]
	_editor.call("_update")
	assert_str(info.text).contains("Excluded: 1")
	helmet_type.excluded_combinations = excluded
