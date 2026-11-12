@tool
class_name RotateTileAbility
extends Ability
## Lifts the tile the character stands on, themselves with it, turns it and sets it down (the Mystic).
## Held: [method begin] lifts, [method adjust] turns the lifted tile, [method use] sets it down turned.
## The argument is the net clockwise quarter turns; each net quarter turn costs [member Ability.cost].

class RotateTileStep extends AbilityStep:
	var tile: Structure
	var clockwise_turns: int

	func _init(used_ability: Ability, used_by: Character, paid_cost: int, turned_tile: Structure, turns: int) -> void:
		super(used_ability, used_by, paid_cost)
		tile = turned_tile
		clockwise_turns = turns

	func undo(level: Level) -> void:
		level.rotate_tile(tile, -clockwise_turns, character)

func _init() -> void:
	targeting = Targeting.OWN_TILE
	held = true

## @returns [member Ability.cost] per net quarter turn: turning three times one way costs as much as once the other way
func get_cost(_character: Character, _target: Vector2i, argument: int) -> int:
	var net_turns: int = posmod(argument, Level.Direction.size())
	return mini(net_turns, Level.Direction.size() - net_turns) * cost

## Turns on round, skipping the angles [param character] can not pay for
func get_next_argument(character: Character, target: Vector2i, argument: int, step: int) -> int:
	var next_argument: int = argument
	for _turn: int in Level.Direction.size() - 1:
		next_argument = posmod(next_argument + step, Level.Direction.size())
		if get_cost(character, target, next_argument) <= character.movement_points: return next_argument
	return posmod(argument, Level.Direction.size())

## Turns the tile until the character on it faces [param direction]
func get_argument_towards(character: Character, _target: Vector2i, direction: Level.Direction) -> int:
	return posmod(direction - character.facing, Level.Direction.size())

## Lifting needs the points for at least a quarter turn. Room tiles turn too: only their exits move, as a room tile always
## connects to the tiles of its room beside it.
func can_begin(character: Character, target: Vector2i, level: Level) -> bool:
	if not super(character, target, level) or character.movement_points < cost: return false
	var tile: Structure = level.get_placed_tile(target)
	return tile != null and not tile.is_lifted()

func begin(character: Character, target: Vector2i, level: Level) -> void:
	level.get_placed_tile(target).lifted_by = character.get_path()

func adjust(_character: Character, target: Vector2i, argument: int, level: Level) -> void:
	level.get_placed_tile(target).lift_turns = posmod(argument, Level.Direction.size())

func cancel(_character: Character, target: Vector2i, level: Level) -> void:
	var tile: Structure = level.get_placed_tile(target)
	if tile: tile.lifted_by = NodePath()

## Setting the tile down unturned changes nothing: the [TurnManager] cancels it for free. A turn into the same shape (e.g. in
## the middle of a room, where every side connects) still turns the tile, and costs.
func can_use(character: Character, target: Vector2i, argument: int, level: Level) -> bool:
	var tile: Structure = level.get_placed_tile(target)
	if not tile or tile.lifted_by != character.get_path(): return false
	return posmod(argument, Level.Direction.size()) != 0

func use(character: Character, target: Vector2i, argument: int, level: Level) -> AbilityStep:
	var tile: Structure = level.get_placed_tile(target)
	var net_turns: int = posmod(argument, Level.Direction.size())
	tile.lifted_by = NodePath()
	level.rotate_tile(tile, net_turns, character)
	return RotateTileStep.new(self, character, get_cost(character, target, argument), tile, net_turns)

## The sides [param tile] would connect to, turned by [param clockwise_turns]: its exits turn, its room sides stay
static func _get_turned_connections(tile: Structure, clockwise_turns: int) -> Array[Level.Direction]:
	var connections_turned: Array[Level.Direction] = tile.get_room_sides()
	for opening: Level.Direction in tile.get_openings():
		var turned: Level.Direction = Level.turn_direction(opening, clockwise_turns)
		if not connections_turned.has(turned): connections_turned.append(turned)
	connections_turned.sort()
	return connections_turned
