@tool
class_name ModularCharacter
extends Model

@export_tool_button("Randomize", "RandomNumberGenerator") var _randomize_action: Callable = _randomize
@export_group("Body Parts")
@export var arm_lower_left: ModularBodyPartGendered
@export var arm_lower_right: ModularBodyPartGendered
@export var arm_upper_left: ModularBodyPartGendered
@export var arm_upper_right: ModularBodyPartGendered
@export var ear: ModularBodyPart
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

func _randomize() -> void:
	arm_lower_left.random_mesh()
	arm_lower_right.random_mesh()
	arm_upper_left.random_mesh()
	arm_upper_right.random_mesh()
	ear.random_mesh()
	hand_left.random_mesh()
	hand_right.random_mesh()
	head.random_mesh()
	head_no_elements.random_mesh()
	hips.random_mesh()
	leg_left.random_mesh()
	leg_right.random_mesh()
	torso.random_mesh()
	eyebrow.random_mesh()
	facial_hair.random_mesh()
	hair.random_mesh()
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
