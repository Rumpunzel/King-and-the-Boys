@tool
class_name ModularBodyPartGendered
extends ModularBodyPart

enum Gender {
	FEMALE,
	MALE,
}

@export var gender: Gender = Gender.MALE

@export_dir var _female_mesh_directory: String
@export_dir var _male_mesh_directory: String

func _get_mesh_directory() -> String:
	match gender:
		Gender.FEMALE: return _female_mesh_directory
		Gender.MALE: return _male_mesh_directory
		_: push_error("Gender %s not implemented!" % gender)
	assert(false)
	return ""

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _female_mesh_directory.is_empty(): warnings.append("Female mesh directory is empty.")
	if _male_mesh_directory.is_empty(): warnings.append("Male mesh directory is empty.")
	return warnings + super._get_configuration_warnings()
