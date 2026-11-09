@tool
extends PanelContainer

## Dresses the character Menagerie previews: one row per slot with the kind of item in it and a carousel per linked group of
## parts (the base, then its attachment), stepping through the looks of the type's [EquipmentCatalog]
## Every change becomes the profile's starting look for that slot and is saved right away. Unchecked looks are offered too, greyed

const NO_PROFILE_HINT: String = "Select a character to dress it."
const UNCHECKED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)

@export_group("Configuration")
## This panel is only shown while this tab is open
@export var _characters_tab: Control
@export var _rows: GridContainer
@export var _status_label: Label

var _profile: CharacterProfile
var _types: Array[EquipmentType] = []
var _is_set_up: bool = false
var _is_update_queued: bool = false

func _ready() -> void:
	if _characters_tab: _characters_tab.visibility_changed.connect(_on_characters_tab_visibility_changed)
	_is_set_up = true
	_on_characters_tab_visibility_changed()

func _update() -> void:
	_is_update_queued = false
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_status_label.text = "" if _profile else NO_PROFILE_HINT
	if not _profile: return
	var blockers: Dictionary[EquipmentLook.Slot, EquipmentLook] = {}
	for equipment_look: EquipmentLook in _profile.get_starting_equipment():
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots: blockers[blocked_slot] = equipment_look
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		var slot_types: Array[EquipmentType] = []
		for equipment_type: EquipmentType in _types:
			if equipment_type.slot == slot: slot_types.append(equipment_type)
		if not slot_types.is_empty(): _add_row(slot, slot_types, blockers.get(slot) as EquipmentLook)

## Rows are rebuilt once per frame at most, also when the profile changes elsewhere, e.g. in the inspector
func _queue_update() -> void:
	if _is_update_queued: return
	_is_update_queued = true
	_update.call_deferred()

func _add_row(slot: EquipmentLook.Slot, slot_types: Array[EquipmentType], blocker: EquipmentLook) -> void:
	var slot_name: String = EquipmentLook.Slot.keys()[slot]
	var slot_label: Label = Label.new()
	slot_label.text = slot_name.capitalize()
	_rows.add_child(slot_label)

	var equipment_look: EquipmentLook = _profile.get_starting_equipment_for(slot)
	var type_option: OptionButton = OptionButton.new()
	type_option.add_item("None")
	for equipment_type: EquipmentType in slot_types:
		if equipment_type.icon: type_option.add_icon_item(equipment_type.icon, equipment_type.name)
		else: type_option.add_item(equipment_type.name)
		if not EquipmentCatalog.find_for(equipment_type): type_option.set_item_disabled(type_option.item_count - 1, true)
	type_option.select(slot_types.find(equipment_look.type) + 1 if equipment_look else 0)
	type_option.item_selected.connect(_on_type_selected.bind(slot, slot_types))
	_rows.add_child(type_option)

	var carousels: HBoxContainer = HBoxContainer.new()
	carousels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(carousels)
	if blocker:
		type_option.disabled = true
		var blocked_label: Label = Label.new()
		blocked_label.text = "Blocked by %s" % blocker.name
		blocked_label.modulate = UNCHECKED_COLOR
		carousels.add_child(blocked_label)
		return
	if not equipment_look: return
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(equipment_look.type)
	var is_catalog_look: bool = catalog != null and catalog.looks.has(equipment_look)
	var combination_key: String = EquipmentCatalog.get_key_of(equipment_look) if is_catalog_look else equipment_look.type.get_combination_key_of(equipment_look)
	var links: Array[Array] = equipment_look.type.get_key_links()
	for link_index: int in links.size():
		var leader: ModularCharacter.Part = links[link_index][0]
		carousels.add_child(_create_carousel(slot, catalog, combination_key, link_index, leader))
	if not equipment_look.allowed:
		carousels.modulate = UNCHECKED_COLOR
		carousels.tooltip_text = "%s is unchecked in its catalog." % equipment_look.name
	if not is_catalog_look: carousels.tooltip_text = "%s is hand-made; stepping picks catalog looks." % equipment_look.name

func _create_carousel(slot: EquipmentLook.Slot, catalog: EquipmentCatalog, combination_key: String, link_index: int, leader: ModularCharacter.Part) -> HBoxContainer:
	var carousel: HBoxContainer = HBoxContainer.new()
	var previous_button: Button = Button.new()
	previous_button.text = "<"
	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 190
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next_button: Button = Button.new()
	next_button.text = ">"
	var part_name: String = ModularCharacter.Part.keys()[leader]
	var mesh_number: String = combination_key.split(" ")[link_index]
	value_label.text = "%s %s" % [part_name.capitalize().trim_suffix(" Left"), mesh_number]
	if catalog:
		var options: PackedStringArray = catalog.get_options(combination_key, link_index)
		value_label.tooltip_text = "%d of %d" % [options.find(mesh_number) + 1, options.size()]
		previous_button.pressed.connect(_step.bind(slot, catalog, combination_key, link_index, -1))
		next_button.pressed.connect(_step.bind(slot, catalog, combination_key, link_index, 1))
	previous_button.disabled = not catalog
	next_button.disabled = not catalog
	for control: Control in [previous_button, value_label, next_button]: carousel.add_child(control)
	return carousel

func _step(slot: EquipmentLook.Slot, catalog: EquipmentCatalog, combination_key: String, link_index: int, direction: int) -> void:
	_set_look(slot, catalog.get_look(catalog.step(combination_key, link_index, direction)))

func _on_type_selected(index: int, slot: EquipmentLook.Slot, slot_types: Array[EquipmentType]) -> void:
	if index == 0:
		_set_look(slot, null)
		return
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(slot_types[index - 1])
	if catalog: _set_look(slot, catalog.get_look(catalog.get_first_key()))

## Like equipping in game, a look empties the slots it blocks
func _set_look(slot: EquipmentLook.Slot, equipment_look: EquipmentLook) -> void:
	_profile.set_starting_equipment_for(slot, equipment_look)
	if equipment_look:
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots: _profile.set_starting_equipment_for(blocked_slot, null)
	_save()

func _save() -> void:
	# Tests change cached profiles only; they restore them themselves
	if not Engine.is_editor_hint() or _profile.resource_path.is_empty() or _profile.resource_path.contains(ResourceId.SEPARATOR): return
	var error: Error = ResourceSaver.save(_profile, _profile.resource_path)
	if error != Error.OK:
		_status_label.text = "Could not save %s: %s" % [_profile.resource_path, error_string(error)]
		push_error(_status_label.text)
		return
	EditorInterface.get_resource_filesystem().update_file(_profile.resource_path)

func _on_characters_tab_visibility_changed() -> void:
	# Without a Characters tab (e.g. in tests) the panel is always shown
	visible = _characters_tab.visible if _characters_tab else true
	if not visible: return
	# Types may have been added or edited since the tab was last open
	_types = EquipmentType.find_all()
	_update()

# The preview may report before this panel is ready; showing the Characters tab then catches up
func _on_active_profile_changed(active_profile: Profile) -> void:
	if _profile and _profile.changed.is_connected(_queue_update): _profile.changed.disconnect(_queue_update)
	_profile = active_profile as CharacterProfile
	if _profile: _profile.changed.connect(_queue_update)
	if _is_set_up and visible: _update()
