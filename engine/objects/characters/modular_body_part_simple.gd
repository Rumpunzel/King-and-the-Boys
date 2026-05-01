@tool
class_name ModularBodyPartSimple
extends ModularBodyPart

@export_dir var _mesh_directory: String

func _get_mesh_directory() -> String: return _mesh_directory

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _mesh_directory.is_empty(): warnings.append("Mesh directory is empty.")
	return warnings + super._get_configuration_warnings()
