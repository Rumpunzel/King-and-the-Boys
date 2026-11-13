@tool
@icon("uid://c73t2rg8wrdt3")
class_name PlayerStateMachine
extends StateMachine

@export_group("Configuration")
@export var player_controller: PlayerController
@export var character: Character
@export var default_phantom_camera: PhantomCamera3D

## The move actions pressed in the current state: a step goes on releasing one of them, so a key held down from another
## state (e.g. while aiming a held ability, where move keys act on press) does not step when let go
var move_presses: Dictionary[StringName, bool] = {}

var _state: PlayerState

func handle_input(event: InputEvent) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	get_state().handle_input(event)

func get_state() -> PlayerState:
	return _state

func set_state(state: State) -> void:
	assert(state is PlayerState)
	_state = state
	move_presses.clear()
	_state.set_state_machine(self)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not player_controller: warnings.append("Missing PlayerController reference.")
	if not default_phantom_camera: warnings.append("Missing default PhantomCamera3D reference.")
	return warnings + super._get_configuration_warnings()
