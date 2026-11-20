@icon("uid://bfpmyljmhdkos")
class_name MonsterSenses
extends RefCounted
## Host only: who notices whom. A monster notices a hero only from the cells the hero sees ([method Character.get_vision]): if
## you can see it, it can see you. A lit hero ([method Character.is_lit]) is noticed there whatever way the monster faces; an
## unlit one only by a monster on its tile or looking straight at it within its [method Character.get_perception]. Dark vision
## does not count. [TurnManager] holds one (see [method TurnManager.get_senses]) and calls [method update] after every change that
## may change who notices whom.

var _turn_manager: TurnManager
var _level: Level
# The heroes noticed at the last update; keys may have been freed since (a player leaving takes their hero along)
var _noticed: Dictionary[Character, bool] = {}
# Who noticed whom at the last update, as [monster's instance id, hero's instance id] (ids: either may have been freed since)
var _attention: Dictionary[Array, bool] = {}
# After a load: the next update only learns who is noticed, as nothing the next action does got them noticed
var _settling: bool = false

func _init(turn_manager: TurnManager, level: Level) -> void:
	_turn_manager = turn_manager
	_level = level

## @returns whether [param monster] notices [param hero] now
func notices(monster: Character, hero: Character) -> bool:
	if not _is_on_board(monster) or not _is_on_board(hero): return false
	return _notices_in(monster, hero, _level.get_cells_in_sight(hero.grid_cell, hero.get_vision()))

## @returns whether [param monster] notices [param hero], who sees [param seen]
func _notices_in(monster: Character, hero: Character, seen: Dictionary[Vector2i, bool]) -> bool:
	if not seen.has(monster.grid_cell): return false
	if hero.is_lit() or monster.grid_cell == hero.grid_cell: return true
	return _looks_at(monster, hero.grid_cell)

## Who notices whom now sets each monster's [member Agent.awareness]: it hunts the nearest hero it notices; one that no longer
## notices the hero it hunted goes to look where it last noticed them, and roams again once there with no one noticed. Nothing
## that gets someone noticed can be taken back: the undo of each hero some monster notices anew closes, and so does
## [param actor]'s, whose action it follows; a monster turns to face the hero it hunts if that hero just caught its eye. Heroes are on alert ([member Character.alerted]) while any monster notices them. While a held ability is
## shown (e.g. a lifted tile), the board is not what it will be: nothing changes until it is used or cancelled.
func update(actor: Character = null) -> void:
	if _turn_manager.is_ability_held(): return
	var heroes: Array[Character] = _get_on_board(CharacterProfile.Groups.HEROES)
	# Each hero's sight once: monsters notice only from there
	var sights: Dictionary[Character, Dictionary] = {}
	for hero: Character in heroes: sights[hero] = _level.get_cells_in_sight(hero.grid_cell, hero.get_vision())
	var noticed_now: Dictionary[Character, bool] = {}
	var attention_now: Dictionary[Array, bool] = {}
	var anew: bool = false
	for monster: Character in _get_on_board(CharacterProfile.Groups.MONSTERS):
		var agent: Agent = monster.get_parent() as Agent
		if not agent: continue
		var noticed: Array[Character] = []
		# Those it did not notice at the last update
		var caught: Array[Character] = []
		for hero: Character in heroes:
			var seen: Dictionary[Vector2i, bool] = sights[hero]
			if not _notices_in(monster, hero, seen): continue
			noticed.append(hero)
			noticed_now[hero] = true
			var pair: Array = [monster.get_instance_id(), hero.get_instance_id()]
			attention_now[pair] = true
			# After a load, nobody knows what was noticed before it
			if _attention.has(pair) or _settling: continue
			caught.append(hero)
			anew = true
			_turn_manager.close_undo(hero)
		_update_awareness(agent, monster, noticed, caught)
	if anew and is_instance_valid(actor) and actor.is_inside_tree(): _turn_manager.close_undo(actor)
	# Untyped: a freed hero may not go into a typed variable
	for key: Variant in _noticed.keys():
		if not is_instance_valid(key): continue
		var hero: Character = key
		if not noticed_now.has(hero): hero.alerted = false
	for hero: Character in noticed_now: hero.alerted = true
	_noticed = noticed_now
	_attention = attention_now
	_settling = false

## Forgets who was noticed and takes every alert back, e.g. as a save is loaded; awareness stays as saved. The next
## [method update] only learns who is noticed then (and puts them on alert), closing no undo
func reset() -> void:
	_noticed.clear()
	_attention.clear()
	_settling = true
	for node: Node in _turn_manager.get_tree().get_nodes_in_group(Character.GROUP):
		var character: Character = node as Character
		if character: character.alerted = false

## [param caught]: those of [param noticed] it did not notice before
func _update_awareness(agent: Agent, monster: Character, noticed: Array[Character], caught: Array[Character]) -> void:
	if not noticed.is_empty():
		var nearest: Character = _get_nearest(monster, noticed)
		if caught.has(nearest): _face(monster, nearest)
		# The target first: whoever follows the awareness reads both
		agent.awareness_target = nearest.grid_cell
		agent.awareness = Agent.Awareness.HUNTING
	elif agent.awareness == Agent.Awareness.HUNTING:
		agent.awareness = Agent.Awareness.INVESTIGATING
	elif agent.awareness == Agent.Awareness.INVESTIGATING and monster.grid_cell == agent.awareness_target:
		agent.awareness = Agent.Awareness.ROAMING

## @returns the hero of [param heroes] fewest steps along passages from [param monster]; among those as near, the first by
## [member CharacterProfile.block_priority], then turn order (as [method Level.get_lead] orders them)
func _get_nearest(monster: Character, heroes: Array[Character]) -> Character:
	# Far enough for any noticed hero: they stand in the monster's sight or theirs, and passages may wind
	var reach: float = monster.get_perception()
	for hero: Character in heroes: reach = maxf(reach, hero.get_vision())
	var lengths: Dictionary[Vector2i, int] = _level.get_path_lengths(monster.grid_cell, ceili(reach) * 2)
	var nearest: Character = null
	var nearest_length: int = 0
	for hero: Character in Formation.by_priority(heroes):
		# Not reached along passages: last
		var length: int = lengths.get(hero.grid_cell, lengths.size() + 1)
		if nearest and length >= nearest_length: continue
		nearest = hero
		nearest_length = length
	return nearest

## Turns [param monster] towards [param hero], the way it would step to reach them along passages (none on its own tile)
func _face(monster: Character, hero: Character) -> void:
	var way: int = _level.get_step_towards(monster.grid_cell, hero.grid_cell)
	if way < 0: return
	monster.place_on_grid(monster.grid_cell, monster.tile_spot, way as Level.Direction)

## @returns the characters of [param group] on this level's board, in turn order
func _get_on_board(group: CharacterProfile.Groups) -> Array[Character]:
	var characters: Array[Character] = []
	for node: Node in _turn_manager.get_tree().get_nodes_in_group(Character.GROUP):
		var character: Character = node as Character
		if character and character.profile and character.profile.group == group and _is_on_board(character): characters.append(character)
	return characters

## @returns whether [param cell] lies straight ahead of [param monster], in sight within its perception
func _looks_at(monster: Character, cell: Vector2i) -> bool:
	var ahead: Vector2i = Level.direction_to_vector(monster.facing)
	var offset: Vector2i = cell - monster.grid_cell
	# A positive multiple of the way it faces
	if offset.x * ahead.y != offset.y * ahead.x or offset.x * ahead.x + offset.y * ahead.y <= 0: return false
	return _level.get_cells_in_sight(monster.grid_cell, monster.get_perception()).has(cell)

func _is_on_board(character: Character) -> bool:
	if not is_instance_valid(character) or character.is_queued_for_deletion(): return false
	return character.is_inside_tree() and character.visible and character.level == _level and _level.get_placed_tile(character.grid_cell) != null
