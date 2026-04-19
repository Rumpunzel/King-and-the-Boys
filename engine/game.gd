@tool
@icon("uid://b0vg3flbqcfqk")
class_name Game
extends Node

@export_group("Configuration")
@export var _serializer: Serializer
@export var _level: Level
@export var _player_ghost_spawner: PlayerGhostSpawner

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	if Engine.is_editor_hint(): return

func setup_game() -> void:
	if not multiplayer.is_server(): return
	_level.build_level()
	_player_ghost_spawner.start_synching_players()

func save_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Saving game...")
	var error: Error = _serializer.save_world_state()
	if error == Error.OK: pass
	return error

func load_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Loading game...")
	var error: Error = _serializer.load_world_state()
	_player_ghost_spawner.start_synching_players()
	return error

func stop_game() -> void:
	print_debug("Stopping running game...")
	_player_ghost_spawner.stop_synching_players()
	SceneManager.to_main()

func _on_save_requested() -> void:
	pass # Replace with function body.

func _on_load_requested() -> void:
	pass # Replace with function body.

func _on_disconnected_from_multiplayer() -> void:
	stop_game()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _serializer: warnings.append("Missing Serializer reference.")
	if not _level: warnings.append("Missing Level reference.")
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	return warnings
