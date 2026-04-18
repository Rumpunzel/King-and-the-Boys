@tool
@icon("uid://bsnfjvi6jpfrm")
extends Spawner

signal player_connected(player: Player)
signal player_disconnected(player: Player)

signal player_created(player: Player)

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
	_setup_toaster()

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
	player.ready.connect(player_created.emit.bind(player))
	print_debug("Spawned player: %s" % player.get_player_info())
	return player

func _create_local_player() -> void:
	spawn(Player.get_local_player_info())

func _remove_all_players(except_local_player: bool = false) -> void:
	for player_id: int in _players.keys():
		var player_weakref: WeakRef = weakref(_players.get(player_id))
		var player: Player = player_weakref.get_ref()
		if not player:
			_players.erase(player_id)
			continue
		if except_local_player and player.is_local_player(): continue
		_remove_player(player)

func _remove_player(player: Player) -> void:
	assert(player)
	assert(_players.has(player.player_id))
	_players.erase(player.player_id)
	remove_child(player)
	player.queue_free()
	print_debug("Removed player: %s!" % player.get_player_info())

func _setup_toaster() -> void:
	var _toaster: Toaster = Toaster.new()
	multiplayer.connection_failed.connect(_toaster.toast_error.bind("Connection failed!"))
	multiplayer.server_disconnected.connect(_toaster.toast_error.bind("Connection to server lost!"))
	Multiplayer.connected_to_multiplayer.connect(_toaster.toast_info.bind("Connecting to multiplayer..."))
	Multiplayer.disconnected_from_multiplayer.connect(_toaster.toast_warning.bind("Disconnected from multiplayer..."))
	Multiplayer.game_hosted.connect(func(_ip_address: StringName, _port: int) -> void: _toaster.toast_success("Game hosted!"))
	Multiplayer.joining_multiplayer.connect(_toaster.toast_info.bind("Joining multiplayer..."))
	Multiplayer.game_joined.connect(func(host_player_info: Dictionary) -> void: _toaster.toast_success("Joined %s's game!" % host_player_info[Player.NAME]))
	Multiplayer.player_joined.connect(func(player_info: Dictionary) -> void: _toaster.toast_success("%s joined!" % player_info[Player.NAME]))
	player_disconnected.connect(func(player: Player) -> void: _toaster.toast_warning("%s left!" % player.player_name))
	add_child(_toaster)

func _on_game_started() -> void:
	_create_local_player()

func _on_game_stopped() -> void:
	_remove_all_players()

func _on_disconnected_from_multiplayer() -> void:
	_remove_all_players(true)

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
	player_disconnected.emit(disconnected_player)
	print_debug("Player with player_id %d disconnected!" % peer_id)

func _on_server_disconnected() -> void:
	_remove_all_players()
