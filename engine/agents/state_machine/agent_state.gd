@icon("uid://ne8n58y4wim8")
class_name AgentState
extends State

var _state_machine: AgentStateMachine

func get_state_machine() -> AgentStateMachine: return _state_machine

func get_agent() ->  Agent: return get_state_machine().agent
func get_character() ->  Character: return get_state_machine().character
func get_hit_box() ->  CharacterHitBox: return get_state_machine().hit_box

func set_state_machine(state_machine: StateMachine) -> void:
	assert(state_machine is AgentStateMachine)
	_state_machine = state_machine
