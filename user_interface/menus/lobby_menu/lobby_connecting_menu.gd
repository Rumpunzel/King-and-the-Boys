@tool
class_name LobbyConnectingMenu
extends Menu

@export_group("Configuration")

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _on_cancel_pressed() -> void:
	Multiplayer.leave_game()

func _on_disconnected_from_multiplayer() -> void:
	SceneManager.to_main(false)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
