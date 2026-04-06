@tool
extends Control

signal profile_changed(new_profile: Profile)

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
	if icon.get_size().aspect() != 1.0: push_warning("Using a non-square icon for %s" % profile.resource_path)
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

func _on_item_selected() -> void:
	_change_profile(_profiles_tree.get_selected())

func _on_profile_filter_text_changed(new_text: String) -> void:
	_filter_string = new_text

func _on_rescan_button_pressed() -> void:
	_update_profiles()
