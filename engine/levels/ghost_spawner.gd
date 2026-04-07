@tool
@icon("uid://2fcoorprkcjl")
class_name PlayerGhostSpawner
extends Spawner

@export_group("Configuration")

var _player_ghosts: Dictionary[Player, PlayerGhost] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player_ghost

func _ready() -> void:
	super._ready()

func start_synching_players() -> void:
	assert(multiplayer.is_server())
	var connected_players: Array[Player] = Lobby.get_connected_players()
	for connected_player: Player in connected_players:
		var spawning_queued: bool = spawn_player_ghost(connected_player)
		if spawning_queued: return
	Lobby.player_connected.connect(spawn_player_ghost)

func stop_synching_players() -> void:
	assert(multiplayer.is_server())
	_remove_all_player_ghosts()
	if Lobby.player_connected.is_connected(spawn_player_ghost):
		Lobby.player_connected.disconnect(spawn_player_ghost)

## @returns [code]true[/code] if spawning is queued for later
func spawn_player_ghost(player: Player) -> bool:
	assert(multiplayer.is_server())
	assert(player)
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group("PlayerSpawnPoints")
	## Level not yet loaded, queue spawning for later
	if all_player_spawn_points.is_empty():
		get_tree().node_added.connect(_on_node_added)
		return true
	assert(all_player_spawn_points.size() == 1)
	var character_spawn_point: CharacterSpawnPoint = all_player_spawn_points.front()
	assert(character_spawn_point)
	var character_data: Dictionary[StringName, Variant] = character_spawn_point.get_character_data()
	var player_ghost_data: Dictionary[StringName, Variant] = {
		PlayerGhost.PLAYER_ID: player.player_id,
		PlayerGhost.CHARACTER_DATA: character_data,
	}
	PlayerGhost.validate_player_ghost_data(player_ghost_data)
	spawn(player_ghost_data)
	return false

func get_all_node_data() -> Array[Variant]:
	var player_ghosts_data: Array[Variant] = []
	for player_ghost: PlayerGhost in _player_ghosts.values():
		player_ghosts_data.append(player_ghost.to_player_ghost_data())
	return player_ghosts_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_player_ghost_paths: Array[NodePath] = []
	for player_ghost: PlayerGhost in _player_ghosts.values():
		removed_player_ghost_paths.append(player_ghost.get_path())
		_remove_player_ghost(player_ghost)
	return removed_player_ghost_paths

func _spawn_player_ghost(player_ghost_data: Dictionary[StringName, Variant]) -> PlayerGhost:
	PlayerGhost.validate_player_ghost_data(player_ghost_data)
	var player_id: int = player_ghost_data[PlayerGhost.PLAYER_ID]
	var player: Player = Lobby.get_player(player_id)
	assert(player)
	var character_data: Dictionary[StringName, Variant] = player_ghost_data[PlayerGhost.CHARACTER_DATA]
	character_data[Character.VARIATION] = -1
	var player_ghost: PlayerGhost = PlayerGhost.create(player, character_data)
	assert(not _player_ghosts.has(player))
	_player_ghosts[player_ghost.player] = player_ghost
	player.tree_exiting.connect(_remove_player_ghost.bind(player_ghost))
	return player_ghost

func _remove_all_player_ghosts() -> void:
	remove_all_spawned_nodes()

func _remove_player_ghost(player_ghost: PlayerGhost) -> void:
	var player: Player = player_ghost.player
	_player_ghosts.erase(player)
	player.tree_exiting.disconnect(_remove_player_ghost.bind(player_ghost))
	remove_child(player_ghost)
	player_ghost.queue_free()

func _on_node_added(node: Node) -> void:
	if not node.is_in_group("PlayerSpawnPoints"): return
	get_tree().node_added.disconnect(_on_node_added)
	start_synching_players()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
