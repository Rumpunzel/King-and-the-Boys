@tool
class_name DungeonTileSet
extends Resource

@export var tile_connection: StructureProfile
@export var tile_connector: StructureProfile

@export var _dungeon_tiles: Dictionary[StructureProfile, float]

# {Bit flag of directions: Array[TileBlueprint]}
var _blueprints_bitflag: Dictionary[int, Array]:
	get:
		if _blueprints_bitflag.is_empty(): _generate_blueprints_bitflag()
		assert(not _blueprints_bitflag.is_empty())
		return _blueprints_bitflag

func get_tile_blueprint_for(tile_position: Vector2i, surrounding_tiles: Array[Structure]) -> TileBlueprint:
	# Build bitflags based on surrounding tiles' connections
	var surrounding_connection_bitflag: int = 0
	var surrounding_wall_bitflag: int = 0
	for surrounding_tile: Structure in surrounding_tiles:
		var surrounding_tile_grid_position: Vector2i = surrounding_tile.get_grid_position()
		var direction: Level.Direction = Level.get_direction(tile_position, surrounding_tile_grid_position)
		var reverse_direction: Level.Direction = Level.get_direction(surrounding_tile_grid_position, tile_position)
		if surrounding_tile.has_connection(reverse_direction):
			assert(surrounding_tile.has_connection_to(tile_position))
			surrounding_connection_bitflag |= 2 ** direction
		else:
			assert(not surrounding_tile.has_connection_to(tile_position))
			surrounding_wall_bitflag |= 2 ** direction
	var connections_in_bitflag: int = _count_true_bits(surrounding_connection_bitflag)
	var walls_in_bitflag: int = _count_true_bits(surrounding_wall_bitflag)
	assert(connections_in_bitflag + walls_in_bitflag == surrounding_tiles.size())
	# Filter blueprints with bitflags
	var fitting_blueprints: Array[TileBlueprint] = []
	for connection_bitflag: int in _blueprints_bitflag.keys():
		# Check if [connection_bitflag] has at least all the connections in [surrounding_connection_bitflag]
		var shares_surrounding_connections: bool = connection_bitflag & surrounding_connection_bitflag == surrounding_connection_bitflag
		# Check if [connection_bitflag] has no connections where there are walls in [surrounding_wall_bitflag]
		var has_wall_conflicts: bool = connection_bitflag & surrounding_wall_bitflag > 0
		if shares_surrounding_connections and not has_wall_conflicts:
			var blueprints_with_fitting_connections: Array[TileBlueprint] = _blueprints_bitflag[connection_bitflag]
			for surrounding_tile: Structure in surrounding_tiles:
				for blueprint: TileBlueprint in blueprints_with_fitting_connections:
					var surrounding_tile_has_connection: bool = surrounding_tile.has_connection_to(tile_position)
					var blueprint_has_connection: bool = blueprint.has_connection(tile_position, surrounding_tile)
					assert(surrounding_tile_has_connection == blueprint_has_connection)
			fitting_blueprints.append_array(blueprints_with_fitting_connections)
	assert(not fitting_blueprints.is_empty())
	# Filter by restrictions
	var legal_neighbours: Array[TileBlueprint] = []
	for surrounding_tile: Structure in surrounding_tiles:
		for blueprint: TileBlueprint in fitting_blueprints:
			var surrounding_tile_has_connection: bool = surrounding_tile.has_connection_to(tile_position)
			var blueprint_has_connection: bool = blueprint.has_connection(tile_position, surrounding_tile)
			assert(surrounding_tile_has_connection == blueprint_has_connection)
			if blueprint.is_legal_neighbour(tile_position, surrounding_tile): legal_neighbours.append(blueprint)
	if legal_neighbours.is_empty():
		legal_neighbours = fitting_blueprints
		print_debug("No fitting neighbour found; continueing without restrictions.")
	# Make weighted random selection
	var total_weight: float = legal_neighbours.reduce(func(sum: float, blueprint: TileBlueprint) -> float: return sum + _dungeon_tiles[blueprint.profile], 0.0)
	var random_selection: float = randf() * total_weight
	for blueprint: TileBlueprint in legal_neighbours:
		for surrounding_tile: Structure in surrounding_tiles: assert(blueprint.has_connection(tile_position, surrounding_tile) == surrounding_tile.has_connection_to(tile_position))
		var weight: float = _dungeon_tiles[blueprint.profile]
		if random_selection < weight: return blueprint
		random_selection -= weight
	assert(false)
	return null

func _generate_blueprints_bitflag() -> void:
	var blueprints_bitflag: Dictionary[int, Array] = {}
	for profile: StructureProfile in _dungeon_tiles.keys():
		for clockwise_rotation: int in range(Level.Direction.size()):
			var blueprint: TileBlueprint = TileBlueprint.new(profile, clockwise_rotation)
			var connection_bitflag: int = blueprint.get_connection_bitflag()
			var similar_blueprints: Array[TileBlueprint] = blueprints_bitflag.get_or_add(connection_bitflag, [] as Array[TileBlueprint])
			similar_blueprints.append(blueprint)
	_blueprints_bitflag = blueprints_bitflag

func _count_true_bits(bitflag: int) -> int:
	var count: int = 0
	while count < bitflag:
		bitflag &= bitflag - 1 # Clear the least significant bit set
		count += 1
	return count

class TileBlueprint extends RefCounted:
	var profile: StructureProfile
	var clockwise_turns: int
	
	func _init(for_profile: StructureProfile, with_clockwise_turns: int = 0) -> void:
		profile = for_profile
		clockwise_turns = with_clockwise_turns
	
	func is_legal_neighbour(grid_position: Vector2i, existing_tile: Structure) -> bool:
		assert(has_connection(grid_position, existing_tile) == existing_tile.has_connection_to(grid_position))
		return can_connect(grid_position, existing_tile) and existing_tile.can_connect_to(grid_position, profile)
	
	func can_connect(grid_position: Vector2i, existing_tile: Structure) -> bool:
		var direction: Level.Direction = _get_direction_to_tile(grid_position, existing_tile)
		return profile.can_connect(direction, clockwise_turns, existing_tile.profile)
	
	func has_connection(grid_position: Vector2i, existing_tile: Structure) -> bool:
		var direction: Level.Direction = _get_direction_to_tile(grid_position, existing_tile)
		return profile.has_connection(direction, clockwise_turns)
	
	func get_connections() -> Array[Level.Direction]: return profile.get_connections(clockwise_turns)
	func get_connection_vectors() -> Array[Vector2i]: return profile.get_connection_vectors(clockwise_turns)
	func get_connection_bitflag() -> int:
		var connection_bitflag: int = 0
		for connection: Level.Direction in get_connections(): connection_bitflag |= 2 ** connection
		return connection_bitflag
	
	func get_restriction(grid_position: Vector2i, existing_tile: Structure) -> ConnectionRestriction:
		var direction: Level.Direction = _get_direction_to_tile(grid_position, existing_tile)
		return profile.get_restriction(direction, clockwise_turns)
	
	func get_restrictions() -> Dictionary[Level.Direction, ConnectionRestriction]: return profile.get_restrictions(clockwise_turns)
	
	func _get_direction_to_tile(grid_position: Vector2i, tile: Structure) -> Level.Direction: return Level.get_direction(grid_position, tile.get_grid_position())
	
	func _to_string() -> String: return "%s rotated %d times" % [profile.name, clockwise_turns]
