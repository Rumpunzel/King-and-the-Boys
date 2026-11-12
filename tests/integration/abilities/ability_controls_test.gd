extends GdUnitTestSuite
## The local player's ability controls on a generated level (no assets): arming lifts the tile, the aiming state turns it,
## sets it down or cancels it, and the held cost reaches the character

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const SPAWNER_SCENE: String = "res://engine/player/player_controller_spawner.tscn"
const TURN_TILE: RotateTileAbility = preload("res://tests/fixtures/turn_tile.tres")

var _level: Level
var _spawner: PlayerControllerSpawner
var _turn_manager: TurnManager
var _local_player: Player
var _local_character: CharacterProfile
var _hero_profile: CharacterProfile
var _original_abilities: Array[Ability]

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_local_player = Lobby.get_player(Multiplayer.HOST_ID)
	_local_character = _local_player.character
	_hero_profile = ModelFreeWorld.load_hero_profile()
	# The profile is cached: restored after each test
	_original_abilities = _hero_profile.abilities
	_hero_profile.abilities = [TURN_TILE]
	_local_player.character = _hero_profile
	_level = auto_free(ModelFreeWorld.create_level())
	_spawner = auto_free((load(SPAWNER_SCENE) as PackedScene).instantiate())
	_spawner.set("_level", _level)
	_spawner.player_controller_created.connect(_level._on_player_controller_created)
	add_child(_spawner)
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await await_idle_frame()
	_spawner.start_synching_players()
	await await_idle_frame()

func after_test() -> void:
	_spawner.stop_synching_players()
	_local_player.character = _local_character
	_hero_profile.abilities = _original_abilities
	await await_idle_frame()

func _controller() -> PlayerController:
	for child: Node in _spawner.get_children():
		if child is PlayerController and not child.is_queued_for_deletion(): return child as PlayerController
	return null

func _state_of(controller: PlayerController) -> PlayerState:
	var state_machine: PlayerStateMachine = controller.get("_state_machine")
	return state_machine.get_state()

## Puts [param hero] on a revealed tile near the start that a quarter turn changes, with moves to spare
func _stand_on_turnable_tile(hero: Character) -> Structure:
	var placed_tiles: Dictionary = _level.get("_placed_tiles")
	var start: Vector2i = hero.grid_cell
	var best: Structure = null
	for cell: Vector2i in placed_tiles:
		var tile: Structure = placed_tiles[cell]
		if tile.profile.resource_path == ModelFreeWorld.WALL_TILE: continue
		if ModelFreeWorld.turned_connections(tile, 1) == ModelFreeWorld.turned_connections(tile, 0): continue
		if not best or cell.distance_squared_to(start) < best.get_grid_position().distance_squared_to(start): best = tile
	assert_object(best).is_not_null()
	hero.place_on_grid(best.get_grid_position(), Vector2.ZERO, hero.facing)
	hero.movement_points = 8
	return best

func test_arming_lifts_the_tile_and_aims_until_it_is_set_down() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	var turns: int = tile.clockwise_turns
	assert_bool(controller.can_arm(TURN_TILE)).is_true()
	controller.arm_ability(TURN_TILE)
	await await_idle_frame()
	assert_bool(tile.lifted_by == hero.get_path()).is_true()
	assert_object(_state_of(controller)).is_instanceof(PlayerStateAiming)
	assert_int(hero.held_cost).is_equal(0)
	# Nothing to undo while the tile hangs, and steps are not read
	assert_bool(controller.can_undo()).is_false()
	controller.adjust_ability(1)
	assert_int(tile.lift_turns).is_equal(1)
	assert_int(hero.held_cost).is_equal(1)
	controller.adjust_ability(-1)
	controller.adjust_ability(-1)
	assert_int(tile.lift_turns).is_equal(3)
	assert_int(hero.held_cost).is_equal(1)
	controller.confirm_ability()
	await await_idle_frame()
	assert_bool(tile.is_lifted()).is_false()
	assert_int(tile.clockwise_turns).is_equal(posmod(turns + 3, 4))
	assert_int(hero.movement_points).is_equal(7)
	assert_int(hero.held_cost).is_equal(0)
	assert_object(_state_of(controller)).is_instanceof(PlayerStateDefault)
	# The tile can be lifted again at once
	assert_bool(controller.can_arm(TURN_TILE)).override_failure_message("The ability can be armed again after setting the tile down").is_true()

func test_pressing_the_ability_again_cancels_it_for_free() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	var turns: int = tile.clockwise_turns
	controller.arm_ability(TURN_TILE)
	controller.adjust_ability(1)
	assert_bool(controller.can_arm(TURN_TILE)).is_true()
	controller.arm_ability(TURN_TILE)
	await await_idle_frame()
	assert_bool(tile.is_lifted()).is_false()
	assert_int(tile.clockwise_turns).is_equal(turns)
	assert_int(hero.movement_points).is_equal(8)
	assert_int(hero.held_cost).is_equal(0)
	assert_object(_state_of(controller)).is_instanceof(PlayerStateDefault)

func test_aiming_keys_turn_set_down_and_cancel() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	controller.arm_ability(TURN_TILE)
	await await_idle_frame()
	var aiming: PlayerState = _state_of(controller)
	var press: InputEventAction = InputEventAction.new()
	press.pressed = true
	press.action = &"rotate_right"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(1)
	press.action = &"rotate_left"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(0)
	press.action = &"move_up"
	aiming.handle_input(press)
	press.pressed = false
	aiming.handle_input(press)
	assert_int(hero.movement_points).is_equal(8)
	press.pressed = true
	press.action = &"cancel_ability"
	aiming.handle_input(press)
	await await_idle_frame()
	assert_bool(tile.is_lifted()).is_false()
	assert_object(_state_of(controller)).is_instanceof(PlayerStateDefault)

func test_angles_out_of_reach_are_skipped() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	hero.movement_points = 1
	controller.arm_ability(TURN_TILE)
	controller.adjust_ability(1)
	# A half turn costs 2: on to three quarters
	controller.adjust_ability(1)
	assert_int(tile.lift_turns).is_equal(3)
	assert_int(hero.held_cost).is_equal(1)
	controller.cancel_ability()

func test_without_moves_or_for_passives_nothing_is_armed() -> void:
	var controller: PlayerController = _controller()
	# Out of moves, the player would pass on their own and the turn would start anew
	controller.auto_pass = false
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	hero.movement_points = 0
	assert_bool(controller.can_arm(TURN_TILE)).is_false()
	controller.arm_ability(TURN_TILE)
	assert_bool(tile.is_lifted()).is_false()
	hero.movement_points = 8
	var passive: Ability = Ability.new()
	passive.targeting = Ability.Targeting.NONE
	assert_bool(controller.can_arm(passive)).is_false()

func test_the_ability_bar_shows_and_arms_the_abilities() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	var ability_bar: AbilityBar = auto_free((load("res://user_interface/hud/ability_bar.tscn") as PackedScene).instantiate())
	add_child(ability_bar)
	ability_bar.player_controller = controller
	ability_bar.character = hero
	var buttons: Container = ability_bar.get("_buttons")
	var hint: Label = ability_bar.get("_aiming_hint")
	assert_int(buttons.get_child_count()).is_equal(1)
	var button: Button = buttons.get_child(0) as Button
	assert_str(button.text).starts_with(TURN_TILE.name)
	assert_bool(button.disabled).is_false()
	assert_bool(hint.visible).is_false()
	button.pressed.emit()
	await await_idle_frame()
	ability_bar.update()
	assert_bool(tile.is_lifted()).is_true()
	assert_bool(button.button_pressed).is_true()
	assert_bool(hint.visible).is_true()
	button.pressed.emit()
	await await_idle_frame()
	ability_bar.update()
	assert_bool(tile.is_lifted()).is_false()
	assert_bool(button.button_pressed).is_false()
	controller.auto_pass = false
	hero.movement_points = 0
	ability_bar.update()
	assert_bool(button.disabled).is_true()

func test_the_move_keys_turn_the_tile_until_the_mystic_faces_that_way() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	var tile: Structure = _stand_on_turnable_tile(hero)
	hero.facing = Level.Direction.UP
	controller.arm_ability(TURN_TILE)
	await await_idle_frame()
	var aiming: PlayerState = _state_of(controller)
	var press: InputEventAction = InputEventAction.new()
	press.pressed = true
	press.action = &"move_right"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(1)
	press.action = &"move_left"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(3)
	press.action = &"move_up"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(0)
	# Facing back costs 2: out of reach with 1 move
	hero.movement_points = 1
	press.action = &"move_down"
	aiming.handle_input(press)
	assert_int(tile.lift_turns).is_equal(0)
	controller.cancel_ability()

func test_a_move_key_held_from_aiming_does_not_step_when_let_go() -> void:
	var controller: PlayerController = _controller()
	var hero: Character = controller.get_controlled_character()
	_stand_on_turnable_tile(hero)
	var cell: Vector2i = hero.grid_cell
	var direction: Level.Direction = Level.Direction.UP
	for candidate: Level.Direction in Level.Direction.values():
		if controller.get_controlled_character().level.is_passage(cell, candidate): direction = candidate
	var action: StringName = [&"move_up", &"move_right", &"move_down", &"move_left"][direction]
	controller.arm_ability(TURN_TILE)
	await await_idle_frame()
	var key: InputEventAction = InputEventAction.new()
	key.action = action
	key.pressed = true
	_state_of(controller).handle_input(key)
	controller.cancel_ability()
	await await_idle_frame()
	var default: PlayerState = _state_of(controller)
	assert_object(default).is_instanceof(PlayerStateDefault)
	# Let go after aiming ended: no step
	key.pressed = false
	default.handle_input(key)
	assert_vector(hero.grid_cell).is_equal(cell)
	# Pressed and let go here, it steps
	key.pressed = true
	default.handle_input(key)
	key.pressed = false
	default.handle_input(key)
	assert_vector(hero.grid_cell).is_not_equal(cell)
