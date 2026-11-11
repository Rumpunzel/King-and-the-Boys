extends GdUnitTestSuite
## The Lobby keeps one Player per peer: a joining player is spawned and announced, a leaving one removed and
## announced, and the local player is found

const JOINING_ID: int = 5

var _connected: Array[Player] = []
var _disconnected: Array[Player] = []
var _created: Array[Player] = []

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

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

func test_the_local_player_is_found_under_another_id() -> void:
	# E.g. a client whose own player is not under the id it looks it up by; offline every player counts as local
	var players: Dictionary = Lobby.get("_players")
	var host: Player = players[Multiplayer.HOST_ID]
	var joined: Player = await _join()
	players.erase(Multiplayer.HOST_ID)
	var found: Player = Lobby.get_local_player()
	players[Multiplayer.HOST_ID] = host
	assert_object(found).is_same(joined)
