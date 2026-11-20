@icon("uid://clji5px21jyvw")
class_name AgentStateDefault
extends AgentState
## The agent acts on its own: in the monster phase it steps as its profile's [member CharacterProfile.strategy] picks (see
## [method choose_step]). It hands over once a player takes control of it.

## For profiles without a strategy of their own
static var _default_strategy: MonsterStrategy = InvestigateStrategy.new()

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_hit_box().controlled.connect(_on_controlled)

func choose_step() -> int:
	var strategy: MonsterStrategy = get_character().profile.strategy
	return (strategy if strategy else _default_strategy).choose_step(get_agent())

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
