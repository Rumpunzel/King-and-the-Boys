@icon("uid://cyxw8it04sxg5")
class_name AgentStateHaunted
extends AgentState

# Data dictionary keys
const HAUNTING: StringName = "haunting"

var _haunting_path: NodePath

var _haunting: Character

## Default parameters are required for deserialization to work
func _init(haunting_path: NodePath = NodePath(), ) -> void:
	_haunting_path = haunting_path

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	_haunting = state_machine.get_node(_haunting_path)
	assert(_haunting)
	get_hit_box().unhaunted.connect(_on_unhaunted)

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	get_hit_box().unhaunted.disconnect(_on_unhaunted)

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[HAUNTING] = _haunting_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> AgentStateHaunted:
	super.deserialize(serialized_state)
	_haunting_path = serialized_state[HAUNTING]
	return self

func _on_unhaunted() -> void:
	finished.emit(AgentStateDefault.new())
