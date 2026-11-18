extends GdUnitTestSuite
## Passing, taking a pass back and ending the turn; no level or assets needed

const OTHER_PLAYER_ID: int = 2

var _turn_manager: TurnManager
var _other_player: Player
var _local_id: int
## The local player this suite created, removed again in after(): a player left in the Lobby holds a hero in later suites
var _own_local_player: Player

func before() -> void:
	if Lobby.get_connected_players().is_empty():
		Lobby.call("_create_local_player")
		_own_local_player = Lobby.get_player(Multiplayer.HOST_ID)

func after() -> void:
	if is_instance_valid(_own_local_player) and Lobby.get_player(Multiplayer.HOST_ID) == _own_local_player: Lobby.call("_remove_player", _own_local_player)
	await await_idle_frame()

func before_test() -> void:
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", auto_free(Level.new()))
	add_child(_turn_manager)
	_local_id = _turn_manager.multiplayer.get_unique_id()
	_other_player = auto_free(Player.create(OTHER_PLAYER_ID, "Other"))
	_players()[OTHER_PLAYER_ID] = _other_player

func after_test() -> void:
	_players().erase(OTHER_PLAYER_ID)

func _players() -> Dictionary:
	return Lobby.get("_players")

func test_the_turn_waits_for_everyone_to_pass() -> void:
	_turn_manager.request_pass(true)
	assert_bool(_turn_manager.has_passed(_local_id)).is_true()
	assert_int(_turn_manager.turn_number).is_equal(1)

func test_a_pass_can_be_taken_back() -> void:
	_turn_manager.request_pass(true)
	_turn_manager.request_pass(false)
	assert_bool(_turn_manager.has_passed(_local_id)).is_false()

func test_the_turn_ends_once_the_last_other_player_leaves() -> void:
	_turn_manager.request_pass(true)
	_players().erase(OTHER_PLAYER_ID)
	Lobby.player_disconnected.emit(_other_player)
	assert_int(_turn_manager.turn_number).is_equal(2)
	assert_bool(_turn_manager.has_passed(_local_id)).is_false()

func test_loading_clears_passes() -> void:
	_turn_manager.request_pass(true)
	_turn_manager.clear_passes()
	assert_bool(_turn_manager.has_passed(_local_id)).is_false()
	assert_int(_turn_manager.turn_number).is_equal(1)
