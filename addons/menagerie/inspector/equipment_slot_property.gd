@tool
class_name EquipmentSlotProperty
extends EditorProperty

## Dresses one starting equipment slot of a [CharacterProfile]: a dropdown for the kind of item (only types made for the profile's
## models, e.g. dwarf gear for dwarves), then a carousel per part of that
## type stepping through the part's meshes. Left and right parts share a carousel until split, so the sides can differ
## Choosing a type starts from its catalog's first look; every change stores a copy in the profile (see [method EquipmentLook.with_part_mesh])
## Changes go through the inspector, so they can be undone and are saved with the profile

const BLOCKED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)

var _slot: EquipmentLook.Slot
var _slot_types: Array[EquipmentType] = []
var _type_option: OptionButton = OptionButton.new()
var _clear_button: Button = Button.new()
var _carousels: VBoxContainer = VBoxContainer.new()
## Left parts whose pair was split here although both sides still show the same mesh
var _split_pairs: Dictionary[int, bool] = {}
var _is_refresh_queued: bool = false

func _init(slot: EquipmentLook.Slot) -> void:
	_slot = slot
	var row: HBoxContainer = HBoxContainer.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.clip_text = true
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

## The types that go into [param slot] of [param profile], i.e. made for one of its models
static func get_slot_types(slot: EquipmentLook.Slot, profile: CharacterProfile) -> Array[EquipmentType]:
	var slot_types: Array[EquipmentType] = []
	for equipment_type: EquipmentType in EquipmentType.find_all():
		if equipment_type.slot == slot and profile.fits(equipment_type): slot_types.append(equipment_type)
	return slot_types

## The starting look of [param profile] that blocks [param slot], if any
static func get_blocker(profile: CharacterProfile, slot: EquipmentLook.Slot) -> EquipmentLook:
	for equipment_look: EquipmentLook in profile.get_starting_equipment():
		if equipment_look.blocked_slots.has(slot): return equipment_look
	return null

## A copy of the first allowed look of [param equipment_type]'s catalog, or [code]null[/code] without a catalog
static func get_first_look(equipment_type: EquipmentType) -> EquipmentLook:
	var catalog: EquipmentCatalog = EquipmentCatalog.find_for(equipment_type)
	return catalog.get_look(catalog.get_first_key()).make_local() if catalog else null

## The trailing number of what [param part] shows in [param equipment_look], [constant ModularBodyPart.EMPTY_MESH_NUMBER] for none
static func get_mesh_number(equipment_look: EquipmentLook, part: int) -> String:
	var mesh: ArrayMesh = equipment_look.get_part_mesh(part)
	return ModularBodyPart.get_mesh_number(mesh.resource_path) if mesh else ModularBodyPart.EMPTY_MESH_NUMBER

## The carousels of [param equipment_look]: one per part, left and right ones together unless they differ or are in [param split_pairs]
static func get_carousel_parts(equipment_look: EquipmentLook, split_pairs: Dictionary[int, bool]) -> Array[Array]:
	var carousels: Array[Array] = []
	var paired: Array[int] = []
	for part: int in equipment_look.type.parts:
		if paired.has(part): continue
		var partner: int = equipment_look.type.get_right_partner(part)
		var is_split: bool = split_pairs.has(part) or (partner >= 0 and get_mesh_number(equipment_look, part) != get_mesh_number(equipment_look, partner))
		if partner >= 0 and not is_split:
			paired.append(partner)
			carousels.append([part, partner])
		else: carousels.append([part])
	return carousels

## A carousel's text, e.g. "Shoulder Attach 05" for a pair or "Shoulder Attach Left 05" for one side
static func describe_carousel(equipment_look: EquipmentLook, parts: Array) -> String:
	var leader: int = parts[0]
	var part_name: String = equipment_look.type.get_part_key(leader)
	var label: String = part_name.capitalize()
	if parts.size() > 1: label = label.trim_suffix(" Left")
	return "%s %s" % [label, get_mesh_number(equipment_look, leader)]

## A copy of [param equipment_look] one mesh further for the carousel's first part, wrapping around; the others take the same number
## where they have it
static func step_parts(equipment_look: EquipmentLook, parts: Array, direction: int) -> EquipmentLook:
	var leader: int = parts[0]
	var options: PackedStringArray = equipment_look.type.get_mesh_options(leader)
	if options.is_empty(): return equipment_look
	var shown_mesh: ArrayMesh = equipment_look.get_part_mesh(leader)
	var shown_index: int = options.find(shown_mesh.resource_path if shown_mesh else "")
	if shown_index < 0: shown_index = 0 if direction > 0 else options.size()
	var stepped: EquipmentLook = _with_mesh_path(equipment_look, leader, options[posmod(shown_index + direction, options.size())])
	for part_index: int in range(1, parts.size()): stepped = match_part(stepped, parts[part_index] as int, leader)
	return stepped

## A copy where [param part] shows the mesh numbered like [param model_part]'s, if it has one
static func match_part(equipment_look: EquipmentLook, part: int, model_part: int) -> EquipmentLook:
	var mesh_number: String = get_mesh_number(equipment_look, model_part)
	for mesh_path: String in equipment_look.type.get_mesh_options(part):
		var number: String = ModularBodyPart.get_mesh_number(mesh_path) if not mesh_path.is_empty() else ModularBodyPart.EMPTY_MESH_NUMBER
		if number == mesh_number: return _with_mesh_path(equipment_look, part, mesh_path)
	return equipment_look

static func _with_mesh_path(equipment_look: EquipmentLook, part: int, mesh_path: String) -> EquipmentLook:
	return equipment_look.with_part_mesh(part, load(mesh_path) as ArrayMesh if not mesh_path.is_empty() else null)

func _update_property() -> void:
	var profile: CharacterProfile = get_edited_object()
	# Other slots change whether this one is blocked
	if not profile.changed.is_connected(_queue_refresh): profile.changed.connect(_queue_refresh)
	_refresh()

func _exit_tree() -> void:
	var profile: CharacterProfile = get_edited_object() as CharacterProfile
	if profile and profile.changed.is_connected(_queue_refresh): profile.changed.disconnect(_queue_refresh)

func _get_current() -> EquipmentLook:
	return get_edited_object().get(get_edited_property()) as EquipmentLook

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
	# The profile's models may have changed, e.g. from a human to a dwarf
	var slot_types: Array[EquipmentType] = get_slot_types(_slot, profile)
	if slot_types != _slot_types or _type_option.item_count == 0: _fill_type_option(slot_types)
	_type_option.select(_slot_types.find(equipment_look.type) + 1 if equipment_look else 0)
	_type_option.disabled = blocker != null
	_clear_button.disabled = not equipment_look
	for child: Node in _carousels.get_children():
		_carousels.remove_child(child)
		child.queue_free()
	if blocker:
		var blocked_label: Label = Label.new()
		blocked_label.text = "Blocked by %s" % blocker.name
		blocked_label.modulate = BLOCKED_COLOR
		_carousels.add_child(blocked_label)
		return
	if not equipment_look or not equipment_look.type: return
	for parts: Array in get_carousel_parts(equipment_look, _split_pairs): _carousels.add_child(_create_carousel(equipment_look, parts))

func _fill_type_option(slot_types: Array[EquipmentType]) -> void:
	_slot_types = slot_types
	_type_option.clear()
	_type_option.add_item("None")
	for equipment_type: EquipmentType in _slot_types:
		if equipment_type.icon: _type_option.add_icon_item(equipment_type.icon, equipment_type.name)
		else: _type_option.add_item(equipment_type.name)
		if not EquipmentCatalog.find_for(equipment_type): _type_option.set_item_disabled(_type_option.item_count - 1, true)

func _create_carousel(equipment_look: EquipmentLook, parts: Array) -> HBoxContainer:
	var carousel: HBoxContainer = HBoxContainer.new()
	var previous_button: Button = Button.new()
	previous_button.text = "<"
	previous_button.pressed.connect(_step.bind(equipment_look, parts, -1))
	var value_label: Label = Label.new()
	value_label.text = describe_carousel(equipment_look, parts)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	var next_button: Button = Button.new()
	next_button.text = ">"
	next_button.pressed.connect(_step.bind(equipment_look, parts, 1))
	for control: Control in [previous_button, value_label, next_button]: carousel.add_child(control)
	var leader: int = parts[0]
	var partner: int = equipment_look.type.get_right_partner(leader)
	if parts.size() > 1:
		carousel.add_child(_create_pair_button("Split", "Give the left and right side meshes of their own", _split.bind(leader)))
	elif partner >= 0:
		carousel.add_child(_create_pair_button("Link", "Show the left side's mesh on both sides again", _link.bind(equipment_look, leader, partner)))
	return carousel

func _create_pair_button(text: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	return button

func _step(equipment_look: EquipmentLook, parts: Array, direction: int) -> void:
	_set_look(step_parts(equipment_look, parts, direction))

func _split(left_part: int) -> void:
	_split_pairs[left_part] = true
	_queue_refresh()

func _link(equipment_look: EquipmentLook, left_part: int, right_part: int) -> void:
	_split_pairs.erase(left_part)
	_set_look(match_part(equipment_look, right_part, left_part))
	_queue_refresh()

func _on_type_selected(index: int) -> void:
	_set_look(get_first_look(_slot_types[index - 1]) if index > 0 else null)

## Like equipping in game, a look empties the slots it blocks
func _set_look(equipment_look: EquipmentLook) -> void:
	var profile: CharacterProfile = get_edited_object()
	if equipment_look:
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots:
			if profile.get_starting_equipment_for(blocked_slot): emit_changed(CharacterProfile.get_slot_property(blocked_slot), null)
	emit_changed(get_edited_property(), equipment_look)
