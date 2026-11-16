@tool
@icon("uid://bpf3ceyvd8tev")
class_name LobbyHostMenu
extends LobbyMenu

@export_group("Configuration")
## Starts the game once every guest is ready, see [method Lobby.can_start]
@export var _start_button: Button

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.connect(_on_connected_to_multiplayer)
	Lobby.readiness_changed.connect(_update_start_button)
	multiplayer.peer_connected.connect(_on_peers_changed)
	multiplayer.peer_disconnected.connect(_on_peers_changed)

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.disconnect(_on_connected_to_multiplayer)
	Lobby.readiness_changed.disconnect(_update_start_button)
	multiplayer.peer_connected.disconnect(_on_peers_changed)
	multiplayer.peer_disconnected.disconnect(_on_peers_changed)

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint(): return
	_update_start_button()

## Start is on once the game may start; online it counts the ready guests
func _update_start_button() -> void:
	_start_button.disabled = not Lobby.can_start()
	if not Multiplayer.is_online():
		_start_button.text = "Start"
		return
	_start_button.text = "Start (%d / %d ready)" % [Lobby.get_ready_count(), multiplayer.get_peers().size()]

## Deferred, as the multiplayer may still list a leaving peer while it tells
func _on_peers_changed(_peer_id: int) -> void:
	_update_start_button.call_deferred()

func _on_start_pressed() -> void:
	if not Lobby.can_start(): return
	Lobby.close_picks()
	close_menu()
	print_debug("Confirming Lobby for : %s" % [_player_panels.keys()])
	await fully_closed
	Panorama.clear_background.rpc()
	SceneManager.transition_everyone_to(_game_scene_path)
	SceneManager.transition_to_scene_with_setup(_game_scene_path, _setup_level, SceneManager.SetupMode.POST_CHANGE)

static func _setup_level(game: Game) -> Error:
	return await game.start_hosted_game()

func _on_connected_to_multiplayer() -> void:
	_update_start_button()

func _on_disconnected_from_multiplayer() -> void:
	_update_start_button()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _start_button: warnings.append("Missing start button reference.")
	return warnings + super._get_configuration_warnings()
