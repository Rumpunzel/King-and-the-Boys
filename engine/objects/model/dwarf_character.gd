@tool
class_name DwarfCharacter
extends ModularModel

## The dwarf body: one skinned body mesh with its clothes baked in, plus attachments on bones (hair, beard, helmets, shoulder pads)
## The body is worn as an outfit (slot [constant EquipmentLook.TORSO]); hair, beard and beard rings are rolled per character
## Weapons and shields are attachments on the hands, from the shared meshes in [code]data/equipment/meshes/[/code]
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
	MAIN_HAND,
	TWO_HANDED,
	OFF_HAND,
}

## The parts each slot owns; the body is the outfit, worn together with the shoulder pads
const SLOT_PARTS: Dictionary[EquipmentLook.Slot, Array] = {
	EquipmentLook.Slot.HEAD: [Part.HEADWEAR],
	EquipmentLook.Slot.FACE: [Part.FACE],
	EquipmentLook.Slot.TORSO: [Part.BODY, Part.SHOULDER_LEFT, Part.SHOULDER_RIGHT],
	# One weapon in the right hand: one-handed, or two-handed (whose type blocks the off hand)
	EquipmentLook.Slot.MAIN_HAND: [Part.MAIN_HAND, Part.TWO_HANDED],
	EquipmentLook.Slot.OFF_HAND: [Part.OFF_HAND],
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
@export_group("Hands")
@export var main_hand: ModularBodyPart
@export var two_handed: ModularBodyPart
@export var off_hand: ModularBodyPart

func get_part_keys() -> PackedStringArray: return PackedStringArray(Part.keys())

func get_slot_parts(slot: EquipmentLook.Slot) -> Array[int]:
	var parts: Array[int] = []
	parts.assign(SLOT_PARTS.get(slot, []) as Array)
	return parts
