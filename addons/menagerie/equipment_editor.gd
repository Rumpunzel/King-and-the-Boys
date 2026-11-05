@tool
extends PanelContainer

signal equipment_saved(equipment_profile: EquipmentProfile)

const ITEM_DIRECTORY: String = "res://data/equipment"

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _gear_tab: Control
@export var _slot_option: OptionButton
@export var _blocked_slots_container: HFlowContainer
@export var _parts_container: VBoxContainer
@export var _name_edit: LineEdit
@export var _save_button: Button
@export var _save_as_new_button: Button
@export var _status_label: Label

var _model: ModularCharacter
## The item being edited, or [code]null[/code] when another profile is previewed
var _equipment_profile: EquipmentProfile
var _blocked_check_boxes: Dictionary[EquipmentProfile.Slot, CheckBox] = {}

func _ready() -> void:
	# Do not bake generated items into this scene while it is edited itself
	if is_part_of_edited_scene(): return
	_gear_tab.visibility_changed.connect(_on_gear_tab_visibility_changed)
	_on_gear_tab_visibility_changed()
	for slot: EquipmentProfile.Slot in EquipmentProfile.Slot.values():
		var slot_name: String = EquipmentProfile.Slot.keys()[slot]
		_slot_option.add_item(slot_name.capitalize(), slot)
		var check_box: CheckBox = CheckBox.new()
		check_box.text = slot_name.capitalize()
		check_box.toggled.connect(_on_blocked_slot_toggled)
		_blocked_slots_container.add_child(check_box)
		_blocked_check_boxes[slot] = check_box
	_slot_option.item_selected.connect(_on_slot_selected)
	_save_button.pressed.connect(_on_save_pressed)
	_save_as_new_button.pressed.connect(_on_save_as_new_pressed)
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _get_slot() -> EquipmentProfile.Slot:
	return _slot_option.get_selected_id() as EquipmentProfile.Slot

func _get_blocked_slots() -> Array[EquipmentProfile.Slot]:
	var blocked_slots: Array[EquipmentProfile.Slot] = []
	for slot: EquipmentProfile.Slot in _blocked_check_boxes:
		if _blocked_check_boxes[slot].button_pressed and slot != _get_slot(): blocked_slots.append(slot)
	return blocked_slots

func _show_item(equipment_profile: EquipmentProfile) -> void:
	_name_edit.text = equipment_profile.name
	_slot_option.select(_slot_option.get_item_index(equipment_profile.slot))
	for slot: EquipmentProfile.Slot in _blocked_check_boxes:
		_blocked_check_boxes[slot].set_pressed_no_signal(equipment_profile.blocked_slots.has(slot))

func _update() -> void:
	for slot: EquipmentProfile.Slot in _blocked_check_boxes:
		_blocked_check_boxes[slot].disabled = slot == _get_slot()
	_save_button.disabled = not _model or not _equipment_profile
	_save_as_new_button.disabled = not _model
	_save_button.tooltip_text = "Overwrite %s" % _equipment_profile.resource_path if _equipment_profile else "Select an item in the Gear tab to overwrite it"
	_rebuild_parts()

func _rebuild_parts() -> void:
	for child: Node in _parts_container.get_children():
		_parts_container.remove_child(child)
		child.queue_free()
	if not _model:
		_status_label.text = "Select a modular character or an item to author equipment."
		return
	for part: ModularCharacter.Part in EquipmentProfile.get_parts_for(_get_slot(), _get_blocked_slots()):
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
	previous_button.pressed.connect(_step_part.bind(part, -1, mesh_label))
	next_button.pressed.connect(_step_part.bind(part, 1, mesh_label))
	for control: Control in [name_label, previous_button, mesh_label, next_button]: row.add_child(control)
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

func _capture() -> EquipmentProfile:
	var captured: EquipmentProfile = EquipmentProfile.from_model(_model, _get_slot(), _get_blocked_slots())
	captured.name = _name_edit.text.strip_edges()
	return captured

func _save(equipment_profile: EquipmentProfile, item_path: String) -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(item_path.get_base_dir())
	if directory_error != Error.OK:
		_report_error("Could not create %s: %s" % [item_path.get_base_dir(), error_string(directory_error)])
		return false
	var save_error: Error = ResourceSaver.save(equipment_profile, item_path)
	if save_error != Error.OK:
		_report_error("Could not save %s: %s" % [item_path, error_string(save_error)])
		return false
	EditorInterface.get_resource_filesystem().update_file(item_path)
	_status_label.text = "Saved %s with %d parts." % [item_path, equipment_profile.appearance.parts.size()]
	equipment_saved.emit(equipment_profile)
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
	_equipment_profile.slot = captured.slot
	_equipment_profile.blocked_slots = captured.blocked_slots
	_equipment_profile.appearance = captured.appearance
	_save(_equipment_profile, _equipment_profile.resource_path)

## Never overwrites an existing item
func _on_save_as_new_pressed() -> void:
	var item_name: String = _name_edit.text.strip_edges()
	if item_name.is_empty():
		_report_error("Set an item name before saving.")
		return
	var slot_name: String = EquipmentProfile.Slot.keys()[_get_slot()]
	var item_path: String = "%s/%s/%s.tres" % [ITEM_DIRECTORY, slot_name.to_lower(), item_name.to_snake_case()]
	if ResourceLoader.exists(item_path):
		_report_error("%s already exists; pick another name." % item_path)
		return
	var captured: EquipmentProfile = _capture()
	if _save(captured, item_path): EditorInterface.get_inspector().edit(load(item_path))

func _on_slot_selected(_index: int) -> void:
	_update()

func _on_blocked_slot_toggled(_toggled_on: bool) -> void:
	_rebuild_parts()

# The preview may report before this panel is ready; [method _ready] then catches up
func _on_active_profile_changed(active_profile: Profile) -> void:
	_equipment_profile = active_profile as EquipmentProfile
	if not _is_set_up(): return
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _on_model_changed(model: Model) -> void:
	_model = model as ModularCharacter
	if _is_set_up(): _update()

func _on_model_removed() -> void:
	_model = null
	if _is_set_up(): _update()

func _is_set_up() -> bool: return not _blocked_check_boxes.is_empty()

func _on_gear_tab_visibility_changed() -> void:
	visible = _gear_tab.visible
