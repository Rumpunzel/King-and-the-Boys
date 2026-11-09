@tool
class_name ModularCharacter
extends ModularModel

## The modular human body: gendered meshes per part, where equipment swaps individual parts such as arms or knees

enum Part {
	ARM_LOWER_LEFT,
	ARM_LOWER_RIGHT,
	ARM_UPPER_LEFT,
	ARM_UPPER_RIGHT,
	EARS,
	HAND_LEFT,
	HAND_RIGHT,
	HEAD,
	HEAD_NO_ELEMENTS,
	HIPS,
	LEG_LEFT,
	LEG_RIGHT,
	TORSO,
	EYEBROW,
	FACIAL_HAIR,
	HAIR,
	BACK_ATTACHMENT,
	ELBOW_ATTACH_LEFT,
	ELBOW_ATTACH_RIGHT,
	HEAD_COVERINGS_BASE_HAIR,
	HEAD_COVERINGS_NO_FACIAL_HAIR,
	HEAD_COVERINGS_NO_HAIR,
	HELMET_ATTACHMENT,
	HIPS_ATTACHMENT,
	KNEE_ATTACH_LEFT,
	KNEE_ATTACH_RIGHT,
	SHOULDER_ATTACH_LEFT,
	SHOULDER_ATTACH_RIGHT,
}

## The parts each slot owns; weapons attach to bone sockets, not body parts
const SLOT_PARTS: Dictionary[EquipmentLook.Slot, Array] = {
	EquipmentLook.Slot.HEAD: [Part.HEAD_COVERINGS_BASE_HAIR, Part.HEAD_COVERINGS_NO_HAIR, Part.HEAD_NO_ELEMENTS, Part.HELMET_ATTACHMENT],
	EquipmentLook.Slot.FACE: [Part.HEAD_COVERINGS_NO_FACIAL_HAIR],
	EquipmentLook.Slot.TORSO: [Part.TORSO, Part.ARM_UPPER_LEFT, Part.ARM_UPPER_RIGHT, Part.SHOULDER_ATTACH_LEFT, Part.SHOULDER_ATTACH_RIGHT],
	EquipmentLook.Slot.HANDS: [Part.ARM_LOWER_LEFT, Part.ARM_LOWER_RIGHT, Part.HAND_LEFT, Part.HAND_RIGHT, Part.ELBOW_ATTACH_LEFT, Part.ELBOW_ATTACH_RIGHT],
	EquipmentLook.Slot.LEGS: [Part.HIPS, Part.LEG_LEFT, Part.LEG_RIGHT, Part.KNEE_ATTACH_LEFT, Part.KNEE_ATTACH_RIGHT],
	EquipmentLook.Slot.WAIST: [Part.HIPS_ATTACHMENT],
	EquipmentLook.Slot.BACK: [Part.BACK_ATTACHMENT],
}

@export_group("Body Parts")
@export var arm_lower_left: ModularBodyPartGendered
@export var arm_lower_right: ModularBodyPartGendered
@export var arm_upper_left: ModularBodyPartGendered
@export var arm_upper_right: ModularBodyPartGendered
@export var ears: ModularBodyPart
@export var hand_left: ModularBodyPartGendered
@export var hand_right: ModularBodyPartGendered
@export var head: ModularBodyPartGendered
@export var head_no_elements: ModularBodyPartGendered
@export var hips: ModularBodyPartGendered
@export var leg_left: ModularBodyPartGendered
@export var leg_right: ModularBodyPartGendered
@export var torso: ModularBodyPartGendered
@export_group("Hair")
@export var eyebrow: ModularBodyPartGendered
@export var facial_hair: ModularBodyPartGendered
@export var hair: ModularBodyPart
@export_group("Attachments")
@export var back_attachment: ModularBodyPart
@export var elbow_attach_left: ModularBodyPart
@export var elbow_attach_right: ModularBodyPart
@export var head_coverings_base_hair: ModularBodyPart
@export var head_coverings_no_facial_hair: ModularBodyPart
@export var head_coverings_no_hair: ModularBodyPart
@export var helmet_attachment: ModularBodyPart
@export var hips_attachment: ModularBodyPart
@export var knee_attach_left: ModularBodyPart
@export var knee_attach_right: ModularBodyPart
@export var shoulder_attach_left: ModularBodyPart
@export var shoulder_attach_right: ModularBodyPart

func get_part_keys() -> PackedStringArray: return PackedStringArray(Part.keys())

func get_slot_parts(slot: EquipmentLook.Slot) -> Array[int]:
	var parts: Array[int] = []
	parts.assign(SLOT_PARTS.get(slot, []) as Array)
	return parts
