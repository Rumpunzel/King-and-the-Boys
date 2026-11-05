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
## Parts that change together and share a mesh number; left and right parts are linked even without a group
@export var part_groups: Array[EquipmentPartGroup]:
	set(new_value):
		for part_group: EquipmentPartGroup in part_groups:
			if part_group and part_group.changed.is_connected(changed.emit): part_group.changed.disconnect(changed.emit)
		part_groups = new_value
		for part_group: EquipmentPartGroup in part_groups:
			if part_group and not part_group.changed.is_connected(changed.emit): part_group.changed.connect(changed.emit)
		changed.emit()
## Slots emptied while an item of this type is equipped, such as a full helmet blocking [constant EquipmentProfile.FACE]
@export var blocked_slots: Array[EquipmentProfile.Slot]:
	set(new_value):
		blocked_slots = new_value
		changed.emit()

## @returns the linked parts: each [member part_groups] entry, plus left/right pairs not already grouped
func get_links() -> Array[Array]:
	var links: Array[Array] = []
	var grouped: Array[ModularCharacter.Part] = []
	for part_group: EquipmentPartGroup in part_groups:
		if not part_group: continue
		var link: Array[ModularCharacter.Part] = []
		for part: ModularCharacter.Part in part_group.parts:
			if parts.has(part) and not grouped.has(part): link.append(part)
		if link.size() < 2: continue
		links.append(link)
		grouped.append_array(link)
	for part: ModularCharacter.Part in parts:
		var part_name: String = ModularCharacter.Part.keys()[part]
		if not part_name.ends_with("_LEFT"): continue
		var right_name: String = part_name.trim_suffix("_LEFT") + "_RIGHT"
		if not ModularCharacter.Part.has(right_name): continue
		var right_part: ModularCharacter.Part = ModularCharacter.Part[right_name]
		if not parts.has(right_part) or grouped.has(part) or grouped.has(right_part): continue
		var pair: Array[ModularCharacter.Part] = [part, right_part]
		links.append(pair)
	return links

## @returns the parts linked with [param part], including itself
func get_link_of(part: ModularCharacter.Part) -> Array[ModularCharacter.Part]:
	for link: Array in get_links():
		if link.has(part):
			var typed_link: Array[ModularCharacter.Part] = []
			typed_link.assign(link)
			return typed_link
	return [part]

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
	var grouped: Array[ModularCharacter.Part] = []
	for part_group: EquipmentPartGroup in part_groups:
		if not part_group: continue
		for part: ModularCharacter.Part in part_group.parts:
			var part_name: String = ModularCharacter.Part.keys()[part]
			if not parts.has(part): warnings.append("Grouped part %s is not one of this type's parts." % part_name)
			if grouped.has(part): warnings.append("Part %s is in more than one group." % part_name)
			grouped.append(part)
	return warnings
