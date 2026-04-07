@icon("uid://cawf6uult17mx")
@abstract
class_name State
extends RefCounted

## Emitted when the state finishes and wants to transition to another state.
@warning_ignore("unused_signal")
signal finished(next_state: State)

const STATE_SCRIPT: StringName = "state_script"
const PREVIOUS_STATE_SCRIPT: StringName = "previous_state_script"

var _previous_state_script: GDScript

static func from_serialized_state(serialized_state: Dictionary[StringName, Variant]) -> State:
	var state_script_path: String = serialized_state[STATE_SCRIPT]
	var state_script: GDScript = load(state_script_path)
	var state: State = state_script.new()
	state.deserialize(serialized_state)
	return state

## Called by the state machine upon changing the active state.
## The [param data] parameter is a dictionary with arbitrary data the state can use to initialize itself.
func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	if previous_state: _previous_state_script = previous_state.get_script()
	set_state_machine(state_machine)
	finished.connect(get_state_machine().transition_to_next_state)

## Called by the state machine on the engine's main loop tick.
func update(_delta: float) -> void:
	pass

## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass

## Called by the state machine before changing the active state.
func exit() -> void:
	var state_machine: StateMachine = get_state_machine()
	if finished.is_connected(state_machine.transition_to_next_state):
		finished.disconnect(state_machine.transition_to_next_state)

func serialize() -> Dictionary[StringName, Variant]:
	var state_script: GDScript = get_script()
	var serialized_state: Dictionary[StringName, Variant] = {
		STATE_SCRIPT: state_script.resource_path,
	}
	if _previous_state_script: serialized_state[PREVIOUS_STATE_SCRIPT] = _previous_state_script.resource_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> State:
	var previous_state_script_path: String = serialized_state.get(PREVIOUS_STATE_SCRIPT, "")
	if not previous_state_script_path.is_empty():
		_previous_state_script = load(previous_state_script_path)
	return self

@abstract func get_state_machine() -> StateMachine
@abstract func set_state_machine(_state_machine: StateMachine) -> void

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	return warnings
