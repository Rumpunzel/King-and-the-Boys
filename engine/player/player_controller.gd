@tool
@icon("uid://nl71yast8tsi")
class_name PlayerController
extends Node

const PLAYER_ID: StringName = "player_id"
const CHARACTER_DATA: StringName = "character_data"

const _ACTIVE_CAMERA_PRIORITY: int = 16
const _DEFAULT_CAMERA_PRIORITY: int = 1
const _INACTIVE_CAMERA_PRIORITY: int = 0

@export var player: Player:
	set(new_player):
		assert(new_player)
		player = new_player
		set_multiplayer_authority(player.get_multiplayer_authority())
		# The host owns the grid state of every piece
		character.give_grid_state_to_host()
		name = player.name
		_camera.current = player.is_local_player()

@export_group("Configuration")
@export var character: Character
@export var _state_machine: PlayerStateMachine
@export var _camera: Camera3D

## Passes for the player once the character is out of moves and its figure arrived;
## undo takes such a pass back. Without moves and without a step to undo, the player passes either way.
## Only acts on the local player's peer.
var auto_pass: bool = true:
	set(new_auto_pass):
		auto_pass = new_auto_pass
		_auto_pass_if_out_of_moves()

# The target and choice of the held ability this player armed; the host keeps its own and checks every request
var _ability_target: Vector2i = Vector2i.ZERO
var _ability_argument: int = 0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Every peer shows who has passed
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if turn_manager:
		turn_manager.passed_players_changed.connect(_on_passed_players_changed)
		_on_passed_players_changed()
	if not is_multiplayer_authority(): return
	_state_machine.start()
	character.movement_points_changed.connect(_on_turn_state_changed)
	character.undo_steps_changed.connect(_on_turn_state_changed)
	_auto_pass_if_out_of_moves()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.physics_update(delta)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.handle_input(event)

static func create(for_player: Player, character_data: Dictionary[StringName, Variant]) -> PlayerController:
	assert(for_player)
	var scene: PackedScene = load("uid://ckcrpkujohkql")
	var new_player_controller: PlayerController = scene.instantiate()
	new_player_controller.player = for_player
	assert(new_player_controller.character)
	new_player_controller.character.apply_character_data(character_data)
	return new_player_controller

static func validate_player_controller_data(player_controller_data: Dictionary[StringName, Variant]) -> void:
	assert(player_controller_data.has_all([PLAYER_ID, CHARACTER_DATA]))
	assert(player_controller_data.size() == 2)

func to_player_controller_data() -> Dictionary[StringName, Variant]:
	assert(player)
	assert(character)
	var character_data: Dictionary[StringName, Variant] = character.to_character_data()
	var player_controller_data: Dictionary[StringName, Variant] = {
		PLAYER_ID: player.player_id,
		CHARACTER_DATA: character_data,
	}
	validate_player_controller_data(player_controller_data)
	return player_controller_data

func get_active_camera_priority() -> int:
	return _ACTIVE_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

func get_default_camera_priority() -> int:
	return _DEFAULT_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

func _on_passed_players_changed() -> void:
	if player: character.show_passed(has_passed())

## Takes back the character's last step; a pass is taken back first
func request_undo() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or not can_undo(): return
	# The host takes a pass back along with a successful undo
	turn_manager.request_undo.rpc_id(Multiplayer.HOST_ID, character.get_path())

## Passes, or takes a pass back while that is still possible
func request_pass(passed: bool) -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or passed == has_passed(): return
	if not passed and must_pass(): return
	turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, passed)

func has_passed() -> bool:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	return turn_manager != null and turn_manager.has_passed(player.player_id)

## Nothing can be undone while a held ability is in use: it is cancelled instead
func can_undo() -> bool:
	return character.undo_steps > 0 and character.active_ability_id.is_empty()

## Whether the character could use [param ability] now; the held ability in use can always be pressed again,
## which cancels it. Uses per turn are counted on the host only, which checks again.
func can_arm(ability: Ability) -> bool:
	if ability.is_passive() or has_passed(): return false
	if not character.active_ability_id.is_empty(): return character.active_ability_id == ResourceId.of(ability)
	if ability.get_charges_left(character) == 0 or not character.level: return false
	var targets: Array[Vector2i] = ability.get_targets(character, character.level)
	if targets.is_empty(): return false
	if ability.held: return ability.can_begin(character, targets[0], character.level)
	return ability.get_cost(character, targets[0], 0) <= character.movement_points and ability.can_use(character, targets[0], 0, character.level)

## Uses [param ability] of the character on its first target: a [member Ability.held] one begins (the tile
## lifts) and waits for [method adjust_ability] and [method confirm_ability]; pressed again, it is cancelled
func arm_ability(ability: Ability) -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or not can_arm(ability): return
	var ability_id: String = ResourceId.of(ability)
	if character.active_ability_id == ability_id:
		cancel_ability()
		return
	_ability_target = ability.get_targets(character, character.level)[0]
	_ability_argument = 0
	if ability.held: turn_manager.request_ability_begin.rpc_id(Multiplayer.HOST_ID, character.get_path(), ability_id, _ability_target)
	else: turn_manager.request_ability.rpc_id(Multiplayer.HOST_ID, character.get_path(), ability_id, _ability_target, _ability_argument)

## Steps the choice of the held ability in use by [param step] (e.g. a quarter turn clockwise for [code]1[/code]),
## skipping choices the character can not pay for
func adjust_ability(step: int) -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	var ability: Ability = character.get_ability(character.active_ability_id)
	if not turn_manager or not ability: return
	var next_argument: int = ability.get_next_argument(character, _ability_target, _ability_argument, step)
	if next_argument == _ability_argument: return
	_ability_argument = next_argument
	turn_manager.request_ability_adjust.rpc_id(Multiplayer.HOST_ID, character.get_path(), _ability_argument)

## Points the held ability in use towards [param direction] (the Mystic's tile turns until they face it), if the
## character can pay for that
func aim_ability_towards(direction: Level.Direction) -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	var ability: Ability = character.get_ability(character.active_ability_id)
	if not turn_manager or not ability: return
	var argument: int = ability.get_argument_towards(character, _ability_target, direction)
	if argument < 0 or argument == _ability_argument: return
	if ability.get_cost(character, _ability_target, argument) > character.movement_points: return
	_ability_argument = argument
	turn_manager.request_ability_adjust.rpc_id(Multiplayer.HOST_ID, character.get_path(), _ability_argument)

## Ends the held ability in use with its current choice (sets the tile down); one that would change nothing is cancelled
func confirm_ability() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or character.active_ability_id.is_empty(): return
	turn_manager.request_ability.rpc_id(Multiplayer.HOST_ID, character.get_path(), character.active_ability_id, _ability_target, _ability_argument)

## Stops the held ability in use without paying for it
func cancel_ability() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or character.active_ability_id.is_empty(): return
	turn_manager.request_ability_cancel.rpc_id(Multiplayer.HOST_ID, character.get_path())

## @returns [code]true[/code] if the character has nothing left to do: no moves, no step to undo
func must_pass() -> bool:
	return character.movement_points == 0 and character.undo_steps == 0

func _auto_pass_if_out_of_moves() -> void:
	if not is_node_ready() or not is_multiplayer_authority(): return
	if character.movement_points != 0: return
	if not auto_pass and not must_pass(): return
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or has_passed(): return
	# Pass when the figure arrived: passing ends the turn at once if everyone else passed, and moves reset
	if character.is_figure_moving():
		if not character.figure_arrived.is_connected(_auto_pass_if_out_of_moves): character.figure_arrived.connect(_auto_pass_if_out_of_moves, CONNECT_ONE_SHOT)
		return
	# The host checks the moves again: this peer may still see the last turn's moves
	turn_manager.request_auto_pass.rpc_id(Multiplayer.HOST_ID, character.get_path())

func _on_turn_state_changed(_value: int) -> void:
	# Deferred: on the host the points change just before the step that starts the figure moving
	_auto_pass_if_out_of_moves.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not character: warnings.append("Missing Character reference.")
	if not _state_machine: warnings.append("Missing PlayerStateMachine reference.")
	if not _camera: warnings.append("Missing Camera3D reference.")
	return warnings
