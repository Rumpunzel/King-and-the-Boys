@tool
class_name GearProfile
extends Profile

enum Groups {
	ARMOR,
	ITEMS,
	WEAPONS,
}

@export var group: Groups = Groups.ARMOR:
	set(new_value):
		group = new_value
		changed.emit()

@export var model_configuration: ModelConfiguration

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()
