@tool
extends PanelContainer

signal equipment_saved(equipment_profile: EquipmentProfile)

const ITEM_DIRECTORY: String = "res://data/equipment"
const TYPE_DIRECTORY: String = "res://data/equipment/types"
const NO_MODEL_HINT: String = "Select an item, or a modular character to start from."
## Above this many combinations, ask before creating them
const CONFIRM_COMBINATIONS: int = 200
## Above this many combinations, refuse; uncheck "vary" on some parts instead
const MAX_COMBINATIONS: int = 5000

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _gear_tab: Control
@export var _type_option: OptionButton
@export var _edit_type_button: Button
@export var _type_info_label: Label
@export var _parts_container: VBoxContainer
@export var _combinations_button: Button
@export var _name_edit: LineEdit
@export var _save_button: Button
@export var _save_as_new_button: Button
@export var _status_label: Label

var _model: ModularCharacter
## The item being edited, or [code]null[/code] when another profile is previewed
var _equipment_profile: EquipmentProfile
## Indexed like the items of [member _type_option]
var _types: Array[EquipmentType] = []
## Parts whose meshes are varied by [method _create_combinations]
var _vary_check_boxes: Dictionary[ModularCharacter.Part, CheckBox] = {}
var _is_set_up: bool = false

func _ready() -> void:
	# Do not bake generated items into this scene while it is edited itself
	if is_part_of_edited_scene(): return
	_gear_tab.visibility_changed.connect(_on_gear_tab_visibility_changed)
	_type_option.item_selected.connect(_on_type_selected)
	_edit_type_button.pressed.connect(_on_edit_type_pressed)
	_combinations_button.pressed.connect(_on_combinations_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_save_as_new_button.pressed.connect(_on_save_as_new_pressed)
	_is_set_up = true
	_on_gear_tab_visibility_changed()

func _load_types() -> void:
	var selected_type: EquipmentType = _get_type()
	_types.clear()
	_type_option.clear()
	if DirAccess.dir_exists_absolute(TYPE_DIRECTORY):
		for file_name: String in DirAccess.get_files_at(TYPE_DIRECTORY):
			if file_name.get_extension() != "tres": continue
			var equipment_type: EquipmentType = load(TYPE_DIRECTORY.path_join(file_name)) as EquipmentType
			if not equipment_type: continue
			_types.append(equipment_type)
			if equipment_type.icon: _type_option.add_icon_item(equipment_type.icon, equipment_type.name)
			else: _type_option.add_item(equipment_type.name)
	_select_type(selected_type)

func _get_type() -> EquipmentType:
	var selected_index: int = _type_option.selected
	if selected_index < 0 or selected_index >= _types.size(): return null
	return _types[selected_index]

func _select_type(equipment_type: EquipmentType) -> void:
	var type_index: int = _types.find(equipment_type)
	if type_index < 0 and not _types.is_empty(): type_index = 0
	_type_option.select(type_index)

func _update() -> void:
	var equipment_type: EquipmentType = _get_type()
	_edit_type_button.disabled = not equipment_type
	_type_info_label.text = _describe(equipment_type)
	_save_button.disabled = not _model or not _equipment_profile or not equipment_type
	_save_as_new_button.disabled = not _model or not equipment_type
	_save_button.tooltip_text = "Overwrite %s" % _equipment_profile.resource_path if _equipment_profile else "Select an item in the Gear tab to overwrite it"
	_rebuild_parts()

func _describe(equipment_type: EquipmentType) -> String:
	if not equipment_type: return "Create an EquipmentType in %s first." % TYPE_DIRECTORY
	var slot_name: String = EquipmentProfile.Slot.keys()[equipment_type.slot]
	var blocked_names: PackedStringArray = []
	for blocked_slot: EquipmentProfile.Slot in equipment_type.blocked_slots:
		var blocked_name: String = EquipmentProfile.Slot.keys()[blocked_slot]
		blocked_names.append(blocked_name.capitalize())
	var description: String = "Slot: %s" % slot_name.capitalize()
	if not blocked_names.is_empty(): description += "   Blocks: %s" % ", ".join(blocked_names)
	return description

func _rebuild_parts() -> void:
	for child: Node in _parts_container.get_children():
		_parts_container.remove_child(child)
		child.queue_free()
	_vary_check_boxes.clear()
	if not _model:
		_status_label.text = NO_MODEL_HINT
		_update_combinations_button()
		return
	if _status_label.text == NO_MODEL_HINT: _status_label.text = ""
	var equipment_type: EquipmentType = _get_type()
	if equipment_type:
		for part: ModularCharacter.Part in equipment_type.parts: _parts_container.add_child(_create_part_row(part))
	_update_combinations_button()

func _create_part_row(part: ModularCharacter.Part) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var part_name: String = ModularCharacter.Part.keys()[part]
	var vary_check_box: CheckBox = CheckBox.new()
	vary_check_box.button_pressed = true
	vary_check_box.tooltip_text = "Vary this part when creating combinations; unchecked parts keep the mesh shown"
	vary_check_box.toggled.connect(_on_vary_toggled)
	_vary_check_boxes[part] = vary_check_box
	var name_label: Label = Label.new()
	name_label.text = part_name.capitalize()
	name_label.custom_minimum_size.x = 200
	var previous_button: Button = Button.new()
	previous_button.text = "<"
	var mesh_label: Label = Label.new()
	mesh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mesh_label.clip_text = true
	var next_button: Button = Button.new()
	next_button.text = ">"
	previous_button.pressed.connect(_step_part.bind(part, -1, mesh_label))
	next_button.pressed.connect(_step_part.bind(part, 1, mesh_label))
	for control: Control in [vary_check_box, name_label, previous_button, mesh_label, next_button]: row.add_child(control)
	_update_mesh_label(part, mesh_label)
	return row

## Steps through the part's mesh directory; decorative parts include "none"
func _step_part(part: ModularCharacter.Part, direction: int, mesh_label: Label) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_count: int = body_part.get_mesh_count()
	if mesh_count == 0: return
	var lowest_index: int = -1 if body_part.allows_none() else 0
	var new_index: int = body_part.get_mesh_index() + direction
	if new_index < lowest_index: new_index = mesh_count - 1
	elif new_index >= mesh_count: new_index = lowest_index
	body_part.update_index(new_index)
	_update_mesh_label(part, mesh_label)
	_status_label.text = ""

func _update_mesh_label(part: ModularCharacter.Part, mesh_label: Label) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_index: int = body_part.get_mesh_index()
	if not body_part.visible or not body_part.mesh:
		mesh_label.text = "none"
		return
	var mesh_name: String = body_part.mesh.resource_path.get_file().get_basename().trim_prefix("modular_character_")
	mesh_label.text = "%s  (%d/%d)" % [mesh_name, mesh_index + 1, body_part.get_mesh_count()]
	mesh_label.tooltip_text = body_part.mesh.resource_path

## @returns the trailing number of the shown mesh's file, such as [code]"05"[/code], or [code]"none"[/code]
static func _get_mesh_number(body_part: ModularBodyPart) -> String:
	if not body_part.visible or not body_part.mesh: return "none"
	var regex: RegEx = RegEx.create_from_string("(\\d+)$")
	var mesh_name: String = body_part.mesh.resource_path.get_file().get_basename()
	var found: RegExMatch = regex.search(mesh_name)
	return found.get_string(1) if found else mesh_name

## Names an item after its type and the mesh number of each of the type's parts, e.g. "Helmet 02 05"
func _get_combination_name() -> String:
	var numbers: PackedStringArray = []
	for part: ModularCharacter.Part in _get_type().parts: numbers.append(_get_mesh_number(_model.get_part(part)))
	return "%s %s" % [_get_type().name, " ".join(numbers)]

func _get_item_path(item_name: String) -> String:
	return "%s/%s/%s.tres" % [ITEM_DIRECTORY, _get_type().name.to_snake_case(), item_name.to_snake_case()]

## Groups the varied parts; a left part and its right counterpart change together
## @returns an [Array] of dimensions, each an [Array] of one or two [enum ModularCharacter.Part]s
func _get_dimensions() -> Array[Array]:
	var dimensions: Array[Array] = []
	var varied: Array[ModularCharacter.Part] = []
	for part: ModularCharacter.Part in _vary_check_boxes:
		if _vary_check_boxes[part].button_pressed: varied.append(part)
	for part: ModularCharacter.Part in varied:
		var part_name: String = ModularCharacter.Part.keys()[part]
		if part_name.ends_with("_RIGHT") and varied.has(ModularCharacter.Part.get(part_name.trim_suffix("_RIGHT") + "_LEFT")): continue
		var dimension: Array[ModularCharacter.Part] = [part]
		if part_name.ends_with("_LEFT"):
			var right_name: String = part_name.trim_suffix("_LEFT") + "_RIGHT"
			if ModularCharacter.Part.has(right_name):
				var right_part: ModularCharacter.Part = ModularCharacter.Part[right_name]
				if varied.has(right_part): dimension.append(right_part)
		dimensions.append(dimension)
	return dimensions

## @returns the mesh indices a dimension cycles through; [code]-1[/code] stands for "none"
func _get_options(dimension: Array) -> Array[int]:
	var first_part: ModularCharacter.Part = dimension[0]
	var body_part: ModularBodyPart = _model.get_part(first_part)
	var options: Array[int] = []
	if body_part.allows_none(): options.append(-1)
	for mesh_index: int in body_part.get_mesh_count(): options.append(mesh_index)
	return options

func _count_combinations() -> int:
	if not _model or not _get_type(): return 0
	var count: int = 1
	for dimension: Array in _get_dimensions():
		count *= _get_options(dimension).size()
		if count > MAX_COMBINATIONS: return count
	return count

func _update_combinations_button() -> void:
	var count: int = _count_combinations()
	_combinations_button.disabled = count == 0
	_combinations_button.text = "Create Combinations (%s)" % (str(count) if count <= MAX_COMBINATIONS else "%d+" % MAX_COMBINATIONS)

func _on_combinations_pressed() -> void:
	var count: int = _count_combinations()
	if count > MAX_COMBINATIONS:
		_report_error("More than %d combinations; uncheck \"vary\" on some parts." % MAX_COMBINATIONS)
		return
	if count <= CONFIRM_COMBINATIONS:
		_create_combinations()
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Create up to %d %s items in %s?" % [count, _get_type().name, _get_item_path("").get_base_dir()]
	dialog.confirmed.connect(_create_combinations)
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

## Saves one item per combination of the varied parts' meshes; existing items are skipped
func _create_combinations() -> void:
	var dimensions: Array[Array] = _get_dimensions()
	var options: Array[Array] = []
	for dimension: Array in dimensions: options.append(_get_options(dimension))
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = {}
	for part: ModularCharacter.Part in _get_type().parts:
		var body_part: ModularBodyPart = _model.get_part(part)
		shown_meshes[part] = body_part.mesh if body_part.visible else null
	var counters: Array[int] = []
	counters.resize(dimensions.size())
	counters.fill(0)
	var saved_count: int = 0
	var skipped_count: int = 0
	while true:
		if _apply_combination(dimensions, options, counters):
			var item_name: String = _get_combination_name()
			var item_path: String = _get_item_path(item_name)
			var captured: EquipmentProfile = EquipmentProfile.from_model(_model, _get_type())
			if ResourceLoader.exists(item_path) or captured.appearance.parts.is_empty(): skipped_count += 1
			else:
				captured.name = item_name
				if not _write(captured, item_path): break
				saved_count += 1
		if not _advance(options, counters): break
	for part: ModularCharacter.Part in shown_meshes: _model.get_part(part).apply_mesh(shown_meshes[part] as ArrayMesh)
	_rebuild_parts()
	if saved_count > 0: equipment_saved.emit(null)
	_status_label.text = "Saved %d new items to %s, skipped %d existing or empty." % [saved_count, _get_item_path("").get_base_dir(), skipped_count]

## @returns [code]false[/code] if a right part has no mesh with the left part's index
func _apply_combination(dimensions: Array[Array], options: Array[Array], counters: Array[int]) -> bool:
	for dimension_index: int in dimensions.size():
		var mesh_index: int = options[dimension_index][counters[dimension_index]]
		for part: ModularCharacter.Part in dimensions[dimension_index]:
			var body_part: ModularBodyPart = _model.get_part(part)
			if mesh_index >= body_part.get_mesh_count(): return false
			body_part.update_index(mesh_index)
	return true

## Counts like an odometer over all dimensions
## @returns [code]false[/code] once every combination was visited
func _advance(options: Array[Array], counters: Array[int]) -> bool:
	for dimension_index: int in counters.size():
		counters[dimension_index] += 1
		if counters[dimension_index] < options[dimension_index].size(): return true
		counters[dimension_index] = 0
	return false

func _capture() -> EquipmentProfile:
	var captured: EquipmentProfile = EquipmentProfile.from_model(_model, _get_type())
	captured.name = _name_edit.text.strip_edges()
	return captured

func _save(equipment_profile: EquipmentProfile, item_path: String) -> bool:
	if not _write(equipment_profile, item_path): return false
	_status_label.text = "Saved %s with %d parts." % [item_path, equipment_profile.appearance.parts.size()]
	equipment_saved.emit(equipment_profile)
	return true

func _write(equipment_profile: EquipmentProfile, item_path: String) -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(item_path.get_base_dir())
	if directory_error != Error.OK:
		_report_error("Could not create %s: %s" % [item_path.get_base_dir(), error_string(directory_error)])
		return false
	var save_error: Error = ResourceSaver.save(equipment_profile, item_path)
	if save_error != Error.OK:
		_report_error("Could not save %s: %s" % [item_path, error_string(save_error)])
		return false
	EditorInterface.get_resource_filesystem().update_file(item_path)
	return true

func _report_error(message: String) -> void:
	_status_label.text = message
	push_error(message)

func _on_save_pressed() -> void:
	assert(_equipment_profile)
	if _name_edit.text.strip_edges().is_empty():
		_report_error("Set an item name before saving.")
		return
	var captured: EquipmentProfile = _capture()
	_equipment_profile.name = captured.name
	_equipment_profile.type = captured.type
	_equipment_profile.appearance = captured.appearance
	_save(_equipment_profile, _equipment_profile.resource_path)

## Saves to [code]data/equipment/<type>/<name>.tres[/code]; never overwrites an existing item
## An empty name falls back to the combination name, e.g. "Helmet 02 05"
func _on_save_as_new_pressed() -> void:
	if _name_edit.text.strip_edges().is_empty(): _name_edit.text = _get_combination_name()
	var item_path: String = _get_item_path(_name_edit.text.strip_edges())
	if ResourceLoader.exists(item_path):
		_report_error("%s already exists; pick another name." % item_path)
		return
	var captured: EquipmentProfile = _capture()
	if _save(captured, item_path): EditorInterface.get_inspector().edit(load(item_path))

func _on_edit_type_pressed() -> void:
	EditorInterface.get_inspector().edit(_get_type())

func _on_type_selected(_index: int) -> void:
	_update()

func _on_vary_toggled(_toggled_on: bool) -> void:
	_update_combinations_button()

func _on_gear_tab_visibility_changed() -> void:
	visible = _gear_tab.visible
	if not visible: return
	# Types may have been added or edited since the tab was last open
	_load_types()
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _show_item(equipment_profile: EquipmentProfile) -> void:
	_name_edit.text = equipment_profile.name
	if equipment_profile.type: _select_type(equipment_profile.type)

# The preview may report before this panel is ready; showing the Gear tab then catches up
func _on_active_profile_changed(active_profile: Profile) -> void:
	_equipment_profile = active_profile as EquipmentProfile
	if not _is_set_up or not visible: return
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _on_model_changed(model: Model) -> void:
	_model = model as ModularCharacter
	if _is_set_up and visible: _update()

func _on_model_removed() -> void:
	_model = null
	if _is_set_up and visible: _update()
