@tool
@icon("uid://b2gskja6u1rym")
class_name EquipmentPartGroup
extends Resource

## Parts that show meshes with the same number, e.g. lower arms and hands of one glove set
## The first part leads: combinations use its numbers, and parts lacking a number keep their mesh

@export var parts: Array[int]:
	set(new_value):
		parts = new_value
		changed.emit()
