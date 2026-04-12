@tool
class_name DungeonTileSet
extends Resource

@export var _dungeon_tiles: Dictionary[StructureProfile, float]
@export var _emergency_tiles: Dictionary[StructureProfile, float]

func get_tile_blueprint_for(tile_position: Vector2i, surrounding_tiles: Dictionary[Vector2i, Structure]) -> TileBlueprint:
	var fitting_blueprint: TileBlueprint = _find_tile_blueprint(_dungeon_tiles, tile_position, surrounding_tiles)
	if fitting_blueprint: return fitting_blueprint
	print_debug("No fitting tile found; looking for emergency tile.")
	fitting_blueprint = _find_tile_blueprint(_emergency_tiles, tile_position, surrounding_tiles)
	assert(fitting_blueprint)
	return fitting_blueprint

func _find_tile_blueprint(set_to_search: Dictionary[StructureProfile, float], tile_position: Vector2i, surrounding_tiles: Dictionary[Vector2i, Structure]) -> TileBlueprint:
	var tile_blueprints: Dictionary[TileBlueprint, float] = {}
	for surrounding_tile_grid_position: Vector2i in surrounding_tiles.keys():
		var surrounding_tile: Structure = surrounding_tiles[surrounding_tile_grid_position]
		for profile: StructureProfile in set_to_search.keys():
			for clockwise_rotation: int in range(4):
				var blueprint: TileBlueprint = TileBlueprint.new(profile, clockwise_rotation)
				if blueprint.is_legal_neighbour(surrounding_tile, tile_position): tile_blueprints[blueprint] = set_to_search[profile]
	if tile_blueprints.is_empty(): return null
	var total_weight: float = tile_blueprints.values().reduce(func(sum: float, tile_weight: float) -> float: return sum + tile_weight)
	var random_selection: float = randf() * total_weight
	for blueprint: TileBlueprint in tile_blueprints.keys():
		var weight: float = tile_blueprints[blueprint]
		if random_selection < weight: return blueprint
		random_selection -= weight
	assert(false)
	return null

class TileBlueprint extends RefCounted:
	var profile: StructureProfile
	var clockwise_turns: int
	
	func _init(for_profile: StructureProfile, with_clockwise_turns: int = 0) -> void:
		profile = for_profile
		clockwise_turns = with_clockwise_turns
	
	func is_legal_neighbour(existing_tile: Structure, grid_position: Vector2i) -> bool:
		# Check horizontal/vertical neighbours
		var direction: Level.Direction = Level.get_direction(grid_position, existing_tile.get_grid_position())
		var reverse_direction: Level.Direction = Level.get_direction(existing_tile.get_grid_position(), grid_position)
		if not has_connection(direction) and not existing_tile.has_connection(reverse_direction): return true
		# Must have opposite connections
		if has_connection(direction) != existing_tile.has_connection(reverse_direction): return false
		return can_connect(direction, existing_tile.profile) and existing_tile.can_connect(reverse_direction, profile)
	
	func has_connection(direction: Level.Direction) -> bool:
		return get_connections().has(direction)
	
	func get_connection(direction: Level.Direction) -> ConnectionRestriction:
		assert(has_connection(direction))
		return get_connections()[direction]

	func can_connect(direction: Level.Direction, other_profile: StructureProfile) -> bool:
		if not has_connection(direction): return false
		var connections: Dictionary[Level.Direction, ConnectionRestriction] = get_connections()
		var restriction: ConnectionRestriction = connections[direction]
		return not restriction or restriction.can_connect(profile, other_profile)

	func get_connections() -> Dictionary[Level.Direction, ConnectionRestriction]:
		var adjusted_connections: Dictionary[Level.Direction, ConnectionRestriction] = {}
		for connection: Level.Direction in profile.connections.keys():
			adjusted_connections[_get_adjusted_direction(connection)] = profile.connections[connection]
		return adjusted_connections

	func get_connection_vectors() -> Array[Vector2i]:
		var connection_vectors: Array[Vector2i]
		connection_vectors.assign(get_connections().keys().map(func(direction: Level.Direction) -> Vector2i: return Level.direction_to_vector(direction)))
		return connection_vectors
	
	func _get_adjusted_direction(direction: Level.Direction) -> Level.Direction:
		var direction_count: int = Level.Direction.size()
		return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)
