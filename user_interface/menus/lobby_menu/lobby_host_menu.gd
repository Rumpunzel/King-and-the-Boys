@tool
@icon("uid://bpf3ceyvd8tev")
class_name LobbyHostMenu
extends LobbyMenu

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.connect(_on_connected_to_multiplayer)

func _on_start_pressed() -> void:
	close_menu()
	print_debug("Confirming Lobby for : %s" % [_player_panels.keys()])
	await fully_closed
	Panorama.clear_background.rpc()
	SceneManager.transition_everyone_to(_game_scene_path)
	SceneManager.transition_to_scene_with_setup(_game_scene_path, _setup_level, SceneManager.SetupMode.POST_CHANGE)

static func _setup_level(game: Game) -> Error:
	return await game.start_hosted_game()

func _on_connected_to_multiplayer() -> void:
	pass

func _on_disconnected_from_multiplayer() -> void:
	pass
