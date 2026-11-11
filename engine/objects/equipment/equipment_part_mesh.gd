@tool
@icon("uid://dr822xlk56pof")
class_name EquipmentPartMesh
extends Resource

## A part number of the look's [member EquipmentType.model]
@export var part: int:
	set(new_value):
		part = new_value
		changed.emit()
@export var male_mesh: ArrayMesh:
	set(new_value):
		male_mesh = new_value
		changed.emit()
## If empty, [member male_mesh] is used for female body parts as well
@export var female_mesh: ArrayMesh:
	set(new_value):
		female_mesh = new_value
		changed.emit()

func apply_to(model: ModularModel) -> void:
	var body_part: ModularBodyPart = model.get_part(part)
	assert(body_part)
	body_part.apply_mesh(get_mesh_for(body_part))

func get_mesh_for(body_part: ModularBodyPart) -> ArrayMesh:
	if not female_mesh: return male_mesh
	if not body_part is ModularBodyPartGendered: return male_mesh
	var gendered_body_part: ModularBodyPartGendered = body_part
	match gendered_body_part.gender:
		ModularBodyPartGendered.Gender.FEMALE: return female_mesh
		ModularBodyPartGendered.Gender.MALE: return male_mesh
		_: push_error("Gender %s not implemented!" % gendered_body_part.gender)
	assert(false)
	return male_mesh
