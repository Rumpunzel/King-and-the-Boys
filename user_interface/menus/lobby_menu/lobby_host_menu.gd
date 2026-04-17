@tool
class_name LobbyHostMenu
extends LobbyMenu

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.connect(_on_connected_to_multiplayer)

func _on_connected_to_multiplayer() -> void:
	_ready_button.visible = true

func _on_disconnected_from_multiplayer() -> void:
	_ready_button.visible = false
