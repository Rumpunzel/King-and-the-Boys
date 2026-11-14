@tool
@icon("uid://bes0anop2dh5u")
class_name StructureProfile
extends Profile

enum Groups {
	BUILDING,
	FLORA,
	TILE,
}

@export var group: Groups = Groups.BUILDING
@export var room_type: RoomType
## Props the tile is dressed with once revealed, see [TileDecorations]
@export var decorations: TileDecorations
@export var grid_cell_extents: Vector3i = Vector3i.ONE
@export_group("Tile Spots", "tile_spot")
## Where pieces stand on the tile, in order of preference; things hold the first spot
@export var tile_spot_directions: Array[Vector2] = [Vector2.ZERO, Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]
## Distance of the spots from the tile center, per axis
@export var tile_spot_extents: Vector2 = Vector2(0.5, 0.5)
@export_group("")

@export var discover_animation: ModelAnimation = preload("uid://bf0msgn2okdfo")
@export var reveal_animation: ModelAnimation = preload("uid://80ut5hvuftsw")

@export_group("Connections", "_connection")
@export var _connection_up: bool
@export var _connection_right: bool
@export var _connection_down: bool
@export var _connection_left: bool
@export_group("Restrictions", "_restriction")
@export var _restriction_up: ConnectionRestriction
@export var _restriction_right: ConnectionRestriction
@export var _restriction_down: ConnectionRestriction
@export var _restriction_left: ConnectionRestriction
@export_group("")
@export var _spawn_table: NestedSpawnTable

@export_group("Configuration")

static func _get_adjusted_direction(direction: Level.Direction, clockwise_turns: int) -> Level.Direction:
	var direction_count: int = Level.Direction.size()
	return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)

func create(variation: int, spawn_transform: Transform3D, clockwise_turns: int, status: Structure.Status) -> Structure:
	var new_structure: Structure = (Files.load_kept("uid://d4b5bccvs2ik1") as PackedScene).instantiate()
	new_structure.variation = variation
	new_structure.profile = self
	new_structure.transform = spawn_transform
	new_structure.clockwise_turns = clockwise_turns
	new_structure.status = status
	return new_structure

func can_connect(direction: Level.Direction, clockwise_turns: int, other_profile: StructureProfile) -> bool:
	var restriction: ConnectionRestriction = get_restriction(direction, clockwise_turns)
	return not restriction or restriction.can_connect(self, other_profile)

func get_spawn() -> Profile:
	if not _spawn_table: return
	return _spawn_table.get_spawn()

func get_connections(clockwise_turns: int) -> Array[Level.Direction]:
	var connections: Array[Level.Direction]
	if _connection_up: connections.append(_get_adjusted_direction(Level.Direction.UP, clockwise_turns))
	if _connection_right: connections.append(_get_adjusted_direction(Level.Direction.RIGHT, clockwise_turns))
	if _connection_down: connections.append(_get_adjusted_direction(Level.Direction.DOWN, clockwise_turns))
	if _connection_left: connections.append(_get_adjusted_direction(Level.Direction.LEFT, clockwise_turns))
	return connections

## Whether the profile, turned by [param clockwise_turns], opens towards [param direction]; asked often, so without a list
func has_connection(direction: Level.Direction, clockwise_turns: int) -> bool:
	match posmod(direction - clockwise_turns, Level.Direction.size()):
		Level.Direction.UP: return _connection_up
		Level.Direction.RIGHT: return _connection_right
		Level.Direction.DOWN: return _connection_down
		_: return _connection_left

func get_connection_vectors(clockwise_turns: int) -> Array[Vector2i]:
	var connection_vectors: Array[Vector2i]
	connection_vectors.assign(get_connections(clockwise_turns).map(Level.direction_to_vector))
	return connection_vectors

func get_restrictions(clockwise_turns: int) -> Dictionary[Level.Direction, ConnectionRestriction]:
	return {
		_get_adjusted_direction(Level.Direction.UP, clockwise_turns): _restriction_up,
		_get_adjusted_direction(Level.Direction.RIGHT, clockwise_turns): _restriction_right,
		_get_adjusted_direction(Level.Direction.DOWN, clockwise_turns): _restriction_down,
		_get_adjusted_direction(Level.Direction.LEFT, clockwise_turns): _restriction_left,
	}

## Its restriction towards [param direction], turned by [param clockwise_turns]; asked often, so without a dictionary
func get_restriction(direction: Level.Direction, clockwise_turns: int) -> ConnectionRestriction:
	match posmod(direction - clockwise_turns, Level.Direction.size()):
		Level.Direction.UP: return _restriction_up
		Level.Direction.RIGHT: return _restriction_right
		Level.Direction.DOWN: return _restriction_down
		_: return _restriction_left

## @returns the offsets from the tile center where pieces stand, in order of preference
func get_tile_spots() -> Array[Vector2]:
	var tile_spots: Array[Vector2] = []
	for direction: Vector2 in tile_spot_directions: tile_spots.append(direction * tile_spot_extents)
	return tile_spots

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _to_string() -> String:
	return "%s: %s" % [resource_path.get_file(), room_type]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
