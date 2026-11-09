@tool
class_name DwarfCharacter
extends ModularModel

## The dwarf body: one skinned body mesh with its clothes baked in, plus attachments on bones (hair, beard, helmets, shoulder pads)
## The body is worn as an outfit (slot [constant EquipmentLook.TORSO]); hair, beard and beard rings are rolled per character
## Saved types and catalogs store parts by number: only append new parts

enum Part {
	BODY,
	HAIR,
	BEARD,
	BEARD_ATTACHMENT,
	HEADWEAR,
	FACE,
	SHOULDER_LEFT,
	SHOULDER_RIGHT,
}

## The parts each slot owns; the body is the outfit, worn together with the shoulder pads
const SLOT_PARTS: Dictionary[EquipmentLook.Slot, Array] = {
	EquipmentLook.Slot.HEAD: [Part.HEADWEAR],
	EquipmentLook.Slot.FACE: [Part.FACE],
	EquipmentLook.Slot.TORSO: [Part.BODY, Part.SHOULDER_LEFT, Part.SHOULDER_RIGHT],
}

@export_group("Body Parts")
@export var body: ModularBodyPart
@export_group("Hair")
@export var hair: ModularBodyPart
@export var beard: ModularBodyPart
@export var beard_attachment: ModularBodyPart
@export_group("Attachments")
@export var headwear: ModularBodyPart
@export var face: ModularBodyPart
@export var shoulder_left: ModularBodyPart
@export var shoulder_right: ModularBodyPart

func get_part_keys() -> PackedStringArray: return PackedStringArray(Part.keys())

func get_slot_parts(slot: EquipmentLook.Slot) -> Array[int]:
	var parts: Array[int] = []
	parts.assign(SLOT_PARTS.get(slot, []) as Array)
	return parts
