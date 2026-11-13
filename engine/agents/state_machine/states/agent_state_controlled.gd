@icon("uid://cyxw8it04sxg5")
class_name AgentStateControlled
extends AgentState

# Data dictionary keys
const CONTROLLER: StringName = "controller"

var _controller_path: NodePath

var _controller: Character

## Default parameters are required for deserialization to work
func _init(controller_path: NodePath = NodePath(), ) -> void:
	_controller_path = controller_path

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	_controller = state_machine.get_node(_controller_path)
	assert(_controller)
	get_hit_box().released.connect(_on_released)

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	get_hit_box().released.disconnect(_on_released)

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[CONTROLLER] = _controller_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> AgentStateControlled:
	super.deserialize(serialized_state)
	_controller_path = serialized_state[CONTROLLER]
	return self

func _on_released() -> void:
	finished.emit(AgentStateDefault.new())
