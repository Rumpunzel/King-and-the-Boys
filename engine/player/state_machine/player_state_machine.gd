@tool
@icon("uid://c73t2rg8wrdt3")
class_name PlayerStateMachine
extends StateMachine

signal available_interactions_changed(available_interactions: Array[Interaction])
signal controlled_character_changed(controlled_character: Character)

@export_group("Configuration")
@export var player_controller: PlayerController
@export var input_reader: InputReader
@export var character: Character
@export var hit_box: CharacterHitBox
@export var default_phantom_camera: PhantomCamera3D

@export var control_phantom_camera_scene: PackedScene

var available_interaction: Interaction:
	set(new_available_interaction):
		available_interaction = new_available_interaction
		var available_interactions: Array[Interaction] = []
		if available_interaction: available_interactions.append(available_interaction)
		available_interactions_changed.emit(available_interactions)

## The move actions pressed in the current state: a step goes on releasing one of them, so a key held down from another
## state (e.g. while aiming a held ability, where move keys act on press) does not step when let go
var move_presses: Dictionary[StringName, bool] = {}

var _state: PlayerState

func handle_input(event: InputEvent) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	get_state().handle_input(event)

## Offers [param current_interactable] (or nothing, for [code]null[/code]) to the current state, which turns it into the
## [member available_interaction] the input prompts show. Nothing calls it yet: it waits for a grid-based finder of the
## pieces within reach (see [method Level.get_cells_in_reach]), now that the interaction area is gone.
func handle_interactable(current_interactable: HitBox) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	available_interaction = get_state().handle_interactable(current_interactable)

func get_state() -> PlayerState:
	return _state

## @returns the [Character] the player currently moves
func get_controlled_character() -> Character:
	return _state.get_controlled_character() if _state else character

func set_state(state: State) -> void:
	assert(state is PlayerState)
	var previous_controlled_character: Character = get_controlled_character()
	_state = state
	move_presses.clear()
	_state.set_state_machine(self)
	if get_controlled_character() != previous_controlled_character:
		controlled_character_changed.emit(get_controlled_character())

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not player_controller: warnings.append("Missing PlayerController reference.")
	if not input_reader: warnings.append("Missing InputReader reference.")
	if not default_phantom_camera: warnings.append("Missing default PhantomCamera3D reference.")
	if not control_phantom_camera_scene: warnings.append("Missing control phantom camera scene.")
	return warnings + super._get_configuration_warnings()
