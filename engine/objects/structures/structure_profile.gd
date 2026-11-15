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

func create(variation: int, spawn_transform: Transform3D, clockwise_turns: int, status: Structure.Status, light: TileLight = null) -> Structure:
	var new_structure: Structure = (Files.load_kept("uid://d4b5bccvs2ik1") as PackedScene).instantiate()
	new_structure.variation = variation
	new_structure.profile = self
	new_structure.transform = spawn_transform
	new_structure.clockwise_turns = clockwise_turns
	new_structure.status = status
	new_structure.light = light
	return new_structure

func can_connect(direction: Level.Direction, clockwise_turns: int, other_profile: StructureProfile) -> bool:
	var restriction: ConnectionRestriction = get_restriction(direction, clockwise_turns)
	return not restriction or restriction.can_connect(self, other_profile)

func get_spawn() -> Profile:
	if not _spawn_table: return
	return _spawn_table.get_spawn()

## In the order of the unturned sides: corridors are built in this order, so another order would build another dungeon from
## the same seed
func get_connections(clockwise_turns: int) -> Array[Level.Direction]:
	var connections: Array[Level.Direction]
	if _connection_up: connections.append(Level.turn_direction(Level.Direction.UP, clockwise_turns))
	if _connection_right: connections.append(Level.turn_direction(Level.Direction.RIGHT, clockwise_turns))
	if _connection_down: connections.append(Level.turn_direction(Level.Direction.DOWN, clockwise_turns))
	if _connection_left: connections.append(Level.turn_direction(Level.Direction.LEFT, clockwise_turns))
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
	var restrictions: Dictionary[Level.Direction, ConnectionRestriction] = {}
	for direction: Level.Direction in Level.Direction.values(): restrictions[direction] = get_restriction(direction, clockwise_turns)
	return restrictions

## Its restriction towards [param direction], turned by [param clockwise_turns]; asked often, so without a dictionary
func get_restriction(direction: Level.Direction, clockwise_turns: int) -> ConnectionRestriction:
	match posmod(direction - clockwise_turns, Level.Direction.size()):
		Level.Direction.UP: return _restriction_up
		Level.Direction.RIGHT: return _restriction_right
		Level.Direction.DOWN: return _restriction_down
		_: return _restriction_left

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _to_string() -> String:
	return "%s: %s" % [resource_path.get_file(), room_type]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
