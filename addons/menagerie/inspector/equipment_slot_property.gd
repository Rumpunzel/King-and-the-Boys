@tool
class_name EquipmentSlotProperty
extends EditorProperty

## Picks an [EquipmentProfile] for one starting equipment slot, listing only items of that slot

const ITEM_DIRECTORY: String = "res://data/equipment"

var _slot: EquipmentProfile.Slot
var _pick_button: Button = Button.new()
var _clear_button: Button = Button.new()
var _popup: PopupPanel = PopupPanel.new()
var _filter_edit: LineEdit = LineEdit.new()
var _item_list: ItemList = ItemList.new()
## Items of [member _slot], sorted by type and name; reloaded whenever the popup opens
var _items: Array[EquipmentProfile] = []

func _init(slot: EquipmentProfile.Slot) -> void:
	_slot = slot
	var row: HBoxContainer = HBoxContainer.new()
	_pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pick_button.clip_text = true
	_pick_button.pressed.connect(_open_popup)
	_clear_button.text = "✕"
	_clear_button.tooltip_text = "Empty this slot"
	_clear_button.pressed.connect(_pick.bind(null))
	row.add_child(_pick_button)
	row.add_child(_clear_button)
	add_child(row)
	add_focusable(_pick_button)
	add_focusable(_clear_button)

	var popup_box: VBoxContainer = VBoxContainer.new()
	_filter_edit.placeholder_text = "Filter by name or type"
	_filter_edit.clear_button_enabled = true
	_filter_edit.text_changed.connect(_on_filter_changed)
	_filter_edit.text_submitted.connect(_on_filter_submitted)
	_item_list.custom_minimum_size = Vector2(420, 360)
	_item_list.item_activated.connect(_on_item_activated)
	popup_box.add_child(_filter_edit)
	popup_box.add_child(_item_list)
	_popup.add_child(popup_box)
	add_child(_popup)

func _update_property() -> void:
	var equipment_profile: EquipmentProfile = get_edited_object().get(get_edited_property())
	_pick_button.text = equipment_profile.name if equipment_profile else "<empty>"
	_pick_button.tooltip_text = equipment_profile.resource_path if equipment_profile else "Pick an item for this slot"
	_clear_button.disabled = not equipment_profile

func _open_popup() -> void:
	_items = find_items(ITEM_DIRECTORY, _slot)
	_filter_edit.text = ""
	_refresh_list()
	var button_rect: Rect2 = _pick_button.get_global_rect()
	_popup.popup(Rect2i(Vector2i(_pick_button.get_screen_position() + Vector2(0, button_rect.size.y)), Vector2i.ZERO))
	_filter_edit.grab_focus()

## @returns every saved item below [param directory_path] that goes into [param slot], sorted by type and name
static func find_items(directory_path: String, slot: EquipmentProfile.Slot) -> Array[EquipmentProfile]:
	var items: Array[EquipmentProfile] = _collect_items(directory_path, slot)
	items.sort_custom(func(a: EquipmentProfile, b: EquipmentProfile) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0 if a.type.name == b.type.name else a.type.name < b.type.name)
	return items

static func _collect_items(directory_path: String, slot: EquipmentProfile.Slot) -> Array[EquipmentProfile]:
	var items: Array[EquipmentProfile] = []
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.get_extension() != "tres": continue
		var equipment_profile: EquipmentProfile = load(directory_path.path_join(file_name)) as EquipmentProfile
		if equipment_profile and equipment_profile.type and equipment_profile.slot == slot: items.append(equipment_profile)
	for directory_name: String in DirAccess.get_directories_at(directory_path):
		items.append_array(_collect_items(directory_path.path_join(directory_name), slot))
	return items

static func get_item_label(equipment_profile: EquipmentProfile) -> String:
	return "%s  (%s)" % [equipment_profile.name, equipment_profile.type.name]

## Matches name or type, ignoring case; an empty filter matches everything
static func matches(equipment_profile: EquipmentProfile, filter: String) -> bool:
	return filter.strip_edges().is_empty() or get_item_label(equipment_profile).containsn(filter.strip_edges())

func _refresh_list() -> void:
	_item_list.clear()
	for equipment_profile: EquipmentProfile in _items:
		if not matches(equipment_profile, _filter_edit.text): continue
		var index: int = _item_list.add_item(get_item_label(equipment_profile), equipment_profile.portrait if equipment_profile.portrait else equipment_profile.type.icon)
		_item_list.set_item_metadata(index, equipment_profile)
		_item_list.set_item_tooltip(index, equipment_profile.resource_path)
	if _item_list.item_count > 0: _item_list.select(0)

func _pick(equipment_profile: EquipmentProfile) -> void:
	emit_changed(get_edited_property(), equipment_profile)
	_popup.hide()

func _on_filter_changed(_new_text: String) -> void:
	_refresh_list()

## Enter picks the first match
func _on_filter_submitted(_text: String) -> void:
	if _item_list.item_count > 0: _on_item_activated(0)

func _on_item_activated(index: int) -> void:
	var equipment_profile: EquipmentProfile = _item_list.get_item_metadata(index)
	_pick(equipment_profile)
