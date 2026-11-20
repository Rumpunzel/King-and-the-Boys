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
		if towards >= 0: return towards
		# No way there (e.g. a turned tile closed it): it gives up and roams
		agent.awareness = Agent.Awareness.ROAMING
	return _wander(character, level)

## A passage out at random, not straight back the way it came unless there is no other
func _wander(character: Character, level: Level) -> int:
	var back: Level.Direction = Level.get_opposite(character.facing)
	var ways: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values():
		if direction != back and level.is_passage(character.grid_cell, direction): ways.append(direction)
	if ways.is_empty(): return back if level.is_passage(character.grid_cell, back) else -1
	return ways.pick_random()
