@tool
@icon("uid://2fcoorprkcjl")
class_name PlayerControllerSpawner
extends Spawner

signal player_controller_created(player_controller: PlayerController)

@export_group("Configuration")

# {player_id: int -> PlayerController}
var _player_controllers: Dictionary[int, PlayerController] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player_controller

func _ready() -> void:
	super._ready()

func start_synching_players() -> void:
	assert(multiplayer.is_server())
	var connected_players: Array[Player] = Lobby.get_connected_players()
	for connected_player: Player in connected_players:
		var spawning_queued: bool = spawn_player_controller(connected_player)
		if spawning_queued: return
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Lobby.player_created.connect(_on_player_created)

func stop_synching_players() -> void:
	assert(multiplayer.is_server())
	_remove_all_player_controllers()
	if Lobby.player_created.is_connected(_on_player_created): Lobby.player_created.disconnect(_on_player_created)

## @returns [code]true[/code] if spawning is queued for later
func spawn_player_controller(player: Player) -> bool:
	assert(multiplayer.is_server())
	assert(player)
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	## Level not yet loaded, queue spawning for later
	if all_player_spawn_points.is_empty():
		get_tree().node_added.connect(_on_node_added)
		return true
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	var character_data: Dictionary[StringName, Variant] = player_spawn_point.get_character_data(player.character, 0, player.body)
	var player_controller_data: Dictionary[StringName, Variant] = {
		PlayerController.PLAYER_ID: player.player_id,
		PlayerController.CHARACTER_DATA: character_data,
	}
	PlayerController.validate_player_controller_data(player_controller_data)
	spawn(player_controller_data)
	return false

func get_all_node_data() -> Array[Variant]:
	var player_controllers_data: Array[Variant] = []
	for player_controller: PlayerController in _player_controllers.values():
		player_controllers_data.append(player_controller.to_player_controller_data())
	return player_controllers_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_player_controller_paths: Array[NodePath] = []
	for player_controller: PlayerController in _player_controllers.values():
		removed_player_controller_paths.append(player_controller.get_path())
		_remove_player_controller(player_controller.player.player_id)
	return removed_player_controller_paths

func _spawn_player_controller(player_controller_data: Dictionary[StringName, Variant]) -> PlayerController:
	PlayerController.validate_player_controller_data(player_controller_data)
	var player_id: int = player_controller_data[PlayerController.PLAYER_ID]
	var player: Player = Lobby.get_player(player_id)
	assert(player)
	var character_data: Dictionary[StringName, Variant] = player_controller_data[PlayerController.CHARACTER_DATA]
	character_data[Character.VARIATION] = -1
	var player_controller: PlayerController = PlayerController.create(player, character_data)
	assert(not _player_controllers.has(player_id))
	_player_controllers[player_id] = player_controller
	return player_controller

func _remove_all_player_controllers() -> void:
	remove_all_spawned_nodes()

func _remove_player_controller(player_id: int) -> void:
	var player_controller_weakref: WeakRef = weakref(_player_controllers.get(player_id))
	var player_controller: PlayerController = player_controller_weakref.get_ref()
	_player_controllers.erase(player_id)
	if not player_controller: return
	remove_child(player_controller)
	player_controller.queue_free()

func _on_node_added(node: Node) -> void:
	if not node.is_in_group("PlayerSpawnPoints"): return
	get_tree().node_added.disconnect(_on_node_added)
	#start_synching_players()

func _on_child_entered_tree(node: Node) -> void:
	if not node is PlayerController: return
	player_controller_created.emit(node)

func _on_player_created(player: Player) -> void:
	if not _player_controllers.has(player.player_id):
		spawn_player_controller(player)
		return
	var existing_player_controller: PlayerController = _player_controllers[player.player_id]
	player.character = existing_player_controller.character.profile
	player.body = existing_player_controller.character.body
	existing_player_controller.player = player

func _on_peer_disconnected(_player_id: int) -> void:
	return

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
