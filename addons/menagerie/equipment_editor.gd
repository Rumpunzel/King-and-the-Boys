@tool
extends PanelContainer

## Authors equipment: steps through a type's parts on the Menagerie preview and reviews its combinations into the type's
## [EquipmentCatalog] (allow / deny), or saves hand-made items as files of their own

signal equipment_saved(equipment_look: EquipmentLook)

const TYPE_DIRECTORY: String = "res://data/equipment/types"
const NO_MODEL_HINT: String = "Select an item, or a modular character to start from."
## Above this many combinations, reviewing refuses; uncheck "vary" on some parts instead
const MAX_COMBINATIONS: int = 5000
## Above this many, allowing all unreviewed combinations asks first
const CONFIRM_COMBINATIONS: int = 50

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _gear_tab: Control
@export var _type_option: OptionButton
@export var _edit_type_button: Button
@export var _type_info_label: Label
@export var _parts_container: VBoxContainer
@export var _review_status_label: Label
@export var _review_counts_label: Label
@export var _previous_button: Button
@export var _next_button: Button
@export var _allow_button: Button
@export var _deny_button: Button
@export var _undecide_button: Button
@export var _allow_rest_button: Button
@export var _name_edit: LineEdit
@export var _save_button: Button
@export var _save_as_new_button: Button
@export var _status_label: Label

var _model: ModularCharacter
## The item being edited, or [code]null[/code] when another profile is previewed
var _equipment_profile: EquipmentLook
## Indexed like the items of [member _type_option]
var _types: Array[EquipmentType] = []
## Parts whose meshes are varied when reviewing combinations
var _vary_check_boxes: Dictionary[ModularCharacter.Part, CheckBox] = {}
var _mesh_labels: Dictionary[ModularCharacter.Part, Label] = {}
var _is_set_up: bool = false

## The selected type's catalog; created on the first decision
var _catalog: EquipmentCatalog
## Every combination of the varied parts, built on demand: {counters: [Array] of [int], key: [String]}
var _review_combinations: Array[Dictionary] = []
var _review_dimensions: Array[Array] = []
var _review_options: Array[Array] = []
## Meshes shown when the review list was built; parts lacking a leader's number fall back to these
var _review_fallback: Dictionary[ModularCharacter.Part, Mesh] = {}
var _is_review_built: bool = false
var _review_index: int = -1

func _ready() -> void:
	# Do not bake generated items into this scene while it is edited itself
	if is_part_of_edited_scene(): return
	if _gear_tab: _gear_tab.visibility_changed.connect(_on_gear_tab_visibility_changed)
	_type_option.item_selected.connect(_on_type_selected)
	_edit_type_button.pressed.connect(_on_edit_type_pressed)
	_previous_button.pressed.connect(_show_next_unreviewed.bind(-1))
	_next_button.pressed.connect(_show_next_unreviewed.bind(1))
	_allow_button.pressed.connect(_on_allow_pressed)
	_deny_button.pressed.connect(_on_deny_pressed)
	_undecide_button.pressed.connect(_on_undecide_pressed)
	_allow_rest_button.pressed.connect(_on_allow_rest_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_save_as_new_button.pressed.connect(_on_save_as_new_pressed)
	_set_shortcut(_allow_button, KEY_A)
	_set_shortcut(_deny_button, KEY_D)
	_set_shortcut(_previous_button, KEY_LEFT)
	_set_shortcut(_next_button, KEY_RIGHT)
	_is_set_up = true
	_on_gear_tab_visibility_changed()

## Shortcuts only fire while the focus is inside this panel
func _set_shortcut(button: Button, keycode: Key) -> void:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key_event]
	button.shortcut = shortcut
	button.shortcut_context = self

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
	_catalog = EquipmentCatalog.find_for(equipment_type)
	_invalidate_review()
	_edit_type_button.disabled = not equipment_type
	_type_info_label.text = _describe(equipment_type)
	_save_button.disabled = not _model or not _equipment_profile or not equipment_type
	_save_as_new_button.disabled = not _model or not equipment_type
	_save_button.tooltip_text = "Overwrite %s" % _equipment_profile.resource_path if _equipment_profile else "Select an item in the Gear tab to overwrite it"
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
		_update_review()
		return
	if _status_label.text == NO_MODEL_HINT: _status_label.text = ""
	var equipment_type: EquipmentType = _get_type()
	if equipment_type:
		for part: ModularCharacter.Part in equipment_type.parts: _parts_container.add_child(_create_part_row(part))
	_update_review()

func _create_part_row(part: ModularCharacter.Part) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var part_name: String = ModularCharacter.Part.keys()[part]
	var vary_check_box: CheckBox = CheckBox.new()
	vary_check_box.button_pressed = true
	vary_check_box.tooltip_text = "Vary this part when reviewing combinations; unchecked parts keep the mesh shown"
	vary_check_box.toggled.connect(_on_vary_toggled)
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
	previous_button.pressed.connect(_step_part.bind(part, -1, mesh_label))
	next_button.pressed.connect(_step_part.bind(part, 1, mesh_label))
	for control: Control in [vary_check_box, name_label, previous_button, mesh_label, next_button]: row.add_child(control)
	_update_mesh_label(part, mesh_label)
	return row

## Steps through the part's mesh directory; decorative parts include "none"
## Linked parts follow to the same mesh number where they have it
func _step_part(part: ModularCharacter.Part, direction: int, _mesh_label: Label) -> void:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_count: int = body_part.get_mesh_count()
	if mesh_count == 0: return
	var lowest_index: int = -1 if body_part.allows_none() else 0
	var new_index: int = body_part.get_mesh_index() + direction
	if new_index < lowest_index: new_index = mesh_count - 1
	elif new_index >= mesh_count: new_index = lowest_index
	body_part.update_index(new_index)
	var mesh_number: String = _get_mesh_number(body_part)
	for linked_part: ModularCharacter.Part in _get_type().get_link_of(part):
		if linked_part != part: _show_mesh_number(linked_part, mesh_number)
	_review_index = -1
	_update_mesh_labels()
	_update_review()
	_status_label.text = ""

## Shows the mesh numbered [param mesh_number], or no mesh for [code]"none"[/code]
## @returns [code]false[/code] if the part has no such mesh
func _show_mesh_number(part: ModularCharacter.Part, mesh_number: String) -> bool:
	var body_part: ModularBodyPart = _model.get_part(part)
	var mesh_index: int = -1 if mesh_number == "none" else body_part.find_mesh_index(mesh_number)
	if mesh_index < 0 and (mesh_number != "none" or not body_part.allows_none()): return false
	body_part.update_index(mesh_index)
	return true

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

## @returns the trailing number of the shown mesh's file, such as [code]"05"[/code], or [code]"none"[/code]
static func _get_mesh_number(body_part: ModularBodyPart) -> String:
	if not body_part.visible or not body_part.mesh: return "none"
	return ModularBodyPart.get_mesh_number(body_part.mesh.resource_path)

## The key of the shown combination, see [method EquipmentType.get_combination_key]
func _get_combination_key() -> String:
	var part_numbers: Dictionary = {}
	for part: ModularCharacter.Part in _get_type().parts: part_numbers[part] = _get_mesh_number(_model.get_part(part))
	return _get_type().get_combination_key(part_numbers)

## The display name of the shown combination, e.g. "Helmet 02 05"
func _get_combination_name() -> String:
	return _get_type().get_combination_name(_get_combination_key())

func _get_item_path(item_name: String) -> String:
	return "%s/%s/%s.tres" % [EquipmentLook.ITEM_DIRECTORY, _get_type().name.to_snake_case(), item_name.to_snake_case()]

## Splits the varied parts into dimensions; linked parts (see [method EquipmentType.get_links]) form one
## @returns an [Array] of dimensions, each an [Array] of [enum ModularCharacter.Part]s
func _get_dimensions() -> Array[Array]:
	var dimensions: Array[Array] = []
	var assigned: Array[ModularCharacter.Part] = []
	for part: ModularCharacter.Part in _vary_check_boxes:
		if assigned.has(part) or not _vary_check_boxes[part].button_pressed: continue
		var dimension: Array[ModularCharacter.Part] = []
		for linked_part: ModularCharacter.Part in _get_type().get_link_of(part):
			if _vary_check_boxes.has(linked_part) and _vary_check_boxes[linked_part].button_pressed: dimension.append(linked_part)
		assigned.append_array(dimension)
		dimensions.append(dimension)
	return dimensions

## The first part of a dimension leads: its mesh numbers, plus [code]"none"[/code] if it allows that
func _get_options(dimension: Array) -> PackedStringArray:
	var leader: ModularCharacter.Part = dimension[0]
	var body_part: ModularBodyPart = _model.get_part(leader)
	var options: PackedStringArray = body_part.get_mesh_numbers()
	if body_part.allows_none(): options.insert(0, "none")
	return options

func _count_combinations() -> int:
	if not _model or not _get_type(): return 0
	var count: int = 1
	for dimension: Array in _get_dimensions():
		count *= _get_options(dimension).size()
		if count > MAX_COMBINATIONS: return count
	return count

## Linked parts follow their dimension's leader; a part lacking the leader's number shows its [param fallback_meshes] entry
## @returns [code]false[/code] if a leader cannot show its option
func _apply_combination(dimensions: Array[Array], options: Array[Array], counters: Array[int], fallback_meshes: Dictionary = {}) -> bool:
	for dimension_index: int in dimensions.size():
		var mesh_number: String = options[dimension_index][counters[dimension_index]]
		var dimension: Array = dimensions[dimension_index]
		for part_index: int in dimension.size():
			var part: ModularCharacter.Part = dimension[part_index]
			if _show_mesh_number(part, mesh_number): continue
			if part_index == 0: return false
			if fallback_meshes.has(part): _model.get_part(part).apply_mesh(fallback_meshes[part] as ArrayMesh)
	return true

## Counts like an odometer over all dimensions
## @returns [code]false[/code] once every combination was visited
func _advance(options: Array[Array], counters: Array[int]) -> bool:
	for dimension_index: int in counters.size():
		counters[dimension_index] += 1
		if counters[dimension_index] < options[dimension_index].size(): return true
		counters[dimension_index] = 0
	return false

func _invalidate_review() -> void:
	_is_review_built = false
	_review_combinations.clear()
	_review_index = -1

## Lists every combination of the varied parts with its key, skipping empty ones; restores the shown meshes afterwards
## @returns [code]false[/code] if there are too many
func _build_review() -> bool:
	if _is_review_built: return true
	if _count_combinations() > MAX_COMBINATIONS:
		_report_error("More than %d combinations; uncheck \"vary\" on some parts." % MAX_COMBINATIONS)
		return false
	_review_dimensions = _get_dimensions()
	_review_options.clear()
	for dimension: Array in _review_dimensions: _review_options.append(Array(_get_options(dimension)))
	_review_fallback = _get_shown_meshes()
	var counters: Array[int] = []
	counters.resize(_review_dimensions.size())
	counters.fill(0)
	_review_combinations.clear()
	while true:
		if _apply_combination(_review_dimensions, _review_options, counters, _review_fallback):
			var combination_key: String = _get_combination_key()
			if not _is_empty_key(combination_key): _review_combinations.append({counters = counters.duplicate(), key = combination_key})
		if not _advance(_review_options, counters): break
	_show_meshes(_review_fallback)
	_is_review_built = true
	return true

static func _is_empty_key(combination_key: String) -> bool:
	for number: String in combination_key.replace("-", " ").split(" "):
		if number != "none": return false
	return true

func _get_shown_meshes() -> Dictionary[ModularCharacter.Part, Mesh]:
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = {}
	for part: ModularCharacter.Part in _get_type().parts:
		var body_part: ModularBodyPart = _model.get_part(part)
		shown_meshes[part] = body_part.mesh if body_part.visible else null
	return shown_meshes

func _show_meshes(meshes: Dictionary[ModularCharacter.Part, Mesh]) -> void:
	for part: ModularCharacter.Part in meshes: _model.get_part(part).apply_mesh(meshes[part] as ArrayMesh)

func _show_review_combination(index: int) -> void:
	var combination: Dictionary = _review_combinations[index]
	var counters: Array[int] = []
	counters.assign(combination.counters)
	_apply_combination(_review_dimensions, _review_options, counters, _review_fallback)
	_review_index = index
	_update_mesh_labels()
	_update_review()

## Shows the next combination nobody decided on yet, going forward or back from the current one
func _show_next_unreviewed(direction: int) -> void:
	if not _model or not _get_type() or not _build_review(): return
	var count: int = _review_combinations.size()
	if count == 0: return
	var start: int = _review_index if _review_index >= 0 else (-1 if direction > 0 else 0)
	for step: int in range(1, count + 1):
		var index: int = posmod(start + step * direction, count)
		if _get_status(_review_combinations[index].key as String) == EquipmentCatalog.Status.UNREVIEWED:
			_show_review_combination(index)
			return
	_update_review()
	_status_label.text = "Every combination of the varied parts is decided."

func _get_status(combination_key: String) -> EquipmentCatalog.Status:
	return _catalog.get_status(combination_key) if _catalog else EquipmentCatalog.Status.UNREVIEWED

func _update_review() -> void:
	var can_review: bool = _model != null and _get_type() != null and not _vary_check_boxes.is_empty()
	for button: Button in [_previous_button, _next_button, _allow_button, _deny_button, _undecide_button, _allow_rest_button]: button.disabled = not can_review
	if not can_review:
		_review_status_label.text = ""
		_review_counts_label.text = ""
		return
	var combination_key: String = _get_combination_key()
	var status: EquipmentCatalog.Status = _get_status(combination_key)
	var status_name: String = EquipmentCatalog.Status.keys()[status]
	_review_status_label.text = "%s: %s" % [_get_type().get_combination_name(combination_key), status_name.capitalize()]
	_undecide_button.disabled = status == EquipmentCatalog.Status.UNREVIEWED
	var allowed_count: int = _catalog.entries.size() if _catalog else 0
	var denied_count: int = _catalog.denied.size() if _catalog else 0
	if not _is_review_built:
		_review_counts_label.text = "Allowed %d · Denied %d" % [allowed_count, denied_count]
		return
	var unreviewed_count: int = 0
	for combination: Dictionary in _review_combinations:
		if _get_status(combination.key as String) == EquipmentCatalog.Status.UNREVIEWED: unreviewed_count += 1
	_review_counts_label.text = "Allowed %d · Denied %d · Unreviewed %d of %d varied" % [allowed_count, denied_count, unreviewed_count, _review_combinations.size()]

## Decides the shown combination and moves on to the next unreviewed one
func _decide(allow: bool) -> void:
	var combination_key: String = _get_combination_key()
	if _is_empty_key(combination_key):
		_report_error("An empty combination cannot be an item.")
		return
	if not _catalog: _catalog = EquipmentCatalog.find_or_create(_get_type())
	if allow: _catalog.allow(EquipmentLook.from_model(_model, _get_type()), combination_key)
	else: _catalog.deny(combination_key)
	if not _save_catalog(): return
	_status_label.text = "%s %s." % [_get_type().get_combination_name(combination_key), "allowed" if allow else "denied"]
	_show_next_unreviewed(1)

func _save_catalog() -> bool:
	var catalog_path: String = _catalog.resource_path if not _catalog.resource_path.is_empty() else _catalog.get_default_path()
	if not _write(_catalog, catalog_path): return false
	equipment_saved.emit(null)
	return true

func _on_allow_pressed() -> void:
	_decide(true)

func _on_deny_pressed() -> void:
	_decide(false)

func _on_undecide_pressed() -> void:
	if not _catalog: return
	_catalog.undecide(_get_combination_key())
	_save_catalog()
	_update_review()

func _on_allow_rest_pressed() -> void:
	if not _build_review(): return
	var unreviewed: Array[Dictionary] = _review_combinations.filter(func(combination: Dictionary) -> bool: return _get_status(combination.key as String) == EquipmentCatalog.Status.UNREVIEWED)
	if unreviewed.is_empty(): return
	if unreviewed.size() <= CONFIRM_COMBINATIONS:
		_allow_all(unreviewed)
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Allow all %d unreviewed %s combinations?" % [unreviewed.size(), _get_type().name]
	dialog.confirmed.connect(_allow_all.bind(unreviewed))
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _allow_all(combinations: Array[Dictionary]) -> void:
	if not _catalog: _catalog = EquipmentCatalog.find_or_create(_get_type())
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = _get_shown_meshes()
	for combination: Dictionary in combinations:
		var counters: Array[int] = []
		counters.assign(combination.counters)
		_apply_combination(_review_dimensions, _review_options, counters, _review_fallback)
		_catalog.allow(EquipmentLook.from_model(_model, _get_type()), combination.key as String)
	_show_meshes(shown_meshes)
	if _save_catalog(): _status_label.text = "Allowed %d combinations." % combinations.size()
	_update_mesh_labels()
	_update_review()

func _capture() -> EquipmentLook:
	var captured: EquipmentLook = EquipmentLook.from_model(_model, _get_type())
	captured.name = _name_edit.text.strip_edges()
	return captured

func _save(equipment_look: EquipmentLook, item_path: String) -> bool:
	if not _write(equipment_look, item_path): return false
	_status_label.text = "Saved %s with %d parts." % [item_path, equipment_look.appearance.parts.size()]
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

## Overwrites the selected item; a catalog entry is saved with its catalog
func _on_save_pressed() -> void:
	assert(_equipment_profile)
	if _name_edit.text.strip_edges().is_empty():
		_report_error("Set an item name before saving.")
		return
	var captured: EquipmentLook = _capture()
	_equipment_profile.name = captured.name
	_equipment_profile.type = captured.type
	_equipment_profile.appearance = captured.appearance
	var item_path: String = _equipment_profile.resource_path
	if not item_path.contains(ResourceId.SEPARATOR):
		_save(_equipment_profile, item_path)
		return
	var catalog: EquipmentCatalog = load(item_path.get_slice(ResourceId.SEPARATOR, 0)) as EquipmentCatalog
	if not catalog or not _write(catalog, catalog.resource_path): return
	_status_label.text = "Saved %s in %s." % [_equipment_profile.name, catalog.resource_path]
	equipment_saved.emit(_equipment_profile)

## Saves a hand-made item to [code]data/equipment/<type>/<name>.tres[/code]; never overwrites an existing item
## An empty name falls back to the combination name, e.g. "Helmet 02 05"
func _on_save_as_new_pressed() -> void:
	if _name_edit.text.strip_edges().is_empty(): _name_edit.text = _get_combination_name()
	var item_path: String = _get_item_path(_name_edit.text.strip_edges())
	if ResourceLoader.exists(item_path):
		_report_error("%s already exists; pick another name." % item_path)
		return
	var captured: EquipmentLook = _capture()
	if _save(captured, item_path): EditorInterface.get_inspector().edit(load(item_path))

func _on_edit_type_pressed() -> void:
	EditorInterface.get_inspector().edit(_get_type())

func _on_type_selected(_index: int) -> void:
	_update()

func _on_vary_toggled(_toggled_on: bool) -> void:
	_invalidate_review()
	_update_review()

func _on_gear_tab_visibility_changed() -> void:
	# Without a Gear tab (e.g. in tests) the panel is always shown
	visible = _gear_tab.visible if _gear_tab else true
	if not visible: return
	# Types may have been added or edited since the tab was last open
	_load_types()
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _show_item(equipment_look: EquipmentLook) -> void:
	_name_edit.text = equipment_look.name
	if equipment_look.type: _select_type(equipment_look.type)

# The preview may report before this panel is ready; showing the Gear tab then catches up
func _on_active_profile_changed(active_profile: Profile) -> void:
	_equipment_profile = active_profile as EquipmentLook
	if not _is_set_up or not visible: return
	if _equipment_profile: _show_item(_equipment_profile)
	_update()

func _on_model_changed(model: Model) -> void:
	_model = model as ModularCharacter
	if _is_set_up and visible: _update()

func _on_model_removed() -> void:
	_model = null
	if _is_set_up and visible: _update()
