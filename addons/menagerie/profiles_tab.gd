@tool
extends Control

signal profile_changed(new_profile: Profile)

const EXCLUDE_ACTION: StringName = &"exclude"

enum Columns {
	PROFILE,
	RESOURCE_PATH,
}

@export var title: String = name:
	set(new_title):
		title = new_title
		_update_name()
@export var profile_column_title: String
@export_dir var _data_path: String = "res://data/"

@export_group("Configuration")
@export var _profiles_tree: Tree

var _group_items: Dictionary[StringName, TreeItem]
var _profile_items: Dictionary[Profile, TreeItem]
var _filter_string: String = "":
	set(new_filter_string):
		if new_filter_string == _filter_string: return
		_filter_string = new_filter_string
		_update_profiles()

func _ready() -> void:
	_profiles_tree.set_column_title(Columns.PROFILE, "%s [Variations]" % profile_column_title)
	_profiles_tree.set_column_title_alignment(Columns.PROFILE, HORIZONTAL_ALIGNMENT_LEFT)
	_profiles_tree.set_column_title(Columns.RESOURCE_PATH, "Path")
	_profiles_tree.set_column_title_alignment(Columns.RESOURCE_PATH, HORIZONTAL_ALIGNMENT_LEFT)
	_update_profiles()

func _create_items_for_profiles_in_directory(directory_path: String = _data_path, parent_item: TreeItem = _profiles_tree.create_item()) -> void:
	var profiles_in_directory: Array[Profile] = _list_profiles_in_directory(directory_path)
	for profile: Profile in profiles_in_directory:
		if not _profile_matches_filter_string(profile): continue
		_create_profile_item(profile, parent_item)
	var directory_names: PackedStringArray = DirAccess.get_directories_at(directory_path)
	for directory_name: String in directory_names:
		_create_items_for_profiles_in_directory(directory_path.path_join(directory_name), parent_item)

func _create_profile_item(profile: Profile, parent_item: TreeItem) -> TreeItem:
	var group_item: TreeItem = _group_items.get(profile.get_group_name())
	if not group_item: group_item = _create_group_item_for_profile(profile, parent_item)
	var profile_item: TreeItem = _profiles_tree.create_item(group_item)
	group_item.set_text(0, "%s (%d)" % [profile.get_group_name(), group_item.get_child_count()])
	
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
	
	_profile_items[profile] = profile_item
	_update_name()
	if visible and not _profiles_tree.get_selected(): _profiles_tree.set_selected(profile_item, Columns.PROFILE)
	return profile_item

func _create_group_item_for_profile(profile: Profile, parent_item: TreeItem) -> TreeItem:
	var group_item: TreeItem = _profiles_tree.create_item(parent_item)
	var group_name: StringName = profile.get_group_name()
	group_item.set_text(0, group_name)
	_group_items[group_name] = group_item
	return group_item

func _change_profile(selected_item: TreeItem) -> void:
	if _group_items.values().has(selected_item): return
	var profile_path: String = selected_item.get_metadata(Columns.RESOURCE_PATH)
	var profile: Profile = load(profile_path)
	if is_visible_in_tree(): EditorInterface.get_inspector().edit(profile)
	profile_changed.emit(profile)

func _clear_profiles() -> void:
	_group_items.clear()
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
	return profiles_in_directory

func _profile_matches_filter_string(profile: Profile) -> bool:
	if _filter_string.is_empty(): return true
	if profile.name.containsn(_filter_string): return true
	return false

func _update_name() -> void:
	name = "%s (%d)" % [title, _profile_items.size()]

func _update_profiles() -> void:
	_clear_profiles()
	_create_items_for_profiles_in_directory()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): _clear_profiles()
	if is_visible_in_tree(): _update_profiles()

func _on_item_activated() -> void:
	_change_profile(_profiles_tree.get_selected())

func _on_item_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if selected and item == _profiles_tree.get_selected(): _change_profile(item)

func _on_profile_filter_text_changed(new_text: String) -> void:
	_filter_string = new_text

func _on_rescan_button_pressed() -> void:
	_update_profiles()

func _on_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_DELETE: return
	_request_delete(_get_selected_paths())
	_profiles_tree.accept_event()

func _on_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT: return
	var selected_paths: PackedStringArray = _get_selected_paths()
	if selected_paths.is_empty(): return
	var context_menu: PopupMenu = PopupMenu.new()
	context_menu.add_item("Move %d to trash" % selected_paths.size())
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

## Asks before moving [param paths] to the OS trash, listing other data files that still use them
func _request_delete(paths: PackedStringArray) -> void:
	if paths.is_empty(): return
	var users: PackedStringArray = _find_users(paths, "res://data")
	var shown_paths: PackedStringArray = paths.slice(0, 10)
	var text: String = "Move %d file(s) to the trash?\n\n%s" % [paths.size(), "\n".join(shown_paths)]
	if paths.size() > shown_paths.size(): text += "\n… and %d more" % (paths.size() - shown_paths.size())
	if not users.is_empty(): text += "\n\nStill used by:\n%s" % "\n".join(users)
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Delete profiles"
	dialog.dialog_text = text
	dialog.ok_button_text = "Move to trash"
	dialog.confirmed.connect(_delete.bind(paths))
	if Array(paths).any(func(path: String) -> bool: return load(path) is EquipmentProfile):
		dialog.add_button("Move to trash and exclude", true, EXCLUDE_ACTION)
		dialog.custom_action.connect(func(action: StringName) -> void:
			if action != EXCLUDE_ACTION: return
			dialog.hide()
			_delete(paths, true))
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

## @returns the resources and scenes below [param directory_path] that depend on any of [param paths]
func _find_users(paths: PackedStringArray, directory_path: String) -> PackedStringArray:
	var users: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.get_extension() not in ["tres", "tscn"]: continue
		var file_path: String = directory_path.path_join(file_name)
		if paths.has(file_path): continue
		for dependency: String in ResourceLoader.get_dependencies(file_path):
			if paths.has(dependency.get_slice("::", 2)) or paths.has(dependency):
				users.append(file_path)
				break
	for directory_name: String in DirAccess.get_directories_at(directory_path):
		users.append_array(_find_users(paths, directory_path.path_join(directory_name)))
	return users

## With [param exclude], equipment combinations are also added to their type's [member EquipmentType.excluded_combinations], so they are not generated again
func _delete(paths: PackedStringArray, exclude: bool = false) -> void:
	var changed_types: Array[EquipmentType] = []
	if exclude:
		for path: String in paths:
			var equipment_profile: EquipmentProfile = load(path) as EquipmentProfile
			if not equipment_profile or not equipment_profile.type: continue
			equipment_profile.type.exclude(equipment_profile.type.get_combination_name_of(equipment_profile))
			if not changed_types.has(equipment_profile.type): changed_types.append(equipment_profile.type)
	for equipment_type: EquipmentType in changed_types:
		var error: Error = ResourceSaver.save(equipment_type, equipment_type.resource_path)
		if error != Error.OK: push_error("Could not save exclusions to %s: %s" % [equipment_type.resource_path, error_string(error)])
	for path: String in paths:
		var error: Error = OS.move_to_trash(ProjectSettings.globalize_path(path))
		if error != Error.OK: push_error("Could not move %s to the trash: %s" % [path, error_string(error)])
	EditorInterface.get_resource_filesystem().scan()
	_update_profiles()
