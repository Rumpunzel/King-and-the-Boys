@tool
@icon("uid://bgjmcb04v358t")
class_name Game
extends Node

@export_group("Configuration")
@export var _serializer: Serializer
@export var _level_spawner: LevelSpawner
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner
@export var _player_ghost_spawner: PlayerGhostSpawner

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	Panorama.clear_background()

func setup_game(level_path: String) -> void:
	ResourceLoader.load_threaded_request(level_path)
	if not multiplayer.is_server(): return
	_level_spawner.load_level(level_path)
	#_agent_spawner.spawn_all_from_spawn_spoints()
	#_structure_spawner.spawn_all_from_spawn_spoints()
	#_thing_spawner.spawn_all_from_spawn_spoints()
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
	assert(multiplayer.is_server())
	print_debug("Stopping running game...")
	_player_ghost_spawner.stop_synching_players()
	_agent_spawner.remove_all_agents()
	_thing_spawner.remove_all_things()
	_structure_spawner.remove_all_structures()
	_level_spawner.unload_level()
	SceneManager.to_main()

func _on_save_requested() -> void:
	pass # Replace with function body.

func _on_load_requested() -> void:
	pass # Replace with function body.

func _on_disconnected_from_multiplayer() -> void:
	SceneManager.to_main()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _serializer: warnings.append("Missing Serializer reference.")
	if not _level_spawner: warnings.append("Missing LevelSpawner reference.")
	if not _structure_spawner: warnings.append("Missing StructureSpawner reference.")
	if not _thing_spawner: warnings.append("Missing ThingSpawner reference.")
	if not _agent_spawner: warnings.append("Missing AgentSpawner reference.")
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	return warnings
