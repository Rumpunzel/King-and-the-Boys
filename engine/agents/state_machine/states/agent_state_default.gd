@icon("uid://clji5px21jyvw")
class_name AgentStateDefault
extends AgentState
## The agent acts on its own: in the monster phase it hunts the nearest hero it sees (within its
## [method Character.get_vision], as heroes see) along passages, and wanders along passages otherwise, see [method choose_step]. It hands over
## once a player takes control of it.

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_hit_box().controlled.connect(_on_controlled)

func choose_step() -> int:
	var character: Character = get_character()
	var level: Level = character.level
	if not level or not level.get_placed_tile(character.grid_cell): return -1
	var hero_cells: Array[Vector2i] = []
	for node: Node in character.get_tree().get_nodes_in_group(Character.GROUP):
		var other: Character = node as Character
		if other and other.visible and other.level == level and other.profile.group == CharacterProfile.Groups.HEROES: hero_cells.append(other.grid_cell)
	# On a hero's tile already: it stays (blocks come later)
	if hero_cells.has(character.grid_cell): return -1
	var hunting: int = level.get_step_towards_in_sight(character.grid_cell, hero_cells, character.get_vision())
	if hunting >= 0: return hunting
	return _wander(character, level)

## A passage out at random, not straight back the way it came unless there is no other
func _wander(character: Character, level: Level) -> int:
	var back: Level.Direction = Level.get_opposite(character.facing)
	var ways: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values():
		if direction != back and level.is_passage(character.grid_cell, direction): ways.append(direction)
	if ways.is_empty(): return back if level.is_passage(character.grid_cell, back) else -1
	return ways.pick_random()

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
