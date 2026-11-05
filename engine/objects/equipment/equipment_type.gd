@tool
class_name EquipmentType
extends Resource

## A kind of item, such as a helmet or a hood: where it goes, which parts it shows and what it covers

@export var name: String:
	set(new_value):
		name = new_value
		changed.emit()
@export var icon: Texture2D:
	set(new_value):
		icon = new_value
		changed.emit()
@export var slot: EquipmentProfile.Slot = EquipmentProfile.Slot.HEAD:
	set(new_value):
		slot = new_value
		changed.emit()
## The parts items of this type set; each must belong to [member slot] or to one of [member blocked_slots]
@export var parts: Array[ModularCharacter.Part]:
	set(new_value):
		parts = new_value
		changed.emit()
## Slots emptied while an item of this type is equipped, such as a full helmet blocking [constant EquipmentProfile.FACE]
@export var blocked_slots: Array[EquipmentProfile.Slot]:
	set(new_value):
		blocked_slots = new_value
		changed.emit()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var slot_name: String = EquipmentProfile.Slot.keys()[slot]
	if name.is_empty(): warnings.append("Missing name.")
	if parts.is_empty() and EquipmentProfile.get_slot_parts(slot).size() > 0: warnings.append("No parts selected.")
	if blocked_slots.has(slot): warnings.append("Slot %s blocks itself." % slot_name)
	var possible_parts: Array[ModularCharacter.Part] = EquipmentProfile.get_parts_for(slot, blocked_slots)
	for part: ModularCharacter.Part in parts:
		var part_name: String = ModularCharacter.Part.keys()[part]
		if not possible_parts.has(part): warnings.append("Part %s is neither owned by slot %s nor by a blocked slot." % [part_name, slot_name])
	return warnings
