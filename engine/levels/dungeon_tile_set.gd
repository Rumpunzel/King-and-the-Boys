@tool
@icon("uid://rlx5flqs6hx5")
class_name DungeonTileSet
extends Resource

@export var _dungeon_tiles: Dictionary[StructureProfile, float]

# Every tile in each of its four turns, made the first time they are needed
var _blueprints: Array[TileBlueprint]:
	get:
		if _blueprints.is_empty(): _generate_blueprints()
		assert(not _blueprints.is_empty())
		return _blueprints

## A blueprint fitting the passages of [param surrounding_tiles], drawn by weight with [param random] among those
## keeping the most of their connection restrictions (all of them, wherever one can)
func pick_tile(tile_position: Vector2i, surrounding_tiles: Array[Structure], random: RandomNumberGenerator) -> Pick:
	# Asked of each surrounding tile once rather than for every blueprint: this runs for every tile the dungeon grows by
	var neighbours: Array[Neighbour] = get_neighbours(tile_position, surrounding_tiles)
	# Restrictions: the fitting blueprints suiting the most surrounding tiles, each once. All of them if any blueprint does;
	# else the least broken, rather than any at all
	var most_suited: int = -1
	var candidates: Array[TileBlueprint] = []
	for blueprint: TileBlueprint in _blueprints:
		if not blueprint.fits(neighbours): continue
		var suited: int = 0
		for neighbour: Neighbour in neighbours:
			if blueprint.is_legal_neighbour(neighbour): suited += 1
		if suited > most_suited:
			most_suited = suited
			candidates.clear()
		if suited == most_suited: candidates.append(blueprint)
	assert(not candidates.is_empty())
	var suits_all: bool = most_suited == neighbours.size()
	if not suits_all: print_verbose("No tile keeps every neighbour's restrictions at %s; taking one that keeps %d of %d" % [tile_position, most_suited, neighbours.size()])
	return Pick.new(_draw(candidates, random), suits_all)

## @returns what [method pick_tile] needs of each of [param surrounding_tiles] around [param tile_position]
static func get_neighbours(tile_position: Vector2i, surrounding_tiles: Array[Structure]) -> Array[Neighbour]:
	var neighbours: Array[Neighbour] = []
	for surrounding_tile: Structure in surrounding_tiles: neighbours.append(Neighbour.new(tile_position, surrounding_tile))
	return neighbours

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

func _generate_blueprints() -> void:
	var blueprints: Array[TileBlueprint] = []
	for profile: StructureProfile in _dungeon_tiles.keys():
		for clockwise_rotation: int in range(Level.Direction.size()): blueprints.append(TileBlueprint.new(profile, clockwise_rotation))
	_blueprints = blueprints

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

	## Whether the blueprint opens exactly where [param neighbours] open towards it. Towards a tile of its own room type a room
	## tile fits either way: room tiles always connect.
	func fits(neighbours: Array[Neighbour]) -> bool:
		for neighbour: Neighbour in neighbours:
			if profile.room_type and neighbour.profile.room_type == profile.room_type: continue
			if profile.has_connection(neighbour.direction, clockwise_turns) != neighbour.opens_towards: return false
		return true

	## Whether the blueprint and [param neighbour] keep each other's connection restrictions
	func is_legal_neighbour(neighbour: Neighbour) -> bool:
		if not profile.can_connect(neighbour.direction, clockwise_turns, neighbour.profile): return false
		return not neighbour.restriction or neighbour.restriction.can_connect(neighbour.profile, profile)

	func get_connections() -> Array[Level.Direction]: return profile.get_connections(clockwise_turns)
	func get_connection_vectors() -> Array[Vector2i]: return profile.get_connection_vectors(clockwise_turns)

	func get_restrictions() -> Dictionary[Level.Direction, ConnectionRestriction]: return profile.get_restrictions(clockwise_turns)

	func _to_string() -> String: return "%s rotated %d times" % [profile.name, clockwise_turns]

## A tile placed beside the one being picked, as [method DungeonTileSet.pick_tile] needs it
class Neighbour extends RefCounted:
	var profile: StructureProfile
	## From the tile being picked towards it
	var direction: Level.Direction
	## Whether it opens towards the tile being picked (by its shape, even while lifted; room tiles towards their room too)
	var opens_towards: bool
	## Its restriction on what lies towards the tile being picked
	var restriction: ConnectionRestriction

	func _init(tile_position: Vector2i, tile: Structure) -> void:
		profile = tile.profile
		direction = Level.get_direction(tile_position, tile.get_grid_position())
		var back: Level.Direction = Level.get_opposite(direction)
		opens_towards = tile.get_connections().has(back)
		restriction = profile.get_restriction(back, tile.clockwise_turns)
