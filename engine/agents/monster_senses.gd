@icon("uid://bfpmyljmhdkos")
class_name MonsterSenses
extends RefCounted
## Host only: who notices whom. A monster notices a hero only from the cells the hero sees ([method Character.get_vision]): if
## you can see it, it can see you. A lit hero ([method Character.is_lit]) is noticed there whatever way the monster faces; an
## unlit one only by a monster on its tile or looking straight at it within its [method Character.get_perception]. Dark vision
## does not count. [TurnManager] holds one (see [method TurnManager.get_senses]).

var _turn_manager: TurnManager
var _level: Level

func _init(turn_manager: TurnManager, level: Level) -> void:
	_turn_manager = turn_manager
	_level = level

## @returns whether [param monster] notices [param hero] now
func notices(monster: Character, hero: Character) -> bool:
	if not _is_on_board(monster) or not _is_on_board(hero): return false
	var seen: Dictionary[Vector2i, bool] = _level.get_cells_in_sight(hero.grid_cell, hero.get_vision())
	if not seen.has(monster.grid_cell): return false
	if hero.is_lit() or monster.grid_cell == hero.grid_cell: return true
	return _looks_at(monster, hero.grid_cell)

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
