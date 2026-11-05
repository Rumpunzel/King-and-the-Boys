@tool
class_name EquipmentSlotProperty
extends EditorProperty

## Picks an [EquipmentProfile] for one starting equipment slot, listing only items of that slot
## Items are grouped by type, then by their base mesh, e.g. "Torso 05", so variations of one base sit together
## Selecting an item equips it right away, so the Menagerie preview can be clicked through; activating it also closes

const ITEM_DIRECTORY: String = "res://data/equipment"

var _slot: EquipmentProfile.Slot
var _pick_button: Button = Button.new()
var _clear_button: Button = Button.new()
var _popup: PopupPanel = PopupPanel.new()
var _filter_edit: LineEdit = LineEdit.new()
var _tree: Tree = Tree.new()
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
	_clear_button.pressed.connect(_on_clear_pressed)
	row.add_child(_pick_button)
	row.add_child(_clear_button)
	add_child(row)
	add_focusable(_pick_button)
	add_focusable(_clear_button)

	var popup_box: VBoxContainer = VBoxContainer.new()
	_filter_edit.placeholder_text = "Filter by name, type or base"
	_filter_edit.clear_button_enabled = true
	_filter_edit.text_changed.connect(_on_filter_changed)
	_filter_edit.text_submitted.connect(_on_filter_submitted)
	_tree.custom_minimum_size = Vector2(420, 420)
	_tree.hide_root = true
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.item_activated.connect(_on_tree_item_activated)
	popup_box.add_child(_filter_edit)
	popup_box.add_child(_tree)
	_popup.add_child(popup_box)
	add_child(_popup)

func _update_property() -> void:
	var equipment_profile: EquipmentProfile = _get_current()
	_pick_button.text = equipment_profile.name if equipment_profile else "<empty>"
	_pick_button.tooltip_text = equipment_profile.resource_path if equipment_profile else "Pick an item for this slot"
	_clear_button.disabled = not equipment_profile

func _get_current() -> EquipmentProfile:
	return get_edited_object().get(get_edited_property())

func _open_popup() -> void:
	_items = find_items(ITEM_DIRECTORY, _slot)
	_filter_edit.text = ""
	_refresh_tree()
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

## @returns the item's mesh for its type's first part, e.g. "Torso 05"; items of one base are variations of each other
static func get_base(equipment_profile: EquipmentProfile) -> String:
	if equipment_profile.type.parts.is_empty(): return equipment_profile.type.name
	var lead_part: ModularCharacter.Part = equipment_profile.type.parts[0]
	var part_name: String = ModularCharacter.Part.keys()[lead_part]
	for part_mesh: EquipmentPartMesh in equipment_profile.appearance.parts:
		if part_mesh and part_mesh.part == lead_part and part_mesh.male_mesh:
			return "%s %s" % [part_name.capitalize(), ModularBodyPart.get_mesh_number(part_mesh.male_mesh.resource_path)]
	return "No %s" % part_name.capitalize()

## Matches name, type or base, ignoring case; an empty filter matches everything
static func matches(equipment_profile: EquipmentProfile, filter: String) -> bool:
	var trimmed_filter: String = filter.strip_edges()
	if trimmed_filter.is_empty(): return true
	return equipment_profile.name.containsn(trimmed_filter) or equipment_profile.type.name.containsn(trimmed_filter) or get_base(equipment_profile).containsn(trimmed_filter)

func _refresh_tree() -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var filtering: bool = not _filter_edit.text.strip_edges().is_empty()
	var current: EquipmentProfile = _get_current()
	var type_items: Dictionary[EquipmentType, TreeItem] = {}
	var base_items: Dictionary[String, TreeItem] = {}
	for equipment_profile: EquipmentProfile in _items:
		if not matches(equipment_profile, _filter_edit.text): continue
		var type_item: TreeItem = type_items.get(equipment_profile.type)
		if not type_item:
			type_item = _tree.create_item(root)
			type_item.set_text(0, equipment_profile.type.name)
			type_item.set_icon(0, equipment_profile.type.icon)
			type_item.set_selectable(0, false)
			type_items[equipment_profile.type] = type_item
		var base: String = get_base(equipment_profile)
		var base_key: String = "%s/%s" % [equipment_profile.type.name, base]
		var base_item: TreeItem = base_items.get(base_key)
		if not base_item:
			base_item = _tree.create_item(type_item)
			base_item.set_text(0, base)
			base_item.collapsed = not filtering
			base_items[base_key] = base_item
		var item: TreeItem = _tree.create_item(base_item)
		item.set_text(0, equipment_profile.name)
		item.set_icon(0, equipment_profile.portrait)
		item.set_tooltip_text(0, equipment_profile.resource_path)
		item.set_metadata(0, equipment_profile)
		if equipment_profile == current:
			base_item.collapsed = false
			item.select(0)
			_tree.scroll_to_item.call_deferred(item)
	for base_key: String in base_items:
		var base_item: TreeItem = base_items[base_key]
		base_item.set_suffix(0, "(%d)" % base_item.get_child_count())

## @returns the item a row stands for; a base row stands for its first variation
func _get_profile_of(tree_item: TreeItem) -> EquipmentProfile:
	if not tree_item: return null
	if tree_item.get_child_count() > 0: tree_item = tree_item.get_first_child()
	return tree_item.get_metadata(0) as EquipmentProfile

func _apply(equipment_profile: EquipmentProfile) -> void:
	if equipment_profile == _get_current(): return
	emit_changed(get_edited_property(), equipment_profile)

func _on_clear_pressed() -> void:
	_apply(null)

func _on_tree_item_selected() -> void:
	var equipment_profile: EquipmentProfile = _get_profile_of(_tree.get_selected())
	if equipment_profile: _apply(equipment_profile)

func _on_tree_item_activated() -> void:
	var selected: TreeItem = _tree.get_selected()
	# Activating a base row opens its variations instead of closing
	if selected and selected.get_child_count() > 0 and selected.collapsed:
		selected.collapsed = false
		return
	var equipment_profile: EquipmentProfile = _get_profile_of(selected)
	if equipment_profile: _apply(equipment_profile)
	_popup.hide()

func _on_filter_changed(_new_text: String) -> void:
	_refresh_tree()

## Enter equips the first match and closes
func _on_filter_submitted(_text: String) -> void:
	for equipment_profile: EquipmentProfile in _items:
		if not matches(equipment_profile, _filter_edit.text): continue
		_apply(equipment_profile)
		_popup.hide()
		return
