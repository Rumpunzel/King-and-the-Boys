@tool
@icon("uid://2fcoorprkcjl")
class_name PlayerControllerSpawner
extends Spawner

signal player_controller_created(player_controller: PlayerController)

# {player_id: int -> PlayerController}
var _player_controllers: Dictionary[int, PlayerController] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player_controller

## Host only: spawns a [PlayerController] for every connected player who has none yet (at once, or once the
## level is built) and for players who join later. Safe to call again, e.g. after loading.
func start_synching_players() -> void:
	assert(multiplayer.is_server())
	if not Lobby.player_created.is_connected(_on_player_created): Lobby.player_created.connect(_on_player_created)
	_spawn_missing_players_once_ready()

## Host only: undoes [method start_synching_players] and removes every [PlayerController]
func stop_synching_players() -> void:
	assert(multiplayer.is_server())
	if Lobby.player_created.is_connected(_on_player_created): Lobby.player_created.disconnect(_on_player_created)
	if get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.disconnect(_on_node_added)
	var level: Level = _get_level()
	if level and level.built.is_connected(_spawn_missing_players_once_ready): level.built.disconnect(_spawn_missing_players_once_ready)
	remove_all_spawned_nodes()

## Host only; needs the level's [PlayerSpawnPoint]
func spawn_player_controller(player: Player) -> void:
	assert(multiplayer.is_server())
	assert(player)
	assert(not _player_controllers.has(player.player_id))
	var player_spawn_point: PlayerSpawnPoint = _get_player_spawn_point()
	assert(player_spawn_point and player_spawn_point.is_ready())
	var character_data: Dictionary[StringName, Variant] = player_spawn_point.get_character_data(player.character, 0, player.body)
	var player_controller_data: Dictionary[StringName, Variant] = {
		PlayerController.PLAYER_ID: player.player_id,
		PlayerController.CHARACTER_DATA: character_data,
	}
	PlayerController.validate_player_controller_data(player_controller_data)
	spawn(player_controller_data)

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

func _remove_player_controller(player_id: int) -> void:
	var player_controller_weakref: WeakRef = weakref(_player_controllers.get(player_id))
	var player_controller: PlayerController = player_controller_weakref.get_ref()
	_player_controllers.erase(player_id)
	if not player_controller: return
	remove_child(player_controller)
	player_controller.queue_free()

func _get_player_spawn_point() -> PlayerSpawnPoint:
	var player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(player_spawn_points.size() <= 1)
	if player_spawn_points.is_empty(): return null
	var player_spawn_point: PlayerSpawnPoint = player_spawn_points.front()
	return player_spawn_point

func _get_level() -> Level:
	var player_spawn_point: PlayerSpawnPoint = _get_player_spawn_point()
	return player_spawn_point.get_level() if player_spawn_point else null

func _is_ready_to_spawn() -> bool:
	var player_spawn_point: PlayerSpawnPoint = _get_player_spawn_point()
	return player_spawn_point != null and player_spawn_point.is_ready()

## Spawning waits for the level: once it is in the tree, until it is built
func _spawn_missing_players_once_ready() -> void:
	if _is_ready_to_spawn():
		for player: Player in Lobby.get_connected_players():
			if not _player_controllers.has(player.player_id): spawn_player_controller(player)
		return
	var level: Level = _get_level()
	if level:
		if not level.built.is_connected(_spawn_missing_players_once_ready): level.built.connect(_spawn_missing_players_once_ready, CONNECT_ONE_SHOT)
	elif not get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not node.is_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS): return
	get_tree().node_added.disconnect(_on_node_added)
	_spawn_missing_players_once_ready()

func _on_child_entered_tree(node: Node) -> void:
	if not node is PlayerController: return
	player_controller_created.emit(node)

func _on_player_created(player: Player) -> void:
	if not _player_controllers.has(player.player_id):
		# Before the level is built, spawning waits for it and then spawns every missing player
		if _is_ready_to_spawn(): spawn_player_controller(player)
		return
	var existing_player_controller: PlayerController = _player_controllers[player.player_id]
	player.character = existing_player_controller.character.profile
	player.body = existing_player_controller.character.body
	existing_player_controller.player = player
