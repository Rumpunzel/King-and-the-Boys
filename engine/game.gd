@tool
@icon("uid://b0vg3flbqcfqk")
class_name Game
extends Node

@export_group("Configuration")
@export var _serializer: Serializer
@export var _level: Level
@export var _player_controller_spawner: PlayerControllerSpawner

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	if Engine.is_editor_hint(): return

## Host only, once its game scene is shown: waits until every connected peer shows it too (peers that
## disconnect meanwhile are not waited for), then sets the game up and ends the loading screens
func start_hosted_game() -> Error:
	assert(multiplayer.is_server())
	SceneManager.confirm_transition()
	var shown_message: String = ""
	while true:
		var peer_ids: Array[int] = get_connected_peer_ids()
		var ready_count: int = peer_ids.filter(SceneManager.has_confirmed).size()
		if ready_count == peer_ids.size(): break
		var message: String = "Waiting for players [%d / %d]" % [ready_count, peer_ids.size()]
		if message != shown_message:
			shown_message = message
			SceneManager.update_loading_screen.rpc(message)
		await get_tree().process_frame
	SceneManager.update_loading_screen.rpc("Generating")
	setup_game()
	SceneManager.remove_loading_screen.rpc()
	return Error.OK

## @returns the ids of every connected peer, this one included
func get_connected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = [multiplayer.get_unique_id()]
	peer_ids.append_array(multiplayer.get_peers())
	return peer_ids

func setup_game() -> void:
	if not multiplayer.is_server(): return
	_level.build_level()
	TurnManager.get_instance(get_tree()).start_syncing_peers()
	_player_controller_spawner.start_synching_players()

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
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	turn_manager.clear_passes()
	turn_manager.start_syncing_peers()
	_player_controller_spawner.start_synching_players()
	return error

func stop_game() -> void:
	print_debug("Stopping running game...")
	_player_controller_spawner.stop_synching_players()
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
	if not _player_controller_spawner: warnings.append("Missing PlayerControllerSpawner reference.")
	return warnings
