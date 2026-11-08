@tool
@icon("uid://nl71yast8tsi")
class_name PlayerGhost
extends Node

## Emitted on the local player's peer when the character they move changes, e.g. when haunting one
signal controlled_character_changed(controlled_character: Character)

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
		player.player_info_changed.connect(_on_player_info_changed)

@export_group("Configuration")
@export var character: Character
@export var _state_machine: PlayerStateMachine
@export var _camera: Camera3D

## Passes for the player once the controlled character is out of moves and its figure arrived;
## undo takes such a pass back. Without moves and without a step to undo, the player passes either way.
## Only acts on the local player's peer.
var auto_pass: bool = true:
	set(new_auto_pass):
		auto_pass = new_auto_pass
		_auto_pass_if_out_of_moves()

var _controlled_character: Character:
	set(new_controlled_character):
		if is_instance_valid(_controlled_character):
			_controlled_character.movement_points_changed.disconnect(_on_turn_state_changed)
			_controlled_character.undo_steps_changed.disconnect(_on_turn_state_changed)
		_controlled_character = new_controlled_character
		_controlled_character.movement_points_changed.connect(_on_turn_state_changed)
		_controlled_character.undo_steps_changed.connect(_on_turn_state_changed)
		_auto_pass_if_out_of_moves()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.controlled_character_changed.connect(_on_controlled_character_changed)
	_state_machine.start()
	_controlled_character = get_controlled_character()

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

static func create(for_player: Player, character_data: Dictionary[StringName, Variant]) -> PlayerGhost:
	assert(for_player)
	var scene: PackedScene = load("uid://ckcrpkujohkql")
	var new_player_ghost: PlayerGhost = scene.instantiate()
	new_player_ghost.player = for_player
	assert(new_player_ghost.character)
	new_player_ghost.character.apply_character_data(character_data)
	return new_player_ghost

static func validate_player_ghost_data(player_ghost_data: Dictionary[StringName, Variant]) -> void:
	assert(player_ghost_data.has_all([PLAYER_ID, CHARACTER_DATA]))
	assert(player_ghost_data.size() == 2)

func to_player_ghost_data() -> Dictionary[StringName, Variant]:
	assert(player)
	assert(character)
	var character_data: Dictionary[StringName, Variant] = character.to_character_data()
	var player_ghost_data: Dictionary[StringName, Variant] = {
		PLAYER_ID: player.player_id,
		CHARACTER_DATA: character_data,
	}
	validate_player_ghost_data(player_ghost_data)
	return player_ghost_data

func get_active_camera_priority() -> int:
	return _ACTIVE_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

func get_default_camera_priority() -> int:
	return _DEFAULT_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

## @returns the [Character] the player currently moves
func get_controlled_character() -> Character:
	return _state_machine.get_controlled_character()

## Takes back the controlled character's last step; a pass is taken back first
func request_undo() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or not can_undo(): return
	if has_passed(): turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, false)
	turn_manager.request_undo.rpc_id(Multiplayer.HOST_ID, get_controlled_character().get_path())

## Passes, or takes a pass back while that is still possible
func request_pass(passed: bool) -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or passed == has_passed(): return
	if not passed and must_pass(): return
	turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, passed)

func has_passed() -> bool:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	return turn_manager != null and turn_manager.has_passed(player.player_id)

func can_undo() -> bool:
	return get_controlled_character().undo_steps > 0

## @returns [code]true[/code] if the controlled character has nothing left to do: no moves, no step to undo
func must_pass() -> bool:
	var controlled_character: Character = get_controlled_character()
	return controlled_character.movement_points == 0 and controlled_character.undo_steps == 0

func _auto_pass_if_out_of_moves() -> void:
	if not is_node_ready() or not is_multiplayer_authority(): return
	if not is_instance_valid(_controlled_character) or _controlled_character.movement_points != 0: return
	if not auto_pass and not must_pass(): return
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or has_passed(): return
	# Pass when the figure arrived: passing ends the turn at once if everyone else passed, and moves reset
	if _controlled_character.is_figure_moving():
		if not _controlled_character.figure_arrived.is_connected(_auto_pass_if_out_of_moves): _controlled_character.figure_arrived.connect(_auto_pass_if_out_of_moves, CONNECT_ONE_SHOT)
		return
	turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, true)

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_controlled_character = controlled_character
	controlled_character_changed.emit(controlled_character)

func _on_turn_state_changed(_value: int) -> void:
	# Deferred: on the host the points change just before the step that starts the figure moving
	_auto_pass_if_out_of_moves.call_deferred()

func _on_player_info_changed() -> void:
	pass#character.variation = player.ghost_sprite_frame

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not character: warnings.append("Missing Character reference.")
	if not _state_machine: warnings.append("Missing PlayerStateMachine reference.")
	if not _camera: warnings.append("Missing Camera3D reference.")
	return warnings
