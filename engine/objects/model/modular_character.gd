@tool
class_name ModularCharacter
extends Model

@export_tool_button("Randomize Base", "RandomNumberGenerator") var randomize_base_action: Callable = randomize_base
@export_tool_button("Randomize Gear", "AudioStreamRandomizer") var randomize_gear_action: Callable = randomize_gear
@export_tool_button("Reset Gear", "Clear") var reset_gear_action: Callable = reset_gear
@export_tool_button("Preview Equipment", "Skeleton3D") var preview_equipment_action: Callable = preview_equipment

## Editor-only: applied in order by [method preview_equipment], without slot or blocking rules
@export var _preview_equipment: Array[EquipmentProfile]

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

func get_part(part: Part) -> ModularBodyPart:
	match part:
		Part.ARM_LOWER_LEFT: return arm_lower_left
		Part.ARM_LOWER_RIGHT: return arm_lower_right
		Part.ARM_UPPER_LEFT: return arm_upper_left
		Part.ARM_UPPER_RIGHT: return arm_upper_right
		Part.EARS: return ears
		Part.HAND_LEFT: return hand_left
		Part.HAND_RIGHT: return hand_right
		Part.HEAD: return head
		Part.HEAD_NO_ELEMENTS: return head_no_elements
		Part.HIPS: return hips
		Part.LEG_LEFT: return leg_left
		Part.LEG_RIGHT: return leg_right
		Part.TORSO: return torso
		Part.EYEBROW: return eyebrow
		Part.FACIAL_HAIR: return facial_hair
		Part.HAIR: return hair
		Part.BACK_ATTACHMENT: return back_attachment
		Part.ELBOW_ATTACH_LEFT: return elbow_attach_left
		Part.ELBOW_ATTACH_RIGHT: return elbow_attach_right
		Part.HEAD_COVERINGS_BASE_HAIR: return head_coverings_base_hair
		Part.HEAD_COVERINGS_NO_FACIAL_HAIR: return head_coverings_no_facial_hair
		Part.HEAD_COVERINGS_NO_HAIR: return head_coverings_no_hair
		Part.HELMET_ATTACHMENT: return helmet_attachment
		Part.HIPS_ATTACHMENT: return hips_attachment
		Part.KNEE_ATTACH_LEFT: return knee_attach_left
		Part.KNEE_ATTACH_RIGHT: return knee_attach_right
		Part.SHOULDER_ATTACH_LEFT: return shoulder_attach_left
		Part.SHOULDER_ATTACH_RIGHT: return shoulder_attach_right
		_: push_error("Part %s not implemented!" % part)
	assert(false)
	return null

func preview_equipment() -> void:
	reset_gear()
	for equipment_profile: EquipmentProfile in _preview_equipment:
		if not equipment_profile or not equipment_profile.appearance: continue
		equipment_profile.appearance.configure(self)

func randomize_base() -> void:
	ears.random_mesh()
	head.random_mesh()
	eyebrow.random_mesh()
	facial_hair.random_mesh()
	hair.random_mesh()

func randomize_gear() -> void:
	arm_lower_left.random_mesh()
	arm_lower_right.random_mesh()
	arm_upper_left.random_mesh()
	arm_upper_right.random_mesh()
	hand_left.random_mesh()
	hand_right.random_mesh()
	head_no_elements.random_mesh()
	hips.random_mesh()
	leg_left.random_mesh()
	leg_right.random_mesh()
	torso.random_mesh()
	back_attachment.random_mesh()
	elbow_attach_left.random_mesh()
	elbow_attach_right.random_mesh()
	head_coverings_base_hair.random_mesh()
	head_coverings_no_facial_hair.random_mesh()
	head_coverings_no_hair.random_mesh()
	helmet_attachment.random_mesh()
	hips_attachment.random_mesh()
	knee_attach_left.random_mesh()
	knee_attach_right.random_mesh()
	shoulder_attach_left.random_mesh()
	shoulder_attach_right.random_mesh()

func reset() -> void:
	ears.reset_mesh()
	head.reset_mesh()
	eyebrow.reset_mesh()
	facial_hair.reset_mesh()
	hair.reset_mesh()
	reset_gear()

func reset_gear() -> void:
	arm_lower_left.reset_mesh()
	arm_lower_right.reset_mesh()
	arm_upper_left.reset_mesh()
	arm_upper_right.reset_mesh()
	hand_left.reset_mesh()
	hand_right.reset_mesh()
	head_no_elements.reset_mesh()
	hips.reset_mesh()
	leg_left.reset_mesh()
	leg_right.reset_mesh()
	torso.reset_mesh()
	back_attachment.reset_mesh()
	elbow_attach_left.reset_mesh()
	elbow_attach_right.reset_mesh()
	head_coverings_base_hair.reset_mesh()
	head_coverings_no_facial_hair.reset_mesh()
	head_coverings_no_hair.reset_mesh()
	helmet_attachment.reset_mesh()
	hips_attachment.reset_mesh()
	knee_attach_left.reset_mesh()
	knee_attach_right.reset_mesh()
	shoulder_attach_left.reset_mesh()
	shoulder_attach_right.reset_mesh()
