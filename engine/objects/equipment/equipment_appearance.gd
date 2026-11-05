@tool
class_name EquipmentAppearance
extends ModelConfiguration

@export var parts: Array[EquipmentPartMesh]:
	set(new_value):
		parts = new_value
		changed.emit()

func configure(model: ModularCharacter) -> void:
	for part_mesh: EquipmentPartMesh in parts: part_mesh.apply_to(model)

func get_parts() -> Array[ModularCharacter.Part]:
	var configured_parts: Array[ModularCharacter.Part] = []
	for part_mesh: EquipmentPartMesh in parts: configured_parts.append(part_mesh.part)
	return configured_parts
