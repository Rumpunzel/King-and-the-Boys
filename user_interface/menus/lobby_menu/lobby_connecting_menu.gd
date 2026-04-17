@tool
class_name LobbyConnectingMenu
extends Menu

@export_group("Configuration")
@export var _toaster: Toaster
@export_file("*.tscn") var _lobby_guest_scene_path: String

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.game_joined.connect(_on_game_joined)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	SceneManager.preload_scene(_lobby_guest_scene_path)

func _process(_delta: float) -> void:
	if not multiplayer.multiplayer_peer: return
	if not multiplayer.is_server() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		set_process(false)
		SceneManager.transition_to_scene(_lobby_guest_scene_path, false)

func _on_cancel_pressed() -> void:
	Multiplayer.leave_game()

func _on_game_joined(_host_player_info: Dictionary[StringName, Variant]) -> void:
	SceneManager.transition_to_scene(_lobby_guest_scene_path, false)

func _on_disconnected_from_multiplayer() -> void:
	_toaster.toast_error("Connection failed!")
	SceneManager.to_main(false)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _toaster: warnings.append("Missing Toaster reference.")
	if _lobby_guest_scene_path.is_empty(): warnings.append("Missing lobby guest scene path.")
	return warnings
