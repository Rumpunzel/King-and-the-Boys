@tool
extends PanelContainer

## Authors looks: steps through a type's parts on the Menagerie preview, checks or unchecks the shown combination in the type's
## [EquipmentCatalog], adds missing combinations unchecked, or saves hand-made looks as files of their own

signal equipment_saved(equipment_look: EquipmentLook)
## The shown combination's look was checked or unchecked here
signal look_toggled(look: EquipmentLook)
## Looks were added to a catalog, so lists of looks need to be rebuilt
signal catalog_changed

const TYPE_DIRECTORY: String = "res://data/equipment/types"
const NO_MODEL_HINT: String = "Select a look, or a modular character to start from."

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _gear_tab: Control
@export var _type_option: OptionButton
@export var _edit_type_button: Button
@export var _type_info_label: Label
@export var _parts_container: VBoxContainer
@export var _allowed_check: CheckBox
@export var _look_label: Label
@export var _add_missing_button: Button
@export var _name_edit: LineEdit
@export var _save_button: Button
@export var _save_as_new_button: Button
@export var _status_label: Label

var _model: ModularCharacter
## The look being edited, or [code]null[/code] when another profile is previewed
var _equipment_look: EquipmentLook
## Indexed like the items of [member _type_option]
var _types: Array[EquipmentType] = []
## Parts varied when adding missing combinations
var _vary_check_boxes: Dictionary[ModularCharacter.Part, CheckBox] = {}
var _mesh_labels: Dictionary[ModularCharacter.Part, Label] = {}
var _is_set_up: bool = false
## The selected type's catalog, if it has one yet
var _catalog: EquipmentCatalog

func _ready() -> void:
	# Do not bake generated items into this scene while it is edited itself
	if is_part_of_edited_scene(): return
	if _gear_tab: _gear_tab.visibility_changed.connect(_on_gear_tab_visibility_changed)
	_type_option.item_selected.connect(_on_type_selected)
	_edit_type_button.pressed.connect(_on_edit_type_pressed)
	_allowed_check.toggled.connect(_on_allowed_toggled)
	_add_missing_button.pressed.connect(_on_add_missing_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_save_as_new_button.pressed.connect(_on_save_as_new_pressed)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_A
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key_event]
	_allowed_check.shortcut = shortcut
	_allowed_check.shortcut_context = self
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

## Combinations of the selected type on the preview, varying the checked parts
func _get_combinations() -> EquipmentCombinations:
	var combinations: EquipmentCombinations = EquipmentCombinations.new(_get_type(), _model)
	combinations.varied_parts.clear()
	for part: ModularCharacter.Part in _vary_check_boxes:
		if _vary_check_boxes[part].button_pressed: combinations.varied_parts.append(part)
	return combinations

func _update() -> void:
	var equipment_type: EquipmentType = _get_type()
	_catalog = EquipmentCatalog.find_for(equipment_type)
	_edit_type_button.disabled = not equipment_type
	_type_info_label.text = _describe(equipment_type)
	_save_button.disabled = not _model or not _equipment_look or not equipment_type
	_save_as_new_button.disabled = not _model or not equipment_type
	_save_button.tooltip_text = "Overwrite %s" % _equipment_look.resource_path if _equipment_look else "Select a look in the Gear tab to overwrite it"
	_rebuild_parts()

func _describe(equipment_type: EquipmentType) -> String:
	if not equipment_type: return "Create an EquipmentType in %s first." % TYPE_DIRECTORY
	var slot_name: String = EquipmentLook.Slot.keys()[equipment_type.slot]
	var blocked_names: PackedStringArray = []
	for blocked_slot: EquipmentLook.Slot in equipment_type.blocked_slots:
		var blocked_name: String = EquipmentLook.Slot.keys()[blocked_slot]
		blocked_names.append(blocked_name.capitalize())
	var description: String = "Slot: %s" % slot_name.capitalize()
	if not blocked_names.is_empty(): description += "   Blocks: %s" % ", ".join(blocked_names)
	return description

func _rebuild_parts() -> void:
	for child: Node in _parts_container.get_children():
		_parts_container.remove_child(child)
		child.queue_free()
	_vary_check_boxes.clear()
	_mesh_labels.clear()
	if not _model:
		_status_label.text = NO_MODEL_HINT
		_update_look_row()
		return
	if _status_label.text == NO_MODEL_HINT: _status_label.text = ""
	var equipment_type: EquipmentType = _get_type()
	if equipment_type:
		for part: ModularCharacter.Part in equipment_type.parts: _parts_container.add_child(_create_part_row(part))
	_update_look_row()

func _create_part_row(part: ModularCharacter.Part) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var part_name: String = ModularCharacter.Part.keys()[part]
	var vary_check_box: CheckBox = CheckBox.new()
	vary_check_box.button_pressed = true
	vary_check_box.tooltip_text = "Vary this part when adding missing combinations; unchecked parts keep the mesh shown"
	_vary_check_boxes[part] = vary_check_box
	var name_label: Label = Label.new()
	name_label.text = part_name.capitalize()
	name_label.custom_minimum_size.x = 200
	var previous_button: Button = Button.new()
	previous_button.text = "<"
	var mesh_label: Label = Label.new()
	_mesh_labels[part] = mesh_label
	mesh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mesh_label.clip_text = true
	var next_button: Button = Button.new()
	next_button.text = ">"
	previous_button.pressed.connect(_step_part.bind(part, -1))
	next_button.pressed.connect(_step_part.bind(part, 1))
	for control: Control in [vary_check_box, name_label, previous_button, mesh_label, next_button]: row.add_child(control)
	_update_mesh_label(part, mesh_label)
	return row

## Steps through the part's mesh directory; decorative parts include showing no mesh
## Linked parts follow to the same mesh number where they have it
func _step_part(part: ModularCharacter.Part, direction: int) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_count: int = body_part.get_mesh_count()
	if mesh_count == 0: return
	var lowest_index: int = -1 if body_part.allows_none() else 0
	var new_index: int = body_part.get_mesh_index() + direction
	if new_index < lowest_index: new_index = mesh_count - 1
	elif new_index >= mesh_count: new_index = lowest_index
	body_part.update_index(new_index)
	var combinations: EquipmentCombinations = _get_combinations()
	var mesh_number: String = EquipmentCombinations.get_mesh_number(body_part)
	for linked_part: ModularCharacter.Part in _get_type().get_link_of(part):
		if linked_part != part: combinations.show_mesh_number(linked_part, mesh_number)
	_update_mesh_labels()
	_update_look_row()
	_status_label.text = ""

func _update_mesh_labels() -> void:
	for part: ModularCharacter.Part in _mesh_labels: _update_mesh_label(part, _mesh_labels[part])

func _update_mesh_label(part: ModularCharacter.Part, mesh_label: Label) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_index: int = body_part.get_mesh_index()
	if not body_part.visible or not body_part.mesh:
		mesh_label.text = "none"
		return
	var mesh_name: String = body_part.mesh.resource_path.get_file().get_basename().trim_prefix("modular_character_")
	mesh_label.text = "%s  (%d/%d)" % [mesh_name, mesh_index + 1, body_part.get_mesh_count()]
	mesh_label.tooltip_text = body_part.mesh.resource_path

## The key of the shown combination, see [method EquipmentType.get_combination_key]
func _get_combination_key() -> String:
	return _get_combinations().get_shown_key()

## The display name of the shown combination, e.g. "Helmet 02 05"
func _get_combination_name() -> String:
	return _get_type().get_combination_name(_get_combination_key())

func _get_item_path(look_name: String) -> String:
	return "%s/%s/%s.tres" % [EquipmentLook.ITEM_DIRECTORY, _get_type().name.to_snake_case(), look_name.to_snake_case()]

## The catalog look of the shown combination, or [code]null[/code] if the catalog lacks it
func _get_shown_look() -> EquipmentLook:
	return _catalog.get_look(_get_combination_key()) if _catalog else null

func _update_look_row() -> void:
	var can_decide: bool = _model != null and _get_type() != null and not _vary_check_boxes.is_empty()
	_allowed_check.disabled = not can_decide
	_add_missing_button.disabled = not can_decide
	if not can_decide:
		_look_label.text = ""
		_allowed_check.set_pressed_no_signal(false)
		return
	var combination_key: String = _get_combination_key()
	var look: EquipmentLook = _get_shown_look()
	_allowed_check.set_pressed_no_signal(look != null and look.allowed)
	_allowed_check.disabled = EquipmentCombinations.is_empty_key(combination_key)
	_look_label.text = _get_type().get_combination_name(combination_key) + ("" if look else "  (not in the catalog yet)")

## Shows a look's flag after it changed elsewhere, e.g. in the Gear tab
func update_look(look: EquipmentLook) -> void:
	if _is_set_up and _model and _get_type() and look == _get_shown_look(): _update_look_row()

## Checking or unchecking the shown combination; a combination the catalog lacks is added
func _on_allowed_toggled(allowed: bool) -> void:
	var combination_key: String = _get_combination_key()
	if EquipmentCombinations.is_empty_key(combination_key): return
	var is_new_catalog: bool = _ensure_catalog()
	var look: EquipmentLook = _catalog.get_look(combination_key)
	var is_new_look: bool = look == null
	if is_new_look:
		look = EquipmentLook.from_model(_model, _get_type())
		_catalog.add(look, combination_key, allowed)
	else:
		look.allowed = allowed
	CatalogSaver.mark_dirty(_catalog)
	_update_look_row()
	if is_new_catalog or is_new_look:
		CatalogSaver.flush()
		catalog_changed.emit()
	else:
		look_toggled.emit(look)

## A type's first catalog is saved right away, so it has a path; later changes are saved in batches by [CatalogSaver]
## @returns whether a catalog was created
func _ensure_catalog() -> bool:
	if _catalog: return false
	_catalog = EquipmentCatalog.find_or_create(_get_type())
	if not _catalog.resource_path.is_empty(): return false
	_write(_catalog, _catalog.get_default_path())
	_catalog.take_over_path(_catalog.get_default_path())
	return true

## Adds every combination of the varied parts the catalog lacks, unchecked, so nothing new slips in unseen
func _on_add_missing_pressed() -> void:
	var combinations: EquipmentCombinations = _get_combinations()
	if combinations.count() > EquipmentCombinations.MAX_COMBINATIONS:
		_report_error("More than %d combinations; uncheck \"vary\" on some parts." % EquipmentCombinations.MAX_COMBINATIONS)
		return
	_ensure_catalog()
	var added: int = _catalog.add_missing(combinations)
	_update_mesh_labels()
	_update_look_row()
	if added == 0:
		_status_label.text = "The catalog already has every combination of the varied parts."
		return
	CatalogSaver.mark_dirty(_catalog)
	CatalogSaver.flush()
	_status_label.text = "Added %d unchecked looks to %s." % [added, _catalog.resource_path]
	catalog_changed.emit()

func _capture() -> EquipmentLook:
	var captured: EquipmentLook = EquipmentLook.from_model(_model, _get_type())
	captured.name = _name_edit.text.strip_edges()
	return captured

func _save(equipment_look: EquipmentLook, look_path: String) -> bool:
	if not _write(equipment_look, look_path): return false
	_status_label.text = "Saved %s with %d parts." % [look_path, equipment_look.appearance.parts.size()]
	equipment_saved.emit(equipment_look)
	return true

func _write(resource: Resource, path: String) -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != Error.OK:
		_report_error("Could not create %s: %s" % [path.get_base_dir(), error_string(directory_error)])
		return false
	var save_error: Error = ResourceSaver.save(resource, path)
	if save_error != Error.OK:
		_report_error("Could not save %s: %s" % [path, error_string(save_error)])
		return false
	EditorInterface.get_resource_filesystem().update_file(path)
	return true

func _report_error(message: String) -> void:
	_status_label.text = message
	push_error(message)

## Overwrites the selected look; a catalog look is saved with its catalog
func _on_save_pressed() -> void:
	assert(_equipment_look)
	if _name_edit.text.strip_edges().is_empty():
		_report_error("Set a name before saving.")
		return
	var captured: EquipmentLook = _capture()
	_equipment_look.name = captured.name
	_equipment_look.type = captured.type
	_equipment_look.appearance = captured.appearance
	var catalog: EquipmentCatalog = CatalogSaver.get_catalog_of(_equipment_look)
	if not catalog:
		_save(_equipment_look, _equipment_look.resource_path)
		return
	CatalogSaver.mark_dirty(catalog)
	_status_label.text = "Changed %s in %s." % [_equipment_look.name, catalog.resource_path]
	equipment_saved.emit(_equipment_look)

## Saves a hand-made look to [code]data/equipment/<type>/<name>.tres[/code]; never overwrites an existing file
## An empty name falls back to the combination name, e.g. "Helmet 02 05"
func _on_save_as_new_pressed() -> void:
	if _name_edit.text.strip_edges().is_empty(): _name_edit.text = _get_combination_name()
	var look_path: String = _get_item_path(_name_edit.text.strip_edges())
	if ResourceLoader.exists(look_path):
		_report_error("%s already exists; pick another name." % look_path)
		return
	var captured: EquipmentLook = _capture()
	if _save(captured, look_path): EditorInterface.get_inspector().edit(load(look_path))

func _on_edit_type_pressed() -> void:
	EditorInterface.get_inspector().edit(_get_type())

func _on_type_selected(_index: int) -> void:
	_update()

func _on_gear_tab_visibility_changed() -> void:
	# Without a Gear tab (e.g. in tests) the panel is always shown
	visible = _gear_tab.visible if _gear_tab else true
	if not visible: return
	# Types may have been added or edited since the tab was last open
	_load_types()
	if _equipment_look: _show_look(_equipment_look)
	_update()

func _show_look(equipment_look: EquipmentLook) -> void:
	_name_edit.text = equipment_look.name
	if equipment_look.type: _select_type(equipment_look.type)

# The preview may report before this panel is ready; showing the Gear tab then catches up
func _on_active_profile_changed(active_profile: Profile) -> void:
	_equipment_look = active_profile as EquipmentLook
	if not _is_set_up or not visible: return
	if _equipment_look: _show_look(_equipment_look)
	_update()

func _on_model_changed(model: Model) -> void:
	_model = model as ModularCharacter
	if _is_set_up and visible: _update()

func _on_model_removed() -> void:
	_model = null
	if _is_set_up and visible: _update()
