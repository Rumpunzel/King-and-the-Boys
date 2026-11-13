@tool
@icon("uid://b0vg3flbqcfqk")
class_name Game
extends Node

## Host only: a peer the start waits for reported its part of the game arrived, or left
signal peer_readiness_changed

@export_group("Configuration")
@export var _serializer: Serializer
@export var _level: Level
@export var _player_controller_spawner: PlayerControllerSpawner

# Host only: peers sent here at the start whose part of the game has not arrived yet, how many of them arrived,
# and every peer that reported its part arrived (see _report_ready)
var _awaited_peers: Dictionary[int, bool] = {}
var _placed_count: int = 0
var _ready_peers: Dictionary[int, bool] = {}
# Client: told the host its part of the game arrived
var _has_reported: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	# Players joining the running game wait for their part of it too, see _report_ready
	add_to_group(SceneManager.KEEPS_JOINERS_LOADING)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		return
	# Deferred: the controller enters the tree before its character does
	_player_controller_spawner.player_controller_created.connect(_on_part_arrived, CONNECT_DEFERRED)
	_level.tile_placed.connect(_on_part_arrived)
	_on_part_arrived(null)

## Host only, once its game scene is shown: waits until every peer sent here shows it too (see
## [method SceneManager.transition_everyone_to]), sets the game up, then waits until each of them has its
## character and the tile under it, and ends every loading screen at once. Peers that leave are not waited for.
func start_hosted_game() -> Error:
	assert(multiplayer.is_server())
	SceneManager.show_loading_screen()
	SceneManager.transition_progressed.connect(_on_transition_progressed)
	SceneManager.confirm_transition(scene_file_path)
	if not SceneManager.is_transition_complete(): await SceneManager.transition_completed
	SceneManager.transition_progressed.disconnect(_on_transition_progressed)
	_awaited_peers.clear()
	_placed_count = 0
	for peer_id: int in SceneManager.get_transitioning_peers():
		if peer_id != multiplayer.get_unique_id(): _awaited_peers[peer_id] = true
	SceneManager.tell_transitioning_peers("Generating")
	setup_game()
	while not _awaited_peers.is_empty():
		SceneManager.tell_transitioning_peers("Placing players [%d / %d]" % [_placed_count + 1, _placed_count + _awaited_peers.size() + 1])
		await peer_readiness_changed
	SceneManager.end_transition()
	return Error.OK

func setup_game() -> void:
	if not multiplayer.is_server(): return
	_level.build_level()
	# Peers get the turn state once they report their part arrived, see _report_ready
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
	turn_manager.stop_monster_phase()
	turn_manager.clear_passes()
	for peer_id: int in _ready_peers: turn_manager.start_syncing_peer(peer_id)
	_player_controller_spawner.start_synching_players()
	return error

func stop_game() -> void:
	print_debug("Stopping running game...")
	_player_controller_spawner.stop_synching_players()
	SceneManager.to_main()

## Client: its own character and the tile under it arrived, so the host may lift its loading screen
func _has_own_part_arrived() -> bool:
	for child: Node in _player_controller_spawner.get_children():
		var player_controller: PlayerController = child as PlayerController
		if not player_controller or not player_controller.player.is_local_player() or not player_controller.character.is_inside_tree(): continue
		var cell: Vector2i = _level.world_to_grid_position(player_controller.character.global_position)
		return _level.get_placed_tile(cell) != null
	return false

func _on_part_arrived(_part: Node) -> void:
	# Deferred calls queued before the first report still arrive
	if _has_reported or not _has_own_part_arrived(): return
	_has_reported = true
	_player_controller_spawner.player_controller_created.disconnect(_on_part_arrived)
	_level.tile_placed.disconnect(_on_part_arrived)
	_report_ready.rpc_id(Multiplayer.HOST_ID)

## Sent by a client once its own character and the tile under it arrived
@rpc("any_peer", "reliable")
func _report_ready() -> void:
	if not multiplayer.is_server(): return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _ready_peers.has(peer_id): return
	_ready_peers[peer_id] = true
	TurnManager.get_instance(get_tree()).start_syncing_peer(peer_id)
	if _awaited_peers.erase(peer_id):
		_placed_count += 1
		peer_readiness_changed.emit()
		return
	# Joined the running game: in at once
	SceneManager.remove_loading_screen.rpc_id(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	if _awaited_peers.erase(peer_id): peer_readiness_changed.emit()

func _on_transition_progressed(ready_count: int, expected_count: int) -> void:
	if ready_count < expected_count: SceneManager.tell_transitioning_peers("Waiting for players [%d / %d]" % [ready_count, expected_count])

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
