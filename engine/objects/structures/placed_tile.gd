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
	var adjusted_direction: TileProfile.Direction = posmod(direction + clockwise_turns * 2, 8)
	return tile_profile.connections.has(adjusted_direction)

func _to_string() -> String:
	return "[%s: turned %d times]" % [tile_profile.resource_name, clockwise_turns]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
