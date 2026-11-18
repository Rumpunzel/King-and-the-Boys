extends GdUnitTestSuite
## The local player's pass during a block: the host holds the board while a block plays, so the pass is sent once it ended

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const SPAWNER_SCENE: String = "uid://bvj0ntif5bqqq"  # engine/player/player_controller_spawner.tscn
const MAX_FRAMES: int = 3000

var _level: Level
var _spawner: PlayerControllerSpawner
var _turn_manager: TurnManager
var _local_player: Player
var _local_character: CharacterProfile

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_local_player = Lobby.get_player(Multiplayer.HOST_ID)
	_local_character = _local_player.character
	_local_player.character = ModelFreeWorld.load_hero_profile()
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	_level.spawns_monsters = false
	_spawner = auto_free((load(SPAWNER_SCENE) as PackedScene).instantiate())
	_spawner.set("_level", _level)
	_spawner.player_controller_created.connect(_level._on_player_controller_created)
	add_child(_spawner)
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	_turn_manager.choice_timeout = 0.0
	add_child(_turn_manager)
	await await_idle_frame()
	_spawner.start_synching_players()
	await await_idle_frame()

func after_test() -> void:
	_spawner.stop_synching_players()
	_local_player.character = _local_character
	await await_idle_frame()

func _controller() -> PlayerController:
	for child: Node in _spawner.get_children():
		if child is PlayerController and not child.is_queued_for_deletion(): return child as PlayerController
	return null

func test_a_pass_during_a_block_counts_once_it_ended() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var cell: Vector2i = hero.grid_cell
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var way: int = -1
	for direction: Level.Direction in Level.Direction.values():
		if _level.is_passage(cell, direction): way = direction
	assert_int(way).is_not_equal(-1)
	_turn_manager.request_move(hero.get_path(), way as Level.Direction)
	assert_dict(_turn_manager.block_state).is_not_empty()
	controller.request_pass(true)
	await await_idle_frame()
	# Held by the block, not lost
	assert_bool(controller.has_passed()).is_false()
	for _frame: int in MAX_FRAMES:
		if controller.has_passed() or _turn_manager.turn_number > 1: break
		await await_idle_frame()
	# Passed once the block ended: the only player, so the turn went on
	assert_bool(controller.has_passed() or _turn_manager.turn_number > 1).is_true()
