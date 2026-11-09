@tool
class_name EquipmentSlotProperty
extends EditorProperty

## Dresses one starting equipment slot of a [CharacterProfile]: a dropdown for the kind of item, then one carousel per linked
## group of parts (the base, then its attachment) stepping through the looks of the type's [EquipmentCatalog]
## Changes go through the inspector, so they can be undone and are saved with the profile. Unchecked looks are offered, greyed

const UNCHECKED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)

var _slot: EquipmentLook.Slot
var _slot_types: Array[EquipmentType] = []
var _type_option: OptionButton = OptionButton.new()
var _clear_button: Button = Button.new()
var _carousels: VBoxContainer = VBoxContainer.new()
var _is_refresh_queued: bool = false

func _init(slot: EquipmentLook.Slot) -> void:
	_slot = slot
	_slot_types = get_slot_types(slot)
	var row: HBoxContainer = HBoxContainer.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.clip_text = true
	_type_option.add_item("None")
	for equipment_type: EquipmentType in _slot_types:
		if equipment_type.icon: _type_option.add_icon_item(equipment_type.icon, equipment_type.name)
		else: _type_option.add_item(equipment_type.name)
		if not EquipmentCatalog.find_for(equipment_type): _type_option.set_item_disabled(_type_option.item_count - 1, true)
	_type_option.item_selected.connect(_on_type_selected)
	_clear_button.text = "✕"
	_clear_button.tooltip_text = "Empty this slot"
	_clear_button.pressed.connect(_set_look.bind(null))
	row.add_child(_type_option)
	row.add_child(_clear_button)
	add_child(row)
	add_focusable(_type_option)
	add_focusable(_clear_button)
	add_child(_carousels)
	set_bottom_editor(_carousels)

## The types that go into [param slot]
static func get_slot_types(slot: EquipmentLook.Slot) -> Array[EquipmentType]:
	var slot_types: Array[EquipmentType] = []
	for equipment_type: EquipmentType in EquipmentType.find_all():
		if equipment_type.slot == slot: slot_types.append(equipment_type)
	return slot_types

## The key a catalog look is stored under, or the key of the combination a hand-made look shows
static func get_key(equipment_look: EquipmentLook) -> String:
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(equipment_look.type)
	if catalog and catalog.looks.has(equipment_look): return EquipmentCatalog.get_key_of(equipment_look)
	return equipment_look.type.get_combination_key_of(equipment_look)

## The starting look of [param profile] that blocks [param slot], if any
static func get_blocker(profile: CharacterProfile, slot: EquipmentLook.Slot) -> EquipmentLook:
	for equipment_look: EquipmentLook in profile.get_starting_equipment():
		if equipment_look.blocked_slots.has(slot): return equipment_look
	return null

## The first allowed look of [param equipment_type]'s catalog, or [code]null[/code] without a catalog
static func get_first_look(equipment_type: EquipmentType) -> EquipmentLook:
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(equipment_type)
	return catalog.get_look(catalog.get_first_key()) if catalog else null

## The look one option further along the [param link_index]th link, see [method EquipmentCatalog.step]
static func step_look(equipment_look: EquipmentLook, link_index: int, direction: int) -> EquipmentLook:
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(equipment_look.type)
	if not catalog: return null
	return catalog.get_look(catalog.step(get_key(equipment_look), link_index, direction))

## A carousel's text, e.g. "Helmet Attachment 05": the link's first part without its side, and its number
static func describe_link(equipment_look: EquipmentLook, link_index: int) -> String:
	var leader: ModularCharacter.Part = equipment_look.type.get_key_links()[link_index][0]
	var part_name: String = ModularCharacter.Part.keys()[leader]
	return "%s %s" % [part_name.capitalize().trim_suffix(" Left"), get_key(equipment_look).split(" ")[link_index]]

func _update_property() -> void:
	var profile: CharacterProfile = get_edited_object()
	# Other slots change whether this one is blocked
	if not profile.changed.is_connected(_queue_refresh): profile.changed.connect(_queue_refresh)
	_refresh()

func _exit_tree() -> void:
	var profile: CharacterProfile = get_edited_object() as CharacterProfile
	if profile and profile.changed.is_connected(_queue_refresh): profile.changed.disconnect(_queue_refresh)

## The slot stores a [ResourceId]
func _get_current() -> EquipmentLook:
	var equipment_id: String = get_edited_object().get(get_edited_property())
	return ResourceId.find(equipment_id) as EquipmentLook

func _queue_refresh() -> void:
	if _is_refresh_queued: return
	_is_refresh_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_is_refresh_queued = false
	var profile: CharacterProfile = get_edited_object() as CharacterProfile
	if not profile: return
	var equipment_look: EquipmentLook = _get_current()
	var blocker: EquipmentLook = get_blocker(profile, _slot)
	_type_option.select(_slot_types.find(equipment_look.type) + 1 if equipment_look else 0)
	_type_option.disabled = blocker != null
	_clear_button.disabled = not equipment_look
	for child: Node in _carousels.get_children():
		_carousels.remove_child(child)
		child.queue_free()
	_carousels.modulate = Color.WHITE
	_carousels.tooltip_text = ""
	if blocker:
		var blocked_label: Label = Label.new()
		blocked_label.text = "Blocked by %s" % blocker.name
		blocked_label.modulate = UNCHECKED_COLOR
		_carousels.add_child(blocked_label)
		return
	if not equipment_look or not equipment_look.type: return
	for link_index: int in equipment_look.type.get_key_links().size(): _carousels.add_child(_create_carousel(equipment_look, link_index))
	if not equipment_look.allowed:
		_carousels.modulate = UNCHECKED_COLOR
		_carousels.tooltip_text = "%s is unchecked in its catalog." % equipment_look.name

func _create_carousel(equipment_look: EquipmentLook, link_index: int) -> HBoxContainer:
	var carousel: HBoxContainer = HBoxContainer.new()
	var previous_button: Button = Button.new()
	previous_button.text = "<"
	previous_button.pressed.connect(_step.bind(equipment_look, link_index, -1))
	var value_label: Label = Label.new()
	value_label.text = describe_link(equipment_look, link_index)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	var next_button: Button = Button.new()
	next_button.text = ">"
	next_button.pressed.connect(_step.bind(equipment_look, link_index, 1))
	for control: Control in [previous_button, value_label, next_button]: carousel.add_child(control)
	return carousel

func _step(equipment_look: EquipmentLook, link_index: int, direction: int) -> void:
	var stepped: EquipmentLook = step_look(equipment_look, link_index, direction)
	if stepped: _set_look(stepped)

func _on_type_selected(index: int) -> void:
	_set_look(get_first_look(_slot_types[index - 1]) if index > 0 else null)

## Like equipping in game, a look empties the slots it blocks
func _set_look(equipment_look: EquipmentLook) -> void:
	var profile: CharacterProfile = get_edited_object()
	if equipment_look:
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots:
			if not profile.get_starting_equipment_id(blocked_slot).is_empty(): emit_changed(CharacterProfile.get_slot_property(blocked_slot), "")
	emit_changed(get_edited_property(), ResourceId.of(equipment_look) if equipment_look else "")
