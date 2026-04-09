@tool
@icon("uid://bes0anop2dh5u")
class_name TileProfile
extends StructureProfile

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

enum CornerDirection {
	UP_RIGHT,
	DOWN_RIGHT,
	DOWN_LEFT,
	UP_LEFT,
}

@export var connections: Array[Direction] = [Direction.UP, Direction.RIGHT, Direction.DOWN, Direction.LEFT]
@export var corner_connections: Array[CornerDirection] = []

@export_group("Configuration")

static func direction_to_vector(direction: Direction) -> Vector2i:
	match direction:
		Direction.UP: return Vector2i.UP
		Direction.RIGHT: return Vector2i.RIGHT
		Direction.DOWN: return Vector2i.DOWN
		Direction.LEFT: return Vector2i.LEFT
		_: push_error("direction %s is not implemented!" % direction)
	assert(false)
	return Vector2i.ZERO

static func corner_direction_to_vector(corner_direction: CornerDirection) -> Vector2i:
	match corner_direction:
		CornerDirection.UP_RIGHT: return Vector2i(1 , 1)
		CornerDirection.DOWN_RIGHT: return Vector2i(1, -1)
		CornerDirection.DOWN_LEFT: return Vector2i(-1, -1)
		CornerDirection.UP_LEFT: return Vector2i(-1 , 1)
		_: push_error("corner_direction %s is not implemented!" % corner_direction)
	assert(false)
	return Vector2i.ZERO

static func is_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> bool:
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT: return true
	return false

static func get_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> Direction:
	assert(is_direction(first_grid_position, second_grid_position))
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i.UP: return Direction.UP
		Vector2i.RIGHT: return Direction.RIGHT
		Vector2i.DOWN: return Direction.DOWN
		Vector2i.LEFT: return Direction.LEFT
		_: push_error("delta_grid_position %s is not implemented!" % delta_grid_position)
	assert(false)
	return Direction.UP

static func is_corner_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> bool:
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i(1 , 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1 , 1): return true
	return false

static func get_corner_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> CornerDirection:
	assert(is_corner_direction(first_grid_position, second_grid_position))
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i(1 , 1): return CornerDirection.UP_RIGHT
		Vector2i(1, -1): return CornerDirection.DOWN_RIGHT
		Vector2i(-1, -1): return CornerDirection.DOWN_LEFT
		Vector2i(-1 , 1): return CornerDirection.UP_LEFT
		_: push_error("delta_grid_position %s is not implemented!" % delta_grid_position)
	assert(false)
	return CornerDirection.UP_RIGHT

func has_corner_connections() -> bool:
	return not corner_connections.is_empty()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
