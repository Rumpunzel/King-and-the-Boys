@icon("uid://buu3pi6vipwi")
class_name InvestigateStrategy
extends MonsterStrategy
## The monsters' default: it hunts the hero it notices and goes to look where it last noticed one, along passages, and wanders
## along passages while it knows of none. On a tile with a standing hero it stays to fight.

func choose_step(agent: Agent) -> int:
	var character: Character = agent.character
	var level: Level = character.level
	if not level or not level.get_placed_tile(character.grid_cell): return -1
	if level.get_lead(character.grid_cell, CharacterProfile.Groups.HEROES): return -1
	if agent.awareness != Agent.Awareness.ROAMING:
		if character.grid_cell == agent.awareness_target: return -1
		var towards: int = level.get_step_towards(character.grid_cell, agent.awareness_target)
		if towards >= 0 and not _is_full_ahead(agent, towards): return towards
		# No way there (e.g. a turned tile closed it), or no room on it to look round: it gives up and roams
		agent.awareness = Agent.Awareness.ROAMING
	return _wander(character, level)

## @returns whether the step [param towards] would take investigating [param agent] onto the cell it investigates, which has
## no room for it (its side is full there)
func _is_full_ahead(agent: Agent, towards: int) -> bool:
	var character: Character = agent.character
	var level: Level = character.level
	if agent.awareness != Agent.Awareness.INVESTIGATING: return false
	if level.get_step_target(character.grid_cell, towards as Level.Direction) != agent.awareness_target: return false
	return not level.has_room(agent.awareness_target, character.profile.group, character)

## A passage out at random, not straight back the way it came unless there is no other
func _wander(character: Character, level: Level) -> int:
	var back: Level.Direction = Level.get_opposite(character.facing)
	var ways: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values():
		if direction != back and level.is_passage(character.grid_cell, direction): ways.append(direction)
	if ways.is_empty(): return back if level.is_passage(character.grid_cell, back) else -1
	return ways.pick_random()
