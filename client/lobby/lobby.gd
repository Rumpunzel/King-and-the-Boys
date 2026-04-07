@tool
@icon("uid://bsnfjvi6jpfrm")
extends Spawner

signal player_connected(player: Player)

func _enter_tree() -> void:
	spawn_path = get_path()
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_player
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)
	Multiplayer.player_joined.connect(_on_player_joined)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)
	Client.singleplayer_started.connect(_on_singleplayer_started)

func _ready() -> void:
	super._ready()

func get_connected_players() -> Array[Player]:
	var players: Array[Player] = []
	for child: Node in get_children():
		if child is Player: players.append(child)
	return players

func get_player(player_id: int) -> Player:
	for player: Player in get_connected_players():
		if player.player_id == player_id: return player
	return null

func get_local_player() -> Player:
	var local_player_id: int = Multiplayer.HOST_ID
	if Multiplayer.is_online(): local_player_id = multiplayer.get_unique_id()
	var local_player: Player = get_player(local_player_id)
	if not local_player:
		for player: Player in get_connected_players():
			if player.is_local_player(): return local_player
	assert(local_player)
	return local_player

func _spawn_player(player_info: Dictionary[StringName, Variant]) -> Player:
	Player.validate_player_info(player_info)
	var player: Player = Player.from_player_info(player_info)
	player.ready.connect(player_connected.emit.bind(player))
	print_debug("Spawned player: %s" % player.get_player_info())
	return player

func _create_local_player() -> void:
	spawn(Player.get_local_player_info())

func _remove_all_players() -> void:
	for player: Player in get_children():
		_remove_player(player)

func _remove_player(player: Player) -> void:
	assert(player)
	remove_child(player)
	player.queue_free()
	print_debug("Removed player: %s!" % player.get_player_info())

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

func _on_singleplayer_started() -> void:
	_create_local_player()
