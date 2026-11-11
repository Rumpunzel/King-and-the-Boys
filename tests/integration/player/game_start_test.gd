extends GdUnitTestSuite
## Starting a hosted game: a client is ready once its own character and the tile under it arrived; the host
## waits for the peers it sent, not for those that leave

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const SPAWNER_SCENE: String = "res://engine/player/player_controller_spawner.tscn"
const OTHER_PEER_ID: int = 2

var _level: Level
var _spawner: PlayerControllerSpawner
var _game: Game
var _local_player: Player
var _local_character: CharacterProfile

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_local_player = Lobby.get_player(Multiplayer.HOST_ID)
	_local_character = _local_player.character
	_local_player.character = ModelFreeWorld.load_hero_profile()
	_level = auto_free(ModelFreeWorld.create_level())
	_spawner = auto_free((load(SPAWNER_SCENE) as PackedScene).instantiate())
	_spawner.set("_level", _level)
	_spawner.player_controller_created.connect(_level._on_player_controller_created)
	add_child(_level)
	add_child(_spawner)
	# Not in the tree: only its checks are used, not its start-up
	_game = auto_free(Game.new())
	_game.set("_level", _level)
	_game.set("_player_controller_spawner", _spawner)
	await await_idle_frame()

func after_test() -> void:
	_spawner.stop_synching_players()
	_local_player.character = _local_character
	await await_idle_frame()

func test_a_client_is_ready_once_its_character_and_tile_arrived() -> void:
	assert_bool(_game.call("_has_own_part_arrived")).is_false()
	_level.build_level()
	assert_bool(_game.call("_has_own_part_arrived")).is_false()
	_spawner.start_synching_players()
	await await_idle_frame()
	assert_bool(_game.call("_has_own_part_arrived")).is_true()

func test_the_host_does_not_wait_for_a_peer_that_left() -> void:
	var awaited_peers: Dictionary = _game.get("_awaited_peers")
	awaited_peers[OTHER_PEER_ID] = true
	var changes: Array[bool] = []
	_game.peer_readiness_changed.connect(func() -> void: changes.append(true))
	_game.call("_on_peer_disconnected", OTHER_PEER_ID)
	assert_bool(awaited_peers.is_empty()).is_true()
	assert_int(changes.size()).is_equal(1)

func test_a_peer_that_is_not_awaited_changes_nothing_when_it_leaves() -> void:
	var changes: Array[bool] = []
	_game.peer_readiness_changed.connect(func() -> void: changes.append(true))
	_game.call("_on_peer_disconnected", OTHER_PEER_ID)
	assert_int(changes.size()).is_equal(0)

func test_a_client_checks_its_character_only_once_it_is_in_the_tree() -> void:
	_level.build_level()
	# As a client sees it: the controller enters the tree before its character does
	var checks: Array[bool] = []
	var check: Callable = func(_player_controller: PlayerController) -> void: checks.append(_game.call("_has_own_part_arrived"))
	_spawner.player_controller_created.connect(check)
	_spawner.start_synching_players()
	_spawner.player_controller_created.disconnect(check)
	await await_idle_frame()
	assert_array(checks).contains_exactly([false])
	assert_bool(_game.call("_has_own_part_arrived")).is_true()
