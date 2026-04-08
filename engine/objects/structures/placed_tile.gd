@tool
class_name PlacedTile
extends Resource

@export var tile_profile: TileProfile
@export var clockwise_turns: int = 0:
	set(new_rotation): clockwise_turns = posmod(new_rotation, 4)

@export_group("Configuration")

static func create(
	with_tile_profile: TileProfile,
	with_clockwise_turns: int = 0,
) -> PlacedTile:
	var new_placed_tile: PlacedTile = PlacedTile.new()
	new_placed_tile.tile_profile = with_tile_profile
	new_placed_tile.clockwise_turns = with_clockwise_turns
	return new_placed_tile

func has_connection(direction: TileProfile.Direction) -> bool:
	return tile_profile.connections.has(_get_adjusted_direction(direction))

func is_legal_neighbour(other_placed_tile: PlacedTile, direction: TileProfile.Direction, reverse_direction: TileProfile.Direction) -> bool:
	var direction_count: int = TileProfile.Direction.size()
	if direction == TileProfile.Direction.UP_RIGHT or direction == TileProfile.Direction.DOWN_RIGHT or direction == TileProfile.Direction.DOWN_LEFT or direction == TileProfile.Direction.UP_LEFT:
		if not has_connection(direction) == other_placed_tile.has_connection(reverse_direction): return false
	else:
		if not has_connection(direction) == other_placed_tile.has_connection(reverse_direction): return false
		if not has_connection(posmod(direction - 1, direction_count)) == other_placed_tile.has_connection(posmod(reverse_direction + 1, direction_count)): return false
		if not has_connection(posmod(direction + 1, direction_count)) == other_placed_tile.has_connection(posmod(reverse_direction - 1, direction_count)): return false
	return true

func _get_adjusted_direction(direction: TileProfile.Direction) -> TileProfile.Direction:
	var direction_count: int = TileProfile.Direction.size()
	return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)

func _to_string() -> String:
	return "[%s: turned %d times]" % [tile_profile.resource_path, clockwise_turns]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
