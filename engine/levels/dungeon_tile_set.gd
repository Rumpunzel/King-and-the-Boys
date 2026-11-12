@tool
@icon("uid://rlx5flqs6hx5")
class_name DungeonTileSet
extends Resource

@export var _dungeon_tiles: Dictionary[StructureProfile, float]

# {Bit flag of directions: Array[TileBlueprint]}
var _blueprints_bitflag: Dictionary[int, Array]:
	get:
		if _blueprints_bitflag.is_empty(): _generate_blueprints_bitflag()
		assert(not _blueprints_bitflag.is_empty())
		return _blueprints_bitflag

## A blueprint fitting the passages of [param surrounding_tiles], drawn by weight with [param random] among those
## keeping the most of their connection restrictions (all of them, wherever one can)
func pick_tile(tile_position: Vector2i, surrounding_tiles: Array[Structure], random: RandomNumberGenerator) -> Pick:
	# Asked once rather than for every blueprint
	var opening_towards: Dictionary[Structure, bool] = get_openings_towards(tile_position, surrounding_tiles)
	var fitting_blueprints: Array[TileBlueprint] = []
	for blueprints: Array in _blueprints_bitflag.values():
		for blueprint: TileBlueprint in blueprints:
			if blueprint.fits(tile_position, opening_towards): fitting_blueprints.append(blueprint)
	assert(not fitting_blueprints.is_empty())
	# Restrictions: the blueprints suiting the most surrounding tiles, each once. All of them if any blueprint does;
	# else the least broken, rather than any at all
	var most_suited: int = -1
	var candidates: Array[TileBlueprint] = []
	for blueprint: TileBlueprint in fitting_blueprints:
		var suited: int = surrounding_tiles.filter(func(surrounding_tile: Structure) -> bool: return blueprint.is_legal_neighbour(tile_position, surrounding_tile)).size()
		if suited > most_suited:
			most_suited = suited
			candidates.clear()
		if suited == most_suited: candidates.append(blueprint)
	var suits_all: bool = most_suited == surrounding_tiles.size()
	if not suits_all: print_debug("No tile keeps every neighbour's restrictions at %s; taking one that keeps %d of %d" % [tile_position, most_suited, surrounding_tiles.size()])
	return Pick.new(_draw(candidates, random), suits_all)

## @returns whether each of [param surrounding_tiles] opens towards [param tile_position], see [method TileBlueprint.fits]
static func get_openings_towards(tile_position: Vector2i, surrounding_tiles: Array[Structure]) -> Dictionary[Structure, bool]:
	var opening_towards: Dictionary[Structure, bool] = {}
	for surrounding_tile: Structure in surrounding_tiles:
		opening_towards[surrounding_tile] = surrounding_tile.get_connections().has(Level.get_direction(surrounding_tile.get_grid_position(), tile_position))
	return opening_towards

## One of [param candidates] by their weights
func _draw(candidates: Array[TileBlueprint], random: RandomNumberGenerator) -> TileBlueprint:
	assert(not candidates.is_empty())
	var total_weight: float = candidates.reduce(func(sum: float, blueprint: TileBlueprint) -> float: return sum + _dungeon_tiles[blueprint.profile], 0.0)
	var random_selection: float = random.randf() * total_weight
	for blueprint: TileBlueprint in candidates:
		var weight: float = _dungeon_tiles[blueprint.profile]
		if random_selection < weight: return blueprint
		random_selection -= weight
	# randf() may return 1.0, and weights of 0 never win: the last one then
	return candidates.back()

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

## What [method pick_tile] picked, and whether it keeps every neighbour's connection restrictions
class Pick extends RefCounted:
	var blueprint: TileBlueprint
	var suits_all: bool

	func _init(picked: TileBlueprint, picked_suits_all: bool) -> void:
		blueprint = picked
		suits_all = picked_suits_all

class TileBlueprint extends RefCounted:
	var profile: StructureProfile
	var clockwise_turns: int

	func _init(for_profile: StructureProfile, with_clockwise_turns: int = 0) -> void:
		profile = for_profile
		clockwise_turns = with_clockwise_turns

	## Whether the blueprint opens exactly where the neighbours open towards [param grid_position] (each in [param opening_towards], by its shape
	## even while lifted). Towards a tile of its own room type a room tile fits either way: room tiles always connect.
	func fits(grid_position: Vector2i, opening_towards: Dictionary[Structure, bool]) -> bool:
		for surrounding_tile: Structure in opening_towards:
			if profile.room_type and surrounding_tile.profile.room_type == profile.room_type: continue
			if has_connection(grid_position, surrounding_tile) != opening_towards[surrounding_tile]: return false
		return true

	func is_legal_neighbour(grid_position: Vector2i, existing_tile: Structure) -> bool:
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
