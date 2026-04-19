@tool
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
	SceneManager.transition_to_scene_with_setup(_game_scene_path, _setup_level, SceneManager.SetupMode.POST_CHANGE)
	SceneManager.confirmed_transitions = 0
	SceneManager.transition_to_scene_remotely.rpc(_game_scene_path)
	SceneManager.confirm_transition.rpc()

static func _setup_level(game: Game) -> Error:
	if Lobby.get_connected_players().size() > 1:
		var lobby_size: int = Lobby.get_connected_players().size()
		while SceneManager.confirmed_transitions < lobby_size:
			SceneManager.update_loading_screen.rpc("Waiting for other Players [%d / %d]" % [SceneManager.confirmed_transitions, lobby_size])
			await game.get_tree().process_frame
	SceneManager.update_loading_screen.rpc("Generating")
	game.setup_game()
	SceneManager.reset_confirmed_transition.rpc()
	SceneManager.remove_loading_screen.rpc()
	return Error.OK

func _on_connected_to_multiplayer() -> void:
	pass

func _on_disconnected_from_multiplayer() -> void:
	pass
