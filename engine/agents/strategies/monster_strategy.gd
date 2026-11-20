@icon("uid://buu3pi6vipwi")
class_name MonsterStrategy
extends Resource
## How a monster picks its steps in the monster phase, from what it knows of the heroes ([member Agent.awareness], kept by
## [MonsterSenses]). A [CharacterProfile] names one in [member CharacterProfile.strategy]; [InvestigateStrategy] without. The base
## stands still.

## Host only: the direction of [param agent]'s next step, [code]-1[/code] to stop for this turn
func choose_step(_agent: Agent) -> int:
	return -1
