@tool
class_name EquipmentPartGroup
extends Resource

## Parts that always show meshes with the same number, e.g. lower arms and hands of one glove set

@export var parts: Array[ModularCharacter.Part]:
	set(new_value):
		parts = new_value
		changed.emit()
