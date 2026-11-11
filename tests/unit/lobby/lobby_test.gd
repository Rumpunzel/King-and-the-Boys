extends GdUnitTestSuite
## The Lobby keeps one Player per peer: a joining player is spawned and announced, a leaving one removed and
## announced, and the local player is found

const JOINING_ID: int = 5
## Where the host's own player is filed by mistake, so it is not found under its id
const WRONG_KEY: int = 9
const PORT: int = 47124

var _connected: Array[Player] = []
var _disconnected: Array[Player] = []
var _created: Array[Player] = []
## The local player this suite created, removed again in after()
var _own_local_player: Player

func before() -> void:
	if not Lobby.get_player(Multiplayer.HOST_ID):
		Lobby.call("_create_local_player")
		_own_local_player = Lobby.get_player(Multiplayer.HOST_ID)

func after() -> void:
	if is_instance_valid(_own_local_player) and Lobby.get_player(Multiplayer.HOST_ID) == _own_local_player: Lobby.call("_remove_player", _own_local_player)
	await await_idle_frame()

func before_test() -> void:
	_connected.clear()
	_disconnected.clear()
	_created.clear()
	Lobby.player_connected.connect(_on_connected)
	Lobby.player_disconnected.connect(_on_disconnected)
	Lobby.player_created.connect(_on_created)

func after_test() -> void:
	Lobby.player_connected.disconnect(_on_connected)
	Lobby.player_disconnected.disconnect(_on_disconnected)
	Lobby.player_created.disconnect(_on_created)
	var joined: Player = Lobby.get_player(JOINING_ID)
	if joined: Lobby.call("_remove_player", joined)
	await await_idle_frame()

func _on_connected(player: Player) -> void: _connected.append(player)
func _on_disconnected(player: Player) -> void: _disconnected.append(player)
func _on_created(player: Player) -> void: _created.append(player)

func _join() -> Player:
	var player_info: Dictionary[StringName, Variant] = {Player.ID: JOINING_ID, Player.NAME: "Joining"}
	Lobby.call("_on_player_joined", player_info)
	await await_idle_frame()
	return Lobby.get_player(JOINING_ID)

func test_a_joining_player_is_spawned_and_announced() -> void:
	var joined: Player = await _join()
	assert_object(joined).is_not_null()
	assert_str(joined.player_name).is_equal("Joining")
	assert_array(Lobby.get_connected_players()).contains([joined])
	assert_array(_connected).contains_exactly([joined])
	assert_array(_created).contains_exactly([joined])

func test_a_leaving_player_is_removed_and_announced() -> void:
	var joined: Player = await _join()
	Lobby.call("_on_peer_disconnected", JOINING_ID)
	assert_object(Lobby.get_player(JOINING_ID)).is_null()
	assert_array(_disconnected).contains_exactly([joined])
	# Gone from the tree too, not only from the registry
	assert_bool(joined.is_queued_for_deletion() or not joined.is_inside_tree()).is_true()

func test_the_local_player_is_found_under_another_key_and_others_are_skipped() -> void:
	# Online, so only the player of this peer counts as local (offline every player does)
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_int(server.create_server(PORT)).is_equal(OK)
	var offline: MultiplayerPeer = Lobby.multiplayer.multiplayer_peer
	Lobby.multiplayer.multiplayer_peer = server
	var joined: Player = await _join()
	var players: Dictionary = Lobby.get("_players")
	var host: Player = players.get(Multiplayer.HOST_ID)
	assert_object(host).is_not_null()
	players.erase(Multiplayer.HOST_ID)
	players[WRONG_KEY] = host
	var found: Player = Lobby.get_local_player()
	players.erase(WRONG_KEY)
	players[Multiplayer.HOST_ID] = host
	Lobby.multiplayer.multiplayer_peer = offline
	server.close()
	assert_object(found).is_same(host)
	assert_object(found).is_not_same(joined)
