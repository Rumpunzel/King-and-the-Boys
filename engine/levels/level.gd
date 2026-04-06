@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

@export_group("Configuration")
@export var _navigation_region: NavigationRegion3D

var _grid: Dictionary[Vector3i, GridCell]
var _debugs: Dictionary[Vector3i, Label3D]

func _ready() -> void:
	for z: int in range(-32, 32):
		for x: int in range(-32, 32):
			var cell_position: Vector3i = Vector3i(x, 0, z)
			#if not _debugs.has(cell_position): _create_debug_label(cell_position)

static func get_grid_cell_of_node(node: Node3D) -> Vector3i:
	return get_grid_cell(node.global_position)

static func get_grid_cell(world_position: Vector3) -> Vector3i:
	return Vector3i(world_position)

func _create_debug_label(cell_position: Vector3i) -> GridDebugLabel:
	var debug_label: GridDebugLabel = GridDebugLabel.new()
	debug_label.cell_position = cell_position
	add_child(debug_label)
	_debugs[cell_position] = debug_label
	return debug_label

func _update_debug(cell_position: Vector3i, grid_cell: GridCell) -> void:
	var debug_label: GridDebugLabel = _debugs.get_or_add(cell_position, _create_debug_label(cell_position))
	debug_label.grid_cell = grid_cell
	debug_label.update_text()

func _on_character_entered_grid_cell(cell_position: Vector3i) -> void:
	var ground_cell: GroundCell = _grid.get_or_add(cell_position, GridCell.get_default())
	ground_cell.times_entered += 1
	_grid[cell_position] = ground_cell
	_update_debug(cell_position, ground_cell)

func _on_structure_created(structure: Structure) -> void:
	for cell_position: Vector3i in structure.get_grid_cells():
		var structure_cell: StructureCell = StructureCell.new(structure.profile, cell_position)
		_grid[cell_position] = structure_cell
		_update_debug(cell_position, structure_cell)
	if _navigation_region.is_baking():
		await _navigation_region.bake_finished
		_navigation_region.bake_navigation_mesh()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _navigation_region: warnings.append("Missing NavigationRegion3D reference.")
	return warnings
