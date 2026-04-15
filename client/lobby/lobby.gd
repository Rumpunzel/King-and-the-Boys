@tool
@icon("uid://bsnfjvi6jpfrm")
extends Spawner

signal player_connected(player: Player)

## {PlayerId: int -> Plaer}
var _players: Dictionary[int, Player] = {}

func _enter_tree() -> void:
	spawn_path = get_path()
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Client.game_started.connect(_on_game_started)
	Client.game_stopped.connect(_on_game_stopped)
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)
	Multiplayer.player_joined.connect(_on_player_joined)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	super._ready()

func get_connected_players() -> Array[Player]: return _players.values()
func get_player(player_id: int) -> Player: return _players.get(player_id)

func get_local_player() -> Player:
	var local_player_id: int = Multiplayer.HOST_ID
	if Multiplayer.is_online(): local_player_id = multiplayer.get_unique_id()
	var local_player: Player = get_player(local_player_id)
	if not local_player:
		for player: Player in get_connected_players():
			if player.is_local_player(): return local_player
	assert(local_player)
	return local_player

func get_all_node_data() -> Array[Variant]:
	var player_data: Array[Variant] = []
	for player: Player in _players.values():
		player_data.append(player.get_player_info())
	return player_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_player_paths: Array[NodePath] = []
	var players: Array[Player] = _players.values()
	while not players.is_empty():
		var player: Player = players.pop_back()
		removed_player_paths.append(player.get_path())
		_remove_player(player)
	_players.clear()
	return removed_player_paths

func _spawn_player(player_info: Dictionary[StringName, Variant]) -> Player:
	Player.validate_player_info(player_info)
	var player: Player = Player.from_player_info(player_info)
	_players[player.player_id] = player
	player.ready.connect(player_connected.emit.bind(player))
	print_debug("Spawned player: %s" % player.get_player_info())
	return player

func _create_local_player() -> void:
	spawn(Player.get_local_player_info())

func _remove_all_players() -> void:
	for player_id: int in _players.keys():
		var player_weakref: WeakRef = weakref(_players.get(player_id))
		var player: Player = player_weakref.get_ref()
		if not player: continue
		_remove_player(player)

func _remove_player(player: Player) -> void:
	assert(player)
	assert(_players.has(player.player_id))
	_players.erase(player.player_id)
	remove_child(player)
	player.queue_free()
	print_debug("Removed player: %s!" % player.get_player_info())

func _on_game_started() -> void:
	_create_local_player()

func _on_game_stopped() -> void:
	_remove_all_players()

func _on_disconnected_from_multiplayer() -> void:
	_remove_all_players()

func _on_joining_multiplayer() -> void:
	_remove_all_players()

func _on_player_joined(player_info: Dictionary[StringName, Variant]) -> void:
	if not is_multiplayer_authority(): return
	Player.validate_player_info(player_info)
	spawn(player_info)

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_multiplayer_authority(): return
	var disconnected_player: Player = get_player(peer_id)
	if not disconnected_player:
		printerr("Host disconnected!")
		return
	_remove_player(disconnected_player)
	print_debug("Player with player_id %d disconnected!" % peer_id)

func _on_server_disconnected() -> void:
	_remove_all_players()
