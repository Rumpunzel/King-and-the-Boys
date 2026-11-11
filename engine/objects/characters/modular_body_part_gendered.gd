@tool
@icon("uid://s7oh36muqnkf")
class_name ModularBodyPartGendered
extends ModularBodyPart

enum Gender {
	FEMALE,
	MALE,
}

@export_dir var _female_mesh_directory: String
@export_dir var _male_mesh_directory: String
## Which of the two mesh directories the part lists; changing it lists the other one and shows the mesh of the same number there
## (the first, or none for decorative parts, where it has none), e.g. so [method ModularModel.set_gender] turns a whole body
## Declared after the directories: a scene storing it has set its mesh already, and the setter lists the new directory
@export var gender: Gender = Gender.MALE:
	set(new_gender):
		if new_gender == gender: return
		var number: String = get_mesh_number(mesh.resource_path) if mesh else ""
		gender = new_gender
		_mesh_list = []
		if not mesh: return
		# A part gear hides (hair under a helmet) stays hidden
		var shown: bool = visible
		update_index(_find_index_after_change(number))
		if not shown and visible: update_visibility(false)

## Where the mesh numbered [param number] is in the newly listed directory; the first mesh, or none for parts that may show none, if
## it has no such mesh (e.g. female bodies have no facial hair)
func _find_index_after_change(number: String) -> int:
	var index: int = find_mesh_index(number) if not number.is_empty() else -1
	if index >= 0 or allows_none(): return index
	return 0

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
