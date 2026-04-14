@tool
@icon("uid://bgjmcb04v358t")
class_name Game
extends Node

signal game_status_changed(new_game_status: GameStatus)

enum GameStatus {
	NONE,
	IN_LOBBY,
	READY,
	LOADING,
	RUNNING,
}

@export_group("Configuration")
@export var _background_placeholder: CanvasItem
@export_file("*.tscn") var _background_scene_path: String
@export_file("*.tscn") var _default_level_path: String
@export var _loading_screen_scene: PackedScene = preload("uid://dmweuj7kxaxov")
@export var _serializer: Serializer
@export var _level_spawner: LevelSpawner
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner
@export var _player_ghost_spawner: PlayerGhostSpawner

var _loading_screen: CanvasLayer
var _background_scene: Node
var _game_status: GameStatus:
	set(new_game_status):
		_game_status = new_game_status
		match _game_status:
			GameStatus.NONE:
				_on_server = false
				_background_placeholder.modulate.a = 1.0
			GameStatus.IN_LOBBY:
				ResourceLoader.load_threaded_request(_default_level_path)
			GameStatus.READY:
				pass
			GameStatus.LOADING:
				if not _loading_screen:
					_loading_screen = _loading_screen_scene.instantiate()
					add_child(_loading_screen)
				_background_placeholder.visible = false
				if _background_scene:
					_background_scene.queue_free()
					_background_scene = null
				_level_spawner.spawn(_default_level_path)
				#_agent_spawner.spawn_all_from_spawn_spoints()
				#_structure_spawner.spawn_all_from_spawn_spoints()
				#_thing_spawner.spawn_all_from_spawn_spoints()
			GameStatus.RUNNING:
				assert(_loading_screen)
				_loading_screen.queue_free()
				_loading_screen = null
				_player_ghost_spawner.start_synching_players()
			_: push_error("GameStatus %s not implemented!" % _game_status)
		game_status_changed.emit(_game_status)

var _on_server: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Client.singleplayer_started.connect(_on_singleplayer_started)
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)
	Multiplayer.game_joined.connect(_on_game_joined)
	Multiplayer.left_game.connect(_on_left_game)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_background_placeholder.visible = true
	if not _background_scene_path.is_empty(): ResourceLoader.load_threaded_request(_background_scene_path)
	assert(not _default_level_path.is_empty())
	_game_status = GameStatus.NONE

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if _game_status <= GameStatus.IN_LOBBY: if not _background_scene_path.is_empty() and not _background_scene: _load_background_scene_when_ready()
	if _game_status == GameStatus.IN_LOBBY: _check_if_level_is_ready()

func open_lobby() -> void:
	assert(multiplayer.is_server())
	Client.start_game()
	print_debug("Opening Lobby...")
	if _on_server: push_error("Trying to open a lobby while connected to server!")
	_game_status = GameStatus.IN_LOBBY

func start_game() -> void:
	assert(multiplayer.is_server())
	assert(_game_status == GameStatus.READY)
	print_debug("Starting new game...")
	if _on_server: push_error("Trying to start a new game while connected to server!")
	_game_status = GameStatus.LOADING

func save_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Saving game...")
	if _on_server: push_error("Trying to save a game while connected to server!")
	assert(_game_status == GameStatus.RUNNING)
	var error: Error = _serializer.save_world_state()
	if error == Error.OK: pass
	return error

func load_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Loading game...")
	if _on_server: push_error("Trying to load a game while connected to server!")
	assert(_game_status == GameStatus.NONE)
	var error: Error = _serializer.load_world_state()
	_player_ghost_spawner.start_synching_players()
	if error == Error.OK: _game_status = GameStatus.RUNNING
	return error

func continue_game() -> void:
	assert(multiplayer.is_server())
	if not Serializer.has_save_file(Serializer.SAVE_FILE_PATH):
		open_lobby()
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

func _load_background_scene_when_ready() -> void:
	if not ResourceLoader.load_threaded_get_status(_background_scene_path) == ResourceLoader.THREAD_LOAD_LOADED: return
	var background_scene: PackedScene = ResourceLoader.load_threaded_get(_background_scene_path)
	_background_scene = background_scene.instantiate()
	add_child(_background_scene)
	var tween: Tween = create_tween()
	tween.tween_property(_background_placeholder, "modulate:a", 0.0, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _check_if_level_is_ready() -> void:
	assert(_game_status == GameStatus.IN_LOBBY)
	if not ResourceLoader.load_threaded_get_status(_default_level_path) == ResourceLoader.THREAD_LOAD_LOADED: return
	_game_status = GameStatus.READY

func _on_game_requested() -> void:
	open_lobby()

func _on_game_start_requested() -> void:
	start_game()

func _on_level_loaded() -> void:
	assert(_game_status == GameStatus.LOADING)
	_game_status = GameStatus.RUNNING

func _on_save_requested() -> void:
	pass # Replace with function body.

func _on_load_requested() -> void:
	pass # Replace with function body.

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
	if _default_level_path.is_empty(): warnings.append("Missing default level scene.")
	if not _loading_screen_scene: warnings.append("Missing loading screen scene.")
	if not _serializer: warnings.append("Missing Serializer reference.")
	if not _level_spawner: warnings.append("Missing LevelSpawner reference.")
	if not _structure_spawner: warnings.append("Missing StructureSpawner reference.")
	if not _thing_spawner: warnings.append("Missing ThingSpawner reference.")
	if not _agent_spawner: warnings.append("Missing AgentSpawner reference.")
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	return warnings
