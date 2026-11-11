@tool
@icon("uid://2fcoorprkcjl")
class_name PlayerControllerSpawner
extends Spawner

signal player_controller_created(player_controller: PlayerController)

@export_group("Configuration")
## Spawning waits for it to be built
@export var _level: Level

# {player_id: int -> PlayerController}
var _player_controllers: Dictionary[int, PlayerController] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player_controller

## Host only: spawns a [PlayerController] for every connected player who has none yet (at once, or once the
## level is built) and for players who join later. Safe to call again, e.g. after loading.
func start_synching_players() -> void:
	assert(multiplayer.is_server())
	assert(_level)
	if not Lobby.player_created.is_connected(_on_player_created): Lobby.player_created.connect(_on_player_created)
	if _level.is_built: _spawn_missing_players()
	elif not _level.built.is_connected(_spawn_missing_players): _level.built.connect(_spawn_missing_players, CONNECT_ONE_SHOT)

## Host only: undoes [method start_synching_players] and removes every [PlayerController]
func stop_synching_players() -> void:
	assert(multiplayer.is_server())
	if Lobby.player_created.is_connected(_on_player_created): Lobby.player_created.disconnect(_on_player_created)
	if _level and _level.built.is_connected(_spawn_missing_players): _level.built.disconnect(_spawn_missing_players)
	remove_all_spawned_nodes()

## Host only; needs the level built
func spawn_player_controller(player: Player) -> void:
	assert(multiplayer.is_server())
	assert(player)
	assert(not _player_controllers.has(player.player_id))
	assert(_level.is_built)
	var player_spawn_point: PlayerSpawnPoint = _get_player_spawn_point()
	assert(player_spawn_point)
	# Created on its own spot, so the figure shows there at once on every peer instead of moving there from the
	# center; characters spawned before (also in this loop) are in the tree already and hold theirs
	var cell: Vector2i = _level.world_to_grid_position(player_spawn_point.global_position)
	var free_spots: Array[Vector2] = _level.get_free_spots(cell)
	var spot: Vector2 = free_spots.front() if not free_spots.is_empty() else Vector2.ZERO
	var spawn_transform: Transform3D = Transform3D(player_spawn_point.global_basis, _level.get_spot_position(cell, spot))
	var character_data: Dictionary[StringName, Variant] = player.character.create_character_data(0, spawn_transform, player.body)
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

func _spawn_missing_players() -> void:
	for player: Player in Lobby.get_connected_players():
		if not _player_controllers.has(player.player_id): spawn_player_controller(player)

func _on_child_entered_tree(node: Node) -> void:
	if not node is PlayerController: return
	player_controller_created.emit(node)

func _on_player_created(player: Player) -> void:
	if not _player_controllers.has(player.player_id):
		# Before the level is built, its built signal spawns every missing player
		if _level.is_built: spawn_player_controller(player)
		return
	var existing_player_controller: PlayerController = _player_controllers[player.player_id]
	player.character = existing_player_controller.character.profile
	player.body = existing_player_controller.character.body
	existing_player_controller.player = player

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _level: warnings.append("Missing Level reference.")
	return warnings
