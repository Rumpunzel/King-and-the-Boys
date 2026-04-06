@tool
@icon("uid://dlf5ckv713eok")
class_name StateMachine
extends Node

enum Status {
	STOPPED,
	RUNNING,
}

@export_group("Configuration")
@export var _initial_state: GDScript

var _status: Status = Status.STOPPED

## This is used for serialization purposes; serves otherwise no purpose
@warning_ignore("unused_private_class_variable")
var _serialized_state: Dictionary[StringName, Variant]:
	get: return get_state().serialize()
	set(new_serialized_state):
		set_state(State.from_serialized_state(new_serialized_state))
		match _status:
			Status.STOPPED: pass
			Status.RUNNING: get_state().enter(self)
			_: push_error("Status %s not implemented!" % _status)

static func script_is_valid_state(script: Script) -> bool:
	if script.get_global_name() == "State": return true
	if script_is_valid_state(script.get_base_script()): return true
	return false

func start() -> void:
	assert(_status == Status.STOPPED)
	#if not is_node_ready(): await ready
	var initial_state: State = get_state()
	if not initial_state:
		initial_state = _initial_state.new()
		set_state(initial_state)
	initial_state.enter(self)
	_status = Status.RUNNING

## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	get_state().update(delta)

## Called by the state machine on the engine's physics update tick.
func physics_update(delta: float) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	get_state().physics_update(delta)

func stop() -> void:
	assert(_status == Status.RUNNING)
	var state: State = get_state()
	if state: state.exit()
	set_state(null)
	_status = Status.STOPPED

func transition_to_next_state(target_state: State) -> void:
	assert(_status == Status.RUNNING)
	var previous_state: State = get_state()
	if previous_state: previous_state.exit()
	set_state(target_state)
	get_state().enter(self, previous_state)

func get_state() -> State:
	assert(false, "StateMachine._get_state is 'virtual' and needs to be overriden!")
	return null

func set_state(_state: State) -> void:
	assert(false, "StateMachine._set_state is 'virtual' and needs to be overriden!")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _initial_state: warnings.append("Missing initial state.")
	if not script_is_valid_state(_initial_state): warnings.append("Initial state is not a State.")
	return warnings
