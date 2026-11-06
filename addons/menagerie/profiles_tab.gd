@tool
extends Control

signal profile_changed(new_profile: Profile)
## A catalog look was checked or unchecked here
signal look_toggled(look: EquipmentLook)

enum Columns {
	PROFILE,
	## Checked catalog looks are offered and can be worn
	ALLOWED,
	RESOURCE_PATH,
}

const DISALLOWED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)

@export var title: String = name:
	set(new_title):
		title = new_title
		_update_name()
@export var profile_column_title: String
@export_dir var _data_path: String = "res://data/"

@export_group("Configuration")
@export var _profiles_tree: Tree

## Rows that group profiles, such as a type or a look's base; never stand for a profile
var _group_items: Dictionary[StringName, TreeItem]
## Rows grouping the variations of one base mesh; selecting one previews its first look
var _base_items: Dictionary[TreeItem, bool]
var _profile_items: Dictionary[Profile, TreeItem]
var _filter_string: String = "":
	set(new_filter_string):
		if new_filter_string == _filter_string: return
		_filter_string = new_filter_string
		_update_profiles()

func _ready() -> void:
	_profiles_tree.set_column_title(Columns.PROFILE, "%s [Variations]" % profile_column_title)
	_profiles_tree.set_column_title_alignment(Columns.PROFILE, HORIZONTAL_ALIGNMENT_LEFT)
	_profiles_tree.columns = Columns.size()
	_profiles_tree.set_column_expand(Columns.ALLOWED, false)
	_profiles_tree.set_column_custom_minimum_width(Columns.ALLOWED, 32)
	_profiles_tree.set_column_title(Columns.RESOURCE_PATH, "Path")
	_profiles_tree.set_column_title_alignment(Columns.RESOURCE_PATH, HORIZONTAL_ALIGNMENT_LEFT)
	if not _profiles_tree.item_edited.is_connected(_on_item_edited): _profiles_tree.item_edited.connect(_on_item_edited)
	_update_profiles()

## @returns every profile below [param directory_path], including the looks stored in catalogs
func _collect_profiles(directory_path: String = _data_path) -> Array[Profile]:
	var profiles: Array[Profile] = _list_profiles_in_directory(directory_path)
	for directory_name: String in DirAccess.get_directories_at(directory_path):
		profiles.append_array(_collect_profiles(directory_path.path_join(directory_name)))
	return profiles

func _create_items(profiles: Array[Profile]) -> void:
	var root: TreeItem = _profiles_tree.create_item()
	# A base row is only worth a click when it holds several variations
	var base_counts: Dictionary[String, int] = {}
	for profile: Profile in profiles:
		if profile is EquipmentLook:
			var base_key: String = _get_base_key(profile as EquipmentLook)
			base_counts[base_key] = base_counts.get(base_key, 0) + 1
	for profile: Profile in profiles:
		var is_grouped: bool = profile is EquipmentLook and base_counts[_get_base_key(profile as EquipmentLook)] > 1
		_create_profile_item(profile, root, is_grouped)
	_update_group_counts()

static func _get_base_key(look: EquipmentLook) -> String:
	return "%s/%s" % [look.get_group_name(), look.get_base_name()]

func _create_profile_item(profile: Profile, parent_item: TreeItem, is_grouped_by_base: bool = false) -> TreeItem:
	var group_item: TreeItem = _get_or_create_group_item(profile.get_group_name(), parent_item)
	# Looks group once more by their base, e.g. all variations of "Torso 05"
	if is_grouped_by_base:
		var look: EquipmentLook = profile
		var base_item: TreeItem = _get_or_create_group_item(_get_base_key(look), group_item, look.get_base_name())
		base_item.collapsed = _filter_string.is_empty()
		_base_items[base_item] = true
		group_item = base_item
	var profile_item: TreeItem = _profiles_tree.create_item(group_item)

	var icon: Texture2D = profile.portrait if profile.portrait else profile.get_default_icon()
	if icon and icon.get_size().aspect() != 1.0: push_warning("Using a non-square icon for %s" % profile.resource_path)
	var profile_text: String = profile.name
	var variation_count: int = profile.get_variation_count()
	if variation_count > 1: profile_text += " [1- %d]" % variation_count
	profile_item.set_icon(Columns.PROFILE, icon)
	profile_item.set_icon_max_width(Columns.PROFILE, 32)
	profile_item.set_text(Columns.PROFILE, profile_text)
	var variations: PackedStringArray = profile._model_variations.map(func(model: PackedScene) -> String: return model.resource_path)
	profile_item.set_tooltip_text(Columns.PROFILE, "\n".join(variations))
	profile_item.set_custom_color(Columns.PROFILE, profile.color)

	var shortened_path: String = profile.resource_path.trim_prefix(_data_path).trim_prefix("/")
	profile_item.set_text(Columns.RESOURCE_PATH, shortened_path)
	profile_item.set_metadata(Columns.RESOURCE_PATH, profile.resource_path)
	profile_item.set_tooltip_text(Columns.RESOURCE_PATH, profile.resource_path)
	profile_item.set_custom_color(Columns.RESOURCE_PATH, profile.color.darkened(0.5))

	# A catalog look can be checked or unchecked right here
	if profile is EquipmentLook and profile.resource_path.contains(ResourceId.SEPARATOR):
		profile_item.set_cell_mode(Columns.ALLOWED, TreeItem.CELL_MODE_CHECK)
		profile_item.set_editable(Columns.ALLOWED, true)
		profile_item.set_tooltip_text(Columns.ALLOWED, "Checked looks are offered and can be worn; Space toggles the selection")
		_show_allowed(profile_item, profile as EquipmentLook)

	_profile_items[profile] = profile_item
	_update_name()
	if visible and not _profiles_tree.get_selected(): _profiles_tree.set_selected(profile_item, Columns.PROFILE)
	return profile_item

func _get_or_create_group_item(key: StringName, parent_item: TreeItem, text: String = key) -> TreeItem:
	var group_item: TreeItem = _group_items.get(key)
	if group_item: return group_item
	group_item = _profiles_tree.create_item(parent_item)
	group_item.set_text(Columns.PROFILE, text)
	group_item.set_metadata(Columns.PROFILE, text)
	_group_items[key] = group_item
	return group_item

## Group rows show how many profiles they hold, and for looks how many of them are checked
## One pass over the profiles, each counted into every group row above it
func _update_group_counts() -> void:
	var totals: Dictionary[TreeItem, int] = {}
	var allowed_counts: Dictionary[TreeItem, int] = {}
	for profile: Profile in _profile_items:
		var is_catalog_look: bool = profile is EquipmentLook and profile.resource_path.contains(ResourceId.SEPARATOR)
		var parent: TreeItem = _profile_items[profile].get_parent()
		while parent:
			totals[parent] = totals.get(parent, 0) + 1
			if is_catalog_look:
				allowed_counts[parent] = allowed_counts.get(parent, 0) + (1 if (profile as EquipmentLook).allowed else 0)
			parent = parent.get_parent()
	for group_item: TreeItem in _group_items.values():
		var text: String = group_item.get_metadata(Columns.PROFILE)
		var total: int = totals.get(group_item, 0)
		group_item.set_text(Columns.PROFILE, "%s (%d/%d)" % [text, allowed_counts[group_item], total] if allowed_counts.has(group_item) else "%s (%d)" % [text, total])

func _show_allowed(profile_item: TreeItem, look: EquipmentLook) -> void:
	profile_item.set_checked(Columns.ALLOWED, look.allowed)
	var color: Color = look.color if look.allowed else look.color * DISALLOWED_COLOR
	profile_item.set_custom_color(Columns.PROFILE, color)
	profile_item.set_custom_color(Columns.RESOURCE_PATH, color.darkened(0.5))

## Sets a catalog look's flag; the catalog is saved a moment later, see [CatalogSaver]
func set_allowed(look: EquipmentLook, allowed: bool) -> void:
	var catalog: EquipmentCatalog = CatalogSaver.get_catalog_of(look)
	if not catalog or look.allowed == allowed: return
	look.allowed = allowed
	CatalogSaver.mark_dirty(catalog)
	update_look(look)
	look_toggled.emit(look)

## Shows a look's flag after it changed elsewhere, e.g. in the Equipment panel
func update_look(look: EquipmentLook) -> void:
	var profile_item: TreeItem = _profile_items.get(look)
	if not profile_item: return
	_show_allowed(profile_item, look)
	_update_group_counts()

func _change_profile(selected_item: TreeItem) -> void:
	# A base row previews its first variation
	if _base_items.has(selected_item): selected_item = selected_item.get_first_child()
	if not selected_item or _group_items.values().has(selected_item): return
	var profile_path: String = selected_item.get_metadata(Columns.RESOURCE_PATH)
	var profile: Profile = ResourceId.find(profile_path) as Profile
	if is_visible_in_tree(): EditorInterface.get_inspector().edit(profile)
	profile_changed.emit(profile)

func _clear_profiles() -> void:
	_group_items.clear()
	_base_items.clear()
	_profile_items.clear()
	_profiles_tree.clear()

func _list_profiles_in_directory(directory_path: String) -> Array[Profile]:
	var profiles_in_directory: Array[Profile] = []
	var file_names: PackedStringArray = DirAccess.get_files_at(directory_path)
	for file_name: String in file_names:
		if not file_name.get_extension() == "tres": continue
		var resource_path: String = directory_path.path_join(file_name)
		var resource: Resource = load(resource_path)
		if resource is Profile: profiles_in_directory.append(resource)
		# A catalog's looks are stored inside it
		elif resource is EquipmentCatalog:
			var catalog: EquipmentCatalog = resource
			for look: EquipmentLook in catalog.looks:
				if look: profiles_in_directory.append(look)
	return profiles_in_directory

func _profile_matches_filter_string(profile: Profile) -> bool:
	if _filter_string.is_empty(): return true
	if profile.name.containsn(_filter_string): return true
	if profile is EquipmentLook and (profile as EquipmentLook).get_base_name().containsn(_filter_string): return true
	return false

func _update_name() -> void:
	name = "%s (%d)" % [title, _profile_items.size()]

func _update_profiles() -> void:
	_clear_profiles()
	_create_items(_collect_profiles().filter(_profile_matches_filter_string))

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		CatalogSaver.flush()
		_clear_profiles()
	if is_visible_in_tree(): _update_profiles()

func _on_item_activated() -> void:
	_change_profile(_profiles_tree.get_selected())

func _on_item_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if selected and item == _profiles_tree.get_selected(): _change_profile(item)

func _on_item_edited() -> void:
	var edited_item: TreeItem = _profiles_tree.get_edited()
	var look: EquipmentLook = _get_look_of(edited_item)
	if look and _profiles_tree.get_edited_column() == Columns.ALLOWED: set_allowed(look, edited_item.is_checked(Columns.ALLOWED))

func _get_look_of(tree_item: TreeItem) -> EquipmentLook:
	if not tree_item or _group_items.values().has(tree_item): return null
	var profile_path: String = tree_item.get_metadata(Columns.RESOURCE_PATH)
	if not profile_path.contains(ResourceId.SEPARATOR): return null
	return ResourceId.find(profile_path) as EquipmentLook

func _on_profile_filter_text_changed(new_text: String) -> void:
	_filter_string = new_text

func _on_rescan_button_pressed() -> void:
	CatalogSaver.flush()
	_update_profiles()

func _on_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo: return
	match key_event.keycode:
		KEY_SPACE: _toggle_selected_looks()
		KEY_DELETE: _request_delete(_get_selected_paths())
		_: return
	_profiles_tree.accept_event()

## Toggles every selected catalog look to the opposite of the first one's flag
func _toggle_selected_looks() -> void:
	var looks: Array[EquipmentLook] = []
	var item: TreeItem = _profiles_tree.get_next_selected(null)
	while item:
		var look: EquipmentLook = _get_look_of(item)
		if look: looks.append(look)
		item = _profiles_tree.get_next_selected(item)
	if looks.is_empty(): return
	var allowed: bool = not looks[0].allowed
	for look: EquipmentLook in looks: set_allowed(look, allowed)

func _on_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT: return
	var selected_paths: PackedStringArray = _get_selected_paths()
	if selected_paths.is_empty(): return
	var context_menu: PopupMenu = PopupMenu.new()
	context_menu.add_item("Delete / uncheck %d" % selected_paths.size())
	context_menu.id_pressed.connect(func(_id: int) -> void: _request_delete(selected_paths))
	context_menu.popup_hide.connect(context_menu.queue_free)
	add_child(context_menu)
	context_menu.popup(Rect2i(Vector2i(_profiles_tree.get_screen_position() + mouse_position), Vector2i.ZERO))

## @returns the resource paths of all selected profiles; group rows are ignored
func _get_selected_paths() -> PackedStringArray:
	var selected_paths: PackedStringArray = []
	var item: TreeItem = _profiles_tree.get_next_selected(null)
	while item:
		if not _group_items.values().has(item): selected_paths.append(item.get_metadata(Columns.RESOURCE_PATH))
		item = _profiles_tree.get_next_selected(item)
	return selected_paths

## Catalog looks are not files: deleting them unchecks them, without asking
## Files are moved to the OS trash after a confirmation listing data files that still use them
func _request_delete(paths: PackedStringArray) -> void:
	var file_paths: PackedStringArray = []
	for path: String in paths:
		if not path.contains(ResourceId.SEPARATOR):
			file_paths.append(path)
			continue
		var look: EquipmentLook = ResourceId.find(path) as EquipmentLook
		if look: set_allowed(look, false)
	if file_paths.is_empty(): return
	var users: PackedStringArray = _find_users(file_paths, "res://data")
	var shown_paths: PackedStringArray = file_paths.slice(0, 10)
	var text: String = "Move %d file(s) to the trash?\n\n%s" % [file_paths.size(), "\n".join(shown_paths)]
	if file_paths.size() > shown_paths.size(): text += "\n… and %d more" % (file_paths.size() - shown_paths.size())
	if not users.is_empty(): text += "\n\nStill used by:\n%s" % "\n".join(users)
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Delete profiles"
	dialog.dialog_text = text
	dialog.ok_button_text = "Move to trash"
	dialog.confirmed.connect(_delete.bind(file_paths))
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

## @returns the resources and scenes below [param directory_path] that depend on any of [param paths], by reference or by a stored [ResourceId]
func _find_users(paths: PackedStringArray, directory_path: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	for path: String in paths:
		var id: String = ResourceId.of(ResourceId.find(path))
		if not id.is_empty(): ids.append(id)
	return _find_users_of(paths, ids, directory_path)

func _find_users_of(paths: PackedStringArray, ids: PackedStringArray, directory_path: String) -> PackedStringArray:
	var users: PackedStringArray = []
	var files: PackedStringArray = []
	for path: String in paths: files.append(path.get_slice(ResourceId.SEPARATOR, 0))
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.get_extension() not in ["tres", "tscn"]: continue
		var file_path: String = directory_path.path_join(file_name)
		if files.has(file_path): continue
		if _uses(file_path, paths, ids): users.append(file_path)
	for directory_name: String in DirAccess.get_directories_at(directory_path):
		users.append_array(_find_users_of(paths, ids, directory_path.path_join(directory_name)))
	return users

func _uses(file_path: String, paths: PackedStringArray, ids: PackedStringArray) -> bool:
	for dependency: String in ResourceLoader.get_dependencies(file_path):
		if paths.has(dependency.get_slice("::", 2)) or paths.has(dependency): return true
	if ids.is_empty(): return false
	var text: String = FileAccess.get_file_as_string(file_path)
	for id: String in ids:
		if text.contains('"%s"' % id): return true
	return false

func _delete(paths: PackedStringArray) -> void:
	for path: String in paths:
		var error: Error = OS.move_to_trash(ProjectSettings.globalize_path(path))
		if error != Error.OK: push_error("Could not move %s to the trash: %s" % [path, error_string(error)])
	EditorInterface.get_resource_filesystem().scan()
	_update_profiles()
