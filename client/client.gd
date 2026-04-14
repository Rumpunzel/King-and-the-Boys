@icon("uid://csn6gjpak3yxk")
extends Node

signal game_started
signal game_stopped
signal singleplayer_started

signal game_paused
signal game_unpaused

var _game_environment: GameEnvironment
var _pause_requested: bool = false

func _enter_tree() -> void:
	Multiplayer.stopped_hosting_game.connect(_start_singleplayer)
	Multiplayer.left_game.connect(_start_singleplayer)
	Multiplayer.disconnected_from_multiplayer.connect(_start_singleplayer)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	assert(not _game_environment)
	_game_environment = Steamworks.new() # TODO: discriminate between actual environments
	add_child(_game_environment)

func _process(_delta: float) -> void:
	if Multiplayer.is_online():
		if get_tree().paused: _unpause_game()
	else:
		if _pause_requested and not get_tree().paused: _pause_game()

func start_game() -> void: game_started.emit()
func stop_game() -> void: game_stopped.emit()

func pause_game() -> void: _pause_requested = true
func unpause_game() -> void:
	_unpause_game()
	_pause_requested = false

func quit_game() -> void: get_tree().quit()

func get_player_name(player_id: int) -> String:
	var user_name: String = "Haunt"
	var environment_user_name: String = _game_environment.get_player_name(player_id)
	if not environment_user_name.is_empty(): user_name = environment_user_name
	return user_name

func get_player_avatar(player_id: int) -> Texture2D:
	@warning_ignore("redundant_await")
	var environment_avatar: Texture2D = await _game_environment.get_player_avatar(player_id)
	return environment_avatar

func _start_singleplayer() -> void:
	var offline_peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline_peer
	singleplayer_started.emit()

func _pause_game() -> void:
	get_tree().paused = true
	game_paused.emit()

func _unpause_game() -> void:
	get_tree().paused = false
	game_unpaused.emit()
