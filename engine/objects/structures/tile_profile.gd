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

@export var connections: Dictionary[Direction, RoomType] = {Direction.UP: null, Direction.RIGHT: null, Direction.DOWN: null, Direction.LEFT: null}
@export var room_type: RoomType

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

static func get_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> Direction:
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i.UP: return Direction.UP
		Vector2i.RIGHT: return Direction.RIGHT
		Vector2i.DOWN: return Direction.DOWN
		Vector2i.LEFT: return Direction.LEFT
		_: push_error("delta_grid_position %s is not implemented!" % delta_grid_position)
	assert(false)
	return Direction.UP

func has_restrictions() -> bool:
	return connections.values().any(func(restriction: RoomType) -> bool: return restriction != null)


func _to_string() -> String:
	return "%s: %s -> %s" % [resource_path.get_file(), room_type, connections]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
