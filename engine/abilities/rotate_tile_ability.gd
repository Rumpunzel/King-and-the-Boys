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

## Room tiles never turn, a room spans many cells; lifting needs the points for at least a quarter turn
func can_begin(character: Character, target: Vector2i, level: Level) -> bool:
	if not super(character, target, level) or character.movement_points < cost: return false
	var tile: Structure = level.get_placed_tile(target)
	return tile != null and not tile.is_lifted() and not tile.profile.room_type

func begin(character: Character, target: Vector2i, level: Level) -> void:
	level.get_placed_tile(target).lifted_by = character.get_path()

func adjust(_character: Character, target: Vector2i, argument: int, level: Level) -> void:
	level.get_placed_tile(target).lift_turns = posmod(argument, Level.Direction.size())

func cancel(_character: Character, target: Vector2i, level: Level) -> void:
	var tile: Structure = level.get_placed_tile(target)
	if tile: tile.lifted_by = NodePath()

## Setting the tile down unturned, or turned into the same shape, changes nothing: the [TurnManager] cancels it for free
func can_use(character: Character, target: Vector2i, argument: int, level: Level) -> bool:
	var tile: Structure = level.get_placed_tile(target)
	if not tile or tile.lifted_by != character.get_path(): return false
	var net_turns: int = posmod(argument, Level.Direction.size())
	return net_turns != 0 and _get_turned_connections(tile, net_turns) != _get_turned_connections(tile, 0)

func use(character: Character, target: Vector2i, argument: int, level: Level) -> AbilityStep:
	var tile: Structure = level.get_placed_tile(target)
	var net_turns: int = posmod(argument, Level.Direction.size())
	tile.lifted_by = NodePath()
	level.rotate_tile(tile, net_turns, character)
	return RotateTileStep.new(self, character, get_cost(character, target, argument), tile, net_turns)

static func _get_turned_connections(tile: Structure, clockwise_turns: int) -> Array[Level.Direction]:
	var connections: Array[Level.Direction] = []
	for connection: Level.Direction in tile.get_connections(): connections.append(Level.turn_direction(connection, clockwise_turns))
	connections.sort()
	return connections
