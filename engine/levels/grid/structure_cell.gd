class_name StructureCell
extends GridCell

var structure: StructureProfile
var index_in_structure: Vector3i

func _init(new_structure: StructureProfile, new_index_in_structure: Vector3i) -> void:
	structure = new_structure
	index_in_structure = new_index_in_structure
