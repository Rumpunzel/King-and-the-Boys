extends GdUnitTestSuite
## The combat HUD shows the monsters' turn, each block's dice, and a block's choice; it holds no rules

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const COMBAT_STATUS: String = "res://user_interface/hud/combat_status.tscn"

var _level: Level
var _turn_manager: TurnManager
var _status: CombatStatus

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	var spawner: PlayerControllerSpawner = auto_free(PlayerControllerSpawner.new())
	_status = auto_free((load(COMBAT_STATUS) as PackedScene).instantiate())
	_status.set("_turn_manager", _turn_manager)
	_status.set("_player_controller_spawner", spawner)
	add_child(_status)
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _figures() -> Array[Character]:
	var start: Vector2i = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var hero: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(start))))
	hero.level = _level
	add_child(hero)
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), start)
	await await_idle_frame()
	var monster: Character = ((_level.get("_agent_spawner") as AgentSpawner).get_children().back() as Agent).character
	return [hero, monster]

func _dice() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in (_status.get("_dice") as Container).get_children():
		if not child.is_queued_for_deletion(): buttons.append(child as Button)
	return buttons

func test_the_banner_shows_while_the_monsters_act() -> void:
	var banner: Control = _status.get("_banner")
	assert_bool(banner.visible).is_false()
	_turn_manager.phase = TurnManager.Phase.MONSTERS
	assert_bool(banner.visible).is_true()
	_turn_manager.phase = TurnManager.Phase.HEROES
	assert_bool(banner.visible).is_false()

func test_a_blocks_dice_show_with_the_one_that_counts() -> void:
	var figures: Array[Character] = await _figures()
	var dice: Array[int] = [Block.Face.PUSH, Block.Face.DEFENDER_DOWN]
	_turn_manager.block_shown.emit(figures[0], figures[1], dice, Block.Face.DEFENDER_DOWN)
	assert_bool((_status.get("_block_panel") as Control).visible).is_true()
	var buttons: Array[Button] = _dice()
	assert_int(buttons.size()).is_equal(2)
	assert_str(buttons[1].text).is_equal("★ Test monster falls")
	assert_bool(buttons[0].disabled).is_true()

func test_others_see_whose_choice_it_is_without_buttons_to_press() -> void:
	var figures: Array[Character] = await _figures()
	_turn_manager.block_choice = {
		TurnManager.CHOICE_PICKER: 99,
		TurnManager.CHOICE_ATTACKER: figures[0].get_path(),
		TurnManager.CHOICE_DEFENDER: figures[1].get_path(),
		TurnManager.CHOICE_DICE: [Block.Face.PUSH, Block.Face.ATTACKER_DOWN],
		TurnManager.CHOICE_WAYS: [],
	}
	assert_bool((_status.get("_block_panel") as Control).visible).is_true()
	var buttons: Array[Button] = _dice()
	assert_int(buttons.size()).is_equal(2)
	for button: Button in buttons: assert_bool(button.disabled).is_true()
	_turn_manager.block_choice = {}
	assert_bool((_status.get("_block_panel") as Control).visible).is_false()

func test_face_names_say_who_falls() -> void:
	assert_str(CombatStatus.face_name(Block.Face.ATTACKER_DOWN, "Knight", "Skeleton")).is_equal("Knight falls")
	assert_str(CombatStatus.face_name(Block.Face.DEFENDER_STUMBLES, "Knight", "Skeleton")).is_equal("Skeleton stumbles")
	assert_str(CombatStatus.face_name(Block.Face.BOTH_DOWN, "Knight", "Skeleton")).is_equal("Both fall")
