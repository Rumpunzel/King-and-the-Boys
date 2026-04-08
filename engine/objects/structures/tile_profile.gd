@tool
@icon("uid://bes0anop2dh5u")
class_name TileProfile
extends StructureProfile

enum Direction {
	UP,
	UP_RIGHT,
	RIGHT,
	DOWN_RIGHT,
	DOWN,
	DOWN_LEFT,
	LEFT,
	UP_LEFT,
}

@export var connections: Array[Direction] = [Direction.UP, Direction.RIGHT, Direction.DOWN, Direction.LEFT]

@export_group("Configuration")

static func get_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> Direction:
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i.UP: return Direction.UP
		Vector2i.RIGHT: return Direction.RIGHT
		Vector2i.DOWN: return Direction.DOWN
		Vector2i.LEFT: return Direction.LEFT
		Vector2i(1 , 1): return Direction.UP_RIGHT
		Vector2i(1, -1): return Direction.DOWN_RIGHT
		Vector2i(-1, -1): return Direction.DOWN_LEFT
		Vector2i(-1 , 1): return Direction.UP_LEFT
		_: push_error("delta_grid_position %s is not implemented!" % delta_grid_position)
	assert(false)
	return Direction.UP

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
