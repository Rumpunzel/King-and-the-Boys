@icon("uid://clji5px21jyvw")
class_name AgentStateDefault
extends AgentState
## The agent stands by until a player takes control of it; agents act on the grid through the [TurnManager] once they
## have turns of their own

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_hit_box().controlled.connect(_on_controlled)

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	get_hit_box().controlled.disconnect(_on_controlled)

func _on_controlled(controller: Character) -> void:
	finished.emit(AgentStateControlled.new(controller.get_path()))
