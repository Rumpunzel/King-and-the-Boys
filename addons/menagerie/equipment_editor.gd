@tool
extends PanelContainer

signal equipment_saved(equipment_profile: EquipmentProfile)

const ITEM_DIRECTORY: String = "res://data/equipment"
const TYPE_DIRECTORY: String = "res://data/equipment/types"
const NO_MODEL_HINT: String = "Select an item, or a modular character to start from."

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _gear_tab: Control
@export var _type_option: OptionButton
@export var _edit_type_button: Button
@export var _type_info_label: Label
@export var _parts_container: VBoxContainer
@export var _name_edit: LineEdit
@export var _save_button: Button
@export var _save_as_new_button: Button
@export var _status_label: Label

var _model: ModularCharacter
## The item being edited, or [code]null[/code] when another profile is previewed
var _equipment_profile: EquipmentProfile
## Indexed like the items of [member _type_option]
var _types: Array[EquipmentType] = []
var _is_set_up: bool = false

func _ready() -> void:
	# Do not bake generated items into this scene while it is edited itself
	if is_part_of_edited_scene(): return
	_gear_tab.visibility_changed.connect(_on_gear_tab_visibility_changed)
	_type_option.item_selected.connect(_on_type_selected)
	_edit_type_button.pressed.connect(_on_edit_type_pressed)
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
	if not _model:
		_status_label.text = NO_MODEL_HINT
		return
	if _status_label.text == NO_MODEL_HINT: _status_label.text = ""
	var equipment_type: EquipmentType = _get_type()
	if not equipment_type: return
	for part: ModularCharacter.Part in equipment_type.parts:
		_parts_container.add_child(_create_part_row(part))

func _create_part_row(part: ModularCharacter.Part) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var part_name: String = ModularCharacter.Part.keys()[part]
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
	var batch_button: Button = Button.new()
	batch_button.text = "One per mesh"
	batch_button.tooltip_text = "Save one new item for every mesh of this part, keeping the other parts as shown"
	previous_button.pressed.connect(_step_part.bind(part, -1, mesh_label))
	next_button.pressed.connect(_step_part.bind(part, 1, mesh_label))
	batch_button.pressed.connect(_on_one_per_mesh_pressed.bind(part, mesh_label))
	for control: Control in [name_label, previous_button, mesh_label, next_button, batch_button]: row.add_child(control)
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
	mesh_label.text = "%s  (%d/%d)" % [_get_mesh_name(body_part.mesh), mesh_index + 1, body_part.get_mesh_count()]
	mesh_label.tooltip_text = body_part.mesh.resource_path

static func _get_mesh_name(mesh: Mesh) -> String:
	return mesh.resource_path.get_file().get_basename().trim_prefix("modular_character_")

func _get_item_path(item_name: String) -> String:
	return "%s/%s/%s.tres" % [ITEM_DIRECTORY, _get_type().name.to_snake_case(), item_name.to_snake_case()]

## Saves one item per mesh in [param part]'s directory, named after the mesh; existing items are skipped
func _on_one_per_mesh_pressed(part: ModularCharacter.Part, mesh_label: Label) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var original_index: int = body_part.get_mesh_index()
	var saved_count: int = 0
	var skipped_count: int = 0
	for mesh_index: int in body_part.get_mesh_count():
		body_part.update_index(mesh_index)
		var item_name: String = _get_mesh_name(body_part.mesh)
		var item_path: String = _get_item_path(item_name)
		if ResourceLoader.exists(item_path):
			skipped_count += 1
			continue
		var captured: EquipmentProfile = EquipmentProfile.from_model(_model, _get_type())
		captured.name = item_name
		if not _write(captured, item_path): break
		saved_count += 1
	body_part.update_index(original_index)
	_update_mesh_label(part, mesh_label)
	if saved_count > 0: equipment_saved.emit(null)
	_status_label.text = "Saved %d new items to %s, skipped %d existing." % [saved_count, _get_item_path("").get_base_dir(), skipped_count]

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
func _on_save_as_new_pressed() -> void:
	var item_name: String = _name_edit.text.strip_edges()
	if item_name.is_empty():
		_report_error("Set an item name before saving.")
		return
	var item_path: String = _get_item_path(item_name)
	if ResourceLoader.exists(item_path):
		_report_error("%s already exists; pick another name." % item_path)
		return
	var captured: EquipmentProfile = _capture()
	if _save(captured, item_path): EditorInterface.get_inspector().edit(load(item_path))

func _on_edit_type_pressed() -> void:
	EditorInterface.get_inspector().edit(_get_type())

func _on_type_selected(_index: int) -> void:
	_update()

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
