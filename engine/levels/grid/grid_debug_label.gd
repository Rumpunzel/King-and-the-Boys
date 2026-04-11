@tool
class_name GridDebugLabel
extends Label3D

var cell_position: Vector3:
	set(new_cell_position):
		cell_position = new_cell_position
		position = cell_position
		update_text()

var grid_cell: GridCell:
	set(new_grid_cell):
		grid_cell = new_grid_cell
		update_text()

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true

func update_text() -> void:
	if not grid_cell:
		text = "%s\n%0.2f\n-" % [cell_position, GridCell.DEFAULT_TRAVEL_COST]
		return
	var structure_cell: StructureCell = grid_cell
	text = "%s\n%s" % [Vector2i(cell_position.x, cell_position.z), structure_cell.structure.resource_path.get_file()]
