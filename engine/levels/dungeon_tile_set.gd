@tool
class_name DungeonTileSet
extends Resource

@export var _dungeon_tiles: Dictionary[StructureProfile, float]
@export var _emergency_tiles: Dictionary[StructureProfile, float]

var _blueprints: Dictionary[TileBlueprint, float]:
	get:
		if _blueprints.is_empty(): _blueprints = _generate_blueprints(_dungeon_tiles)
		assert(not _blueprints.is_empty())
		return _blueprints
var _emergency_blueprints: Dictionary[TileBlueprint, float]:
	get:
		if _emergency_blueprints.is_empty(): _emergency_blueprints = _generate_blueprints(_emergency_tiles)
		assert(not _emergency_blueprints.is_empty())
		return _emergency_blueprints

func get_tile_blueprint_for(tile_position: Vector2i, surrounding_tiles: Array[Structure]) -> TileBlueprint:
	var fitting_blueprint: TileBlueprint = _find_tile_blueprint(_blueprints, tile_position, surrounding_tiles)
	if fitting_blueprint: return fitting_blueprint
	print_debug("No fitting tile found; looking for emergency tile.")
	fitting_blueprint = _find_tile_blueprint(_emergency_blueprints, tile_position, surrounding_tiles)
	if fitting_blueprint: return fitting_blueprint
	print_debug("No fitting emergency tile found; trying again without restrictions.")
	fitting_blueprint = _find_tile_blueprint(_blueprints, tile_position, surrounding_tiles, true)
	if fitting_blueprint: return fitting_blueprint
	fitting_blueprint = _find_tile_blueprint(_emergency_blueprints, tile_position, surrounding_tiles, true)
	assert(fitting_blueprint)
	return fitting_blueprint

func _find_tile_blueprint(blueprints_to_search: Dictionary[TileBlueprint, float], tile_position: Vector2i, surrounding_tiles: Array[Structure], ignore_restrictions: bool = false) -> TileBlueprint:
	var fitting_blueprints: Dictionary[TileBlueprint, float] = blueprints_to_search.duplicate()
	for surrounding_tile: Structure in surrounding_tiles:
		for blueprint: TileBlueprint in blueprints_to_search.keys():
			if not fitting_blueprints.has(blueprint): continue
			if not blueprint.is_legal_neighbour_at(tile_position, surrounding_tile, ignore_restrictions): fitting_blueprints.erase(blueprint)
	if fitting_blueprints.is_empty(): return null
	var total_weight: float = fitting_blueprints.values().reduce(func(sum: float, tile_weight: float) -> float: return sum + tile_weight)
	var random_selection: float = randf() * total_weight
	for blueprint: TileBlueprint in fitting_blueprints.keys():
		var weight: float = fitting_blueprints[blueprint]
		if random_selection < weight: return blueprint
		random_selection -= weight
	assert(false)
	return null

func _generate_blueprints(for_tile_profiles: Dictionary[StructureProfile, float]) -> Dictionary[TileBlueprint, float]:
	var blueprints: Dictionary[TileBlueprint, float] = {}
	for profile: StructureProfile in for_tile_profiles.keys():
		for clockwise_rotation: int in range(4):
			var blueprint: TileBlueprint = TileBlueprint.new(profile, clockwise_rotation)
			blueprints[blueprint] = for_tile_profiles[profile]
	return blueprints

class TileBlueprint extends RefCounted:
	var profile: StructureProfile
	var clockwise_turns: int
	
	func _init(for_profile: StructureProfile, with_clockwise_turns: int = 0) -> void:
		profile = for_profile
		clockwise_turns = with_clockwise_turns
	
	func is_legal_neighbour_at(grid_position: Vector2i, existing_tile: Structure, ignore_restrictions: bool) -> bool:
		var direction: Level.Direction = Level.get_direction(grid_position, existing_tile.get_grid_position())
		var reverse_direction: Level.Direction = Level.get_direction(existing_tile.get_grid_position(), grid_position)
		if has_connection(direction) != existing_tile.has_connection(reverse_direction): return false
		if ignore_restrictions: return true
		return can_connect(direction, existing_tile.profile) and existing_tile.can_connect(reverse_direction, profile)
	
	func can_connect(direction: Level.Direction, other_profile: StructureProfile) -> bool: return profile.can_connect(direction, clockwise_turns, other_profile)

	func has_connection(direction: Level.Direction) -> bool: return profile.has_connection(direction, clockwise_turns)
	func get_connections() -> Array[Level.Direction]: return profile.get_connections(clockwise_turns)
	func get_connection_vectors() -> Array[Vector2i]: return profile.get_connection_vectors(clockwise_turns)

	func get_restriction(direction: Level.Direction) -> ConnectionRestriction: return profile.get_restriction(direction, clockwise_turns)
	func get_restrictions() -> Dictionary[Level.Direction, ConnectionRestriction]: return profile.get_restrictions(clockwise_turns)
	
	func _to_string() -> String: return "%s rotated %d times" % [profile.name, clockwise_turns]
