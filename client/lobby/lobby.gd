@tool
@icon("uid://bsnfjvi6jpfrm")
extends Spawner

signal player_connected(player: Player)
signal player_disconnected(player: Player)

signal player_created(player: Player)
## A player's hero or [member Player.ready_to_start] changed, or a player joined or left
signal readiness_changed

## The heroes players pick from; without one, no heroes are assigned or checked. Set on the host, it gives every
## player still without a hero a free one, e.g. those who joined before the lobby menu set it
var hero_roster: HeroRoster:
	set(new_hero_roster):
		hero_roster = new_hero_roster
		if Engine.is_editor_hint() or not hero_roster or not picks_open or not is_multiplayer_authority(): return
		for player: Player in _players.values():
			if not player.character: pick_random(player)
## Whether players may still pick heroes and get ready; closed once the game is about to start
var picks_open: bool = true

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
	if local_player: return local_player
	for player: Player in get_connected_players():
		if player.is_local_player(): return player
	# E.g. a client asking before its own player reached it
	push_error("No local player in the lobby yet (looked up as %d)" % local_player_id)
	return null

## The player holding the hero, null if it is free
func get_holder(profile: CharacterProfile) -> Player:
	if not profile: return null
	for player: Player in _players.values():
		if player.character == profile: return player
	return null

## The roster's heroes no player but [param for_player] holds, in roster order
func get_free_heroes(for_player: Player) -> Array[CharacterProfile]:
	var free_heroes: Array[CharacterProfile] = []
	if not hero_roster: return free_heroes
	for hero: CharacterProfile in hero_roster.heroes:
		var holder: Player = get_holder(hero)
		if not holder or holder == for_player: free_heroes.append(hero)
	return free_heroes

## Host side: gives the player the hero if picks are open, it is in the roster, nobody else holds it and the player
## is not ready yet
func try_pick(player: Player, profile: CharacterProfile) -> bool:
	if not picks_open or not hero_roster or not hero_roster.has(profile): return false
	if player.ready_to_start: return false
	var holder: Player = get_holder(profile)
	if holder and holder != player: return false
	player.character = profile
	return true

## Host side: picks a free hero at random for the player, another one than they hold unless it is the only one free
func pick_random(player: Player) -> bool:
	var free_heroes: Array[CharacterProfile] = get_free_heroes(player)
	if free_heroes.size() > 1: free_heroes.erase(player.character)
	if free_heroes.is_empty(): return false
	var hero: CharacterProfile = free_heroes.pick_random()
	return try_pick(player, hero)

## Host side: gives the player a free hero of the roster at random, whether picks are open or not (e.g. a player
## joining as the game starts or into a running game, who needs one for their character); false without a roster or a
## free hero
func assign_free_hero(player: Player) -> bool:
	var free_heroes: Array[CharacterProfile] = get_free_heroes(player)
	if free_heroes.is_empty(): return false
	player.character = free_heroes.pick_random()
	return true

## Host side: marks a client's player with a hero ready or not while picks are open; offline and the host need no ready
func try_set_ready(player: Player, new_ready_to_start: bool) -> bool:
	if not Multiplayer.is_online() or not picks_open or player.is_host() or not player.character: return false
	player.ready_to_start = new_ready_to_start
	return true

## Stops picks and ready changes, e.g. as the game starts
func close_picks() -> void:
	picks_open = false

## Whether the game may start: offline always, online once every connected peer's player is ready
func can_start() -> bool:
	if not Multiplayer.is_online(): return true
	return _can_start_with(multiplayer.get_peers())

## How many connected peers' players are ready; the host is no peer of its own
func get_ready_count() -> int:
	return _count_ready(multiplayer.get_peers())

func _can_start_with(peers: PackedInt32Array) -> bool:
	return _count_ready(peers) == peers.size()

func _count_ready(peers: PackedInt32Array) -> int:
	var ready_count: int = 0
	for peer_id: int in peers:
		var player: Player = get_player(peer_id)
		if player and player.ready_to_start: ready_count += 1
	return ready_count

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
	player.tree_exited.connect(_on_player_exited.bind(player))
	if is_multiplayer_authority() and hero_roster and picks_open: pick_random(player)
	# Runs on every peer (the spawner's spawn function), so each one hears of the new player and its changes
	player.player_info_changed.connect(readiness_changed.emit)
	readiness_changed.emit()
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
	var toaster: Toaster = Toaster.new()
	toaster._vertical_position = Toaster.VerticalPosition.BOTTOM
	toaster._gravity = Toaster.Gravity.BOTTOM
	player_connected.connect(func(player: Player) -> void: toaster.toast_success("%s joined!" % player.player_name))
	player_disconnected.connect(func(player: Player) -> void: toaster.toast_info("%s left!" % player.player_name))
	add_child(toaster)

func _on_game_started() -> void:
	picks_open = true
	_create_local_player()

func _on_game_stopped() -> void:
	_remove_all_players()

func _on_disconnected_from_multiplayer() -> void:
	_remove_all_players(true)

func _on_joining_multiplayer() -> void:
	picks_open = true
	_remove_all_players()

func _on_player_joined(player_info: Dictionary[StringName, Variant]) -> void:
	if not is_multiplayer_authority(): return
	Player.validate_player_info(player_info)
	spawn(player_info)
	var player_id: int = player_info[Player.ID]
	var connected_player: Player = get_player(player_id)
	player_connected.emit(connected_player)

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_multiplayer_authority(): return
	var disconnected_player: Player = get_player(peer_id)
	if not disconnected_player:
		printerr("Host disconnected!")
		return
	_remove_player(disconnected_player)
	player_disconnected.emit(disconnected_player)
	print_debug("Player with player_id %d disconnected!" % peer_id)

## On every peer, whoever removed the player (the host, or the spawner despawning it on a client)
func _on_player_exited(player: Player) -> void:
	if _players.get(player.player_id) == player: _players.erase(player.player_id)
	readiness_changed.emit()

func _on_server_disconnected() -> void:
	_remove_all_players()
