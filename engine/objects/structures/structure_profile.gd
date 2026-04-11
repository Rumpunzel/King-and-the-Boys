@tool
@icon("uid://bes0anop2dh5u")
class_name StructureProfile
extends Profile

enum Groups {
	BUILDING,
	FLORA,
	TILE,
}

@export var connections: Dictionary[Level.Direction, RoomType] = {Level.Direction.UP: null, Level.Direction.RIGHT: null, Level.Direction.DOWN: null, Level.Direction.LEFT: null}
@export var room_type: RoomType
@export var group: Groups = Groups.BUILDING

@export var grid_cell_extents: Vector3i = Vector3i.ONE

@export_group("")
@export_group("Configuration")

func create(variation: int, spawn_transform: Transform3D, clockwise_turns: int, status: Structure.Status) -> Structure:
	var scene: PackedScene = load("uid://d4b5bccvs2ik1")
	var new_structure: Structure = scene.instantiate()
	new_structure.variation = variation
	new_structure.profile = self
	new_structure.transform = spawn_transform
	new_structure.clockwise_turns = clockwise_turns
	new_structure.status = status
	return new_structure

func has_restrictions() -> bool:
	return connections.values().any(func(restriction: RoomType) -> bool: return restriction != null)

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _to_string() -> String:
	return "%s: %s -> %s" % [resource_path.get_file(), room_type, connections]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
