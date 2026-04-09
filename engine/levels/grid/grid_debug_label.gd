@tool
class_name GridDebugLabel
extends Label3D

var cell_position: Vector3i:
	set(new_cell_position):
		cell_position = new_cell_position
		position = Vector3(cell_position) + Vector3(0.5, 0.0, 0.5)
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
	var travel_cost: String
	match (grid_cell.get_script() as GDScript).get_global_name():
		"GroundCell":
			var ground_cell: GroundCell = grid_cell
			travel_cost = "%0.2f->%0.2f" % [ground_cell.travel_cost, ground_cell.get_travel_cost()]
			modulate = Color(ground_cell.get_travel_cost(), 1.0, ground_cell.get_travel_cost())
		"StructureCell":
			var structure_cell: StructureCell = grid_cell
			travel_cost = structure_cell.structure.resource_path.get_file()
			modulate = Color.WHITE
	var grid_position: Vector2i = Vector2i(cell_position.x * 0.5, cell_position.z * 0.5)
	text = "%s\n%s" % [grid_position, travel_cost]
