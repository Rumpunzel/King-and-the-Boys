@tool
@icon("uid://bgjmcb04v358t")
class_name Game
extends Node

signal game_status_changed(new_game_status: GameStatus)

enum GameStatus {
	NONE,
	READY,
	RUNNING,
}

@export_group("Configuration")
@export var _default_level: PackedScene
@export var _loading_screen_scene: PackedScene = preload("uid://dmweuj7kxaxov")
@export var _serializer: Serializer
@export var _level_spawner: LevelSpawner
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner
@export var _player_ghost_spawner: PlayerGhostSpawner

var _loading_screen: CanvasLayer
var _game_status: GameStatus:
	set(new_game_status):
		_game_status = new_game_status
		match _game_status:
			GameStatus.NONE:
				_on_server = false
				if not _loading_screen:
					_loading_screen = _loading_screen_scene.instantiate()
					add_child(_loading_screen)
			GameStatus.READY:
				assert(_loading_screen)
				_loading_screen.queue_free()
				_loading_screen = null
			GameStatus.RUNNING: pass
			_: push_error("GameStatus %s not implemented!" % _game_status)
		game_status_changed.emit(_game_status)

var _on_server: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	_game_status = GameStatus.NONE
	Client.singleplayer_started.connect(_on_singleplayer_started)
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)
	Multiplayer.game_joined.connect(_on_game_joined)
	Multiplayer.left_game.connect(_on_left_game)

func _ready() -> void:
	load_level()

func start_new_game() -> void:
	assert(multiplayer.is_server())
	print_debug("Starting new game...")
	if _on_server: push_error("Trying to start a new game while connected to server!")
	match _game_status:
		GameStatus.NONE: load_level()
		GameStatus.READY: pass
		GameStatus.RUNNING: stop_game()
		_: push_error("GameStatus %s not implemented!" % _game_status)
	assert(_game_status == GameStatus.READY)
	_player_ghost_spawner.start_synching_players()
	if Engine.is_editor_hint(): return
	_game_status = GameStatus.RUNNING

func load_level() -> void:
	assert(_game_status == GameStatus.NONE)
	_level_spawner.spawn(_default_level.resource_path)
	_agent_spawner.spawn_all_from_spawn_spoints()
	_structure_spawner.spawn_all_from_spawn_spoints()
	_thing_spawner.spawn_all_from_spawn_spoints()
	_game_status = GameStatus.READY

func save_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Saving game...")
	if _on_server: push_error("Trying to save a game while connected to server!")
	match _game_status:
		GameStatus.NONE, GameStatus.READY: push_error("Trying to save a game while no game is running!")
		GameStatus.RUNNING: pass
		_: push_error("GameStatus %s not implemented!" % _game_status)
	assert(_game_status == GameStatus.RUNNING)
	var error: Error = _serializer.save_world_state()
	if error == Error.OK: pass
	return error

func load_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Loading game...")
	if _on_server: push_error("Trying to load a game while connected to server!")
	match _game_status:
		GameStatus.NONE, GameStatus.READY: pass
		GameStatus.RUNNING: stop_game()
		_: push_error("GameStatus %s not implemented!" % _game_status)
	assert(_game_status == GameStatus.NONE)
	var error: Error = _serializer.load_world_state()
	_player_ghost_spawner.start_synching_players()
	if error == Error.OK: _game_status = GameStatus.READY
	return error

func continue_game() -> void:
	assert(multiplayer.is_server())
	if not Serializer.has_save_file(Serializer.SAVE_FILE_PATH):
		start_new_game()
		return
	var error: Error = load_game()
	assert(error == Error.OK)

func stop_game() -> void:
	assert(multiplayer.is_server())
	print_debug("Stopping running game...")
	_game_status = GameStatus.NONE
	_player_ghost_spawner.stop_synching_players()
	_agent_spawner.remove_all_agents()
	_thing_spawner.remove_all_things()
	_structure_spawner.remove_all_structures()
	_level_spawner.unload_level()

func _on_game_started() -> void:
	start_new_game()

func _on_singleplayer_started() -> void:
	assert(is_node_ready())
	Client.pause_game()
	continue_game()

func _on_joining_multiplayer() -> void:
	if _game_status == GameStatus.NONE: return
	stop_game()

func _on_game_joined(_host_player_info: Dictionary[StringName, Variant]) -> void:
	_on_server = true

func _on_left_game() -> void:
	stop_game()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _default_level: warnings.append("Missing default level scene.")
	if not _loading_screen_scene: warnings.append("Missing loading screen scene.")
	if not _serializer: warnings.append("Missing Serializer reference.")
	if not _level_spawner: warnings.append("Missing LevelSpawner reference.")
	if not _structure_spawner: warnings.append("Missing StructureSpawner reference.")
	if not _thing_spawner: warnings.append("Missing ThingSpawner reference.")
	if not _agent_spawner: warnings.append("Missing AgentSpawner reference.")
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	return warnings
