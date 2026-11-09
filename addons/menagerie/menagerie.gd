@tool
extends EditorPlugin

const MENAGERIE_PANEL_SCENE: PackedScene = preload("uid://bxs2pxpsmsfud")

var _menagerie_panel: MenageriePanel
var _equipment_inspector_plugin: EditorInspectorPlugin = preload("res://addons/menagerie/inspector/equipment_inspector_plugin.gd").new()

func _enter_tree() -> void:
	_menagerie_panel = MENAGERIE_PANEL_SCENE.instantiate()
	# Add the main panel to the editor's main viewport.
	EditorInterface.get_editor_main_screen().add_child(_menagerie_panel)
	# Hide the main panel. Very much required.
	_make_visible(false)
	add_inspector_plugin(_equipment_inspector_plugin)

func _exit_tree() -> void:
	if _menagerie_panel: _menagerie_panel.queue_free()
	remove_inspector_plugin(_equipment_inspector_plugin)
	# Toggled looks are saved in batches; do not lose the last ones
	CatalogSaver.flush()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _menagerie_panel: _menagerie_panel.visible = visible

func _get_plugin_name() -> String:
	return "Menagerie"

func _get_plugin_icon() -> Texture2D:
	return preload("uid://b0loae1a81516")
