@tool
class_name PlacedTile
extends Resource

enum Status {
	PLACED,
	REVEALED,
}

@export var tile_profile: TileProfile
@export var clockwise_turns: int = 0:
	set(new_rotation): clockwise_turns = posmod(new_rotation, 4)

@export var status: Status = Status.PLACED:
	set(new_status):
		status = new_status
		if not structure: return
		assert(structure)
		var model: Model = structure.model
		assert(model)
		match status:
			Status.PLACED: model.apply_material_override(_hidden_material)
			Status.REVEALED: model.remove_material_override(_hidden_material)
			_: push_error("Status %s not implemented!" % status)

var structure: Structure:
	set(new_structure):
		assert(not structure or new_structure)
		structure = new_structure
		status = status

@export_group("Configuration")
@export var _hidden_material: Material = preload("res://protoype_assets/quaternius/medieval_village/Buildings/GLB/Windows.material")

static func create(
	with_tile_profile: TileProfile,
	with_clockwise_turns: int = 0,
	with_status: Status = Status.PLACED,
	with_structure: Structure = null,
) -> PlacedTile:
	var new_placed_tile: PlacedTile = PlacedTile.new()
	new_placed_tile.tile_profile = with_tile_profile
	new_placed_tile.clockwise_turns = with_clockwise_turns
	new_placed_tile.status = with_status
	if with_structure: new_placed_tile.structure = with_structure
	return new_placed_tile

func reveal() -> void:
	status = Status.REVEALED

func is_legal_neighbour(other_placed_tile: PlacedTile, first_grid_position: Vector2i, second_grid_position: Vector2i) -> bool:
	# Check horizontal/vertical neighbours
	if TileProfile.is_direction(first_grid_position, second_grid_position):
		var direction: TileProfile.Direction = TileProfile.get_direction(first_grid_position, second_grid_position)
		var reverse_direction: TileProfile.Direction = TileProfile.get_direction(second_grid_position, first_grid_position)
		# Must have opposite connections
		if not has_connection(direction) == other_placed_tile.has_connection(reverse_direction): return false
		# For tiles without corners, this is good enough
		if not tile_profile.has_corner_connections() and not other_placed_tile.tile_profile.has_corner_connections(): return true
		# Check if the two ajdacent corners are opposite to connect properly
		var corner_direction_count: int = TileProfile.CornerDirection.size()
		if not has_corner_connection(posmod(direction - 1, corner_direction_count)) == other_placed_tile.has_corner_connection(posmod(reverse_direction, corner_direction_count)): return false
		if not has_corner_connection(posmod(direction, corner_direction_count)) == other_placed_tile.has_corner_connection(posmod(reverse_direction - 1, corner_direction_count)): return false
		return true
	# Check diagonal neighbours
	elif TileProfile.is_corner_direction(first_grid_position, second_grid_position):
		# Tiles without corner connections can always be neighbours diagonally
		if not tile_profile.has_corner_connections() and not other_placed_tile.tile_profile.has_corner_connections(): return true
		var corner_direction: TileProfile.CornerDirection = TileProfile.get_corner_direction(first_grid_position, second_grid_position)
		var reverse_corner_direction: TileProfile.CornerDirection = TileProfile.get_corner_direction(second_grid_position, first_grid_position)
		# Must have opposite corners to connect diagonally
		return has_corner_connection(corner_direction) == other_placed_tile.has_corner_connection(reverse_corner_direction)
	else:
		assert(false, "Does not exist/not implemented!")
		return false

func has_connection(direction: TileProfile.Direction) -> bool:
	return get_connections().has(direction)

func get_connections() -> Array[TileProfile.Direction]:
	var adjusted_connections: Array[TileProfile.Direction] = []
	adjusted_connections.assign(tile_profile.connections.map(func(connection: TileProfile.Direction) -> TileProfile.Direction: return _get_adjusted_direction(connection)))
	return adjusted_connections

func get_connection_vectors() -> Array[Vector2i]:
	var connection_vectors: Array[Vector2i]
	connection_vectors.assign(get_connections().map(func(direction: TileProfile.Direction) -> Vector2i: return TileProfile.direction_to_vector(direction)))
	return connection_vectors

func has_corner_connection(corner_direction: TileProfile.CornerDirection) -> bool:
	return get_corner_connections().has(corner_direction)

func get_corner_connections() -> Array[TileProfile.CornerDirection]:
	var adjusted_connections: Array[TileProfile.CornerDirection] = []
	adjusted_connections.assign(tile_profile.corner_connections.map(func(connection: TileProfile.CornerDirection) -> TileProfile.CornerDirection: return _get_adjusted_corner_direction(connection)))
	return adjusted_connections

func get_corner_connection_vectors() -> Array[Vector2i]:
	var connection_vectors: Array[Vector2i]
	connection_vectors.assign(get_corner_connections().map(func(direction: TileProfile.CornerDirection) -> Vector2i: return TileProfile.corner_direction_to_vector(direction)))
	return connection_vectors

func _get_adjusted_direction(direction: TileProfile.Direction) -> TileProfile.Direction:
	var direction_count: int = TileProfile.Direction.size()
	return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)

func _get_adjusted_corner_direction(corner_direction: TileProfile.CornerDirection) -> TileProfile.CornerDirection:
	var corner_direction_count: int = TileProfile.CornerDirection.size()
	return posmod(corner_direction + clockwise_turns * (corner_direction_count / 4), corner_direction_count)

func _to_string() -> String:
	return "[%s turned %d times: %s (%s)]" % [tile_profile.resource_path, clockwise_turns, get_connections(), get_corner_connections()]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
