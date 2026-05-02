class_name ModelConfigurationRandom
extends ModelConfiguration

@export_group("Body Parts")
@export var _randomize_lower_arms: bool
@export var _randomize_upper_arms: bool
@export var _randomize_ears: bool
@export var _randomize_hands: bool
@export var _randomize_head: bool
@export var _randomize_head_no_elements: bool
@export var _randomize_hips: bool
@export var _randomize_legs: bool
@export var _randomize_torso: bool
@export_group("Hair")
@export var _randomize_eyebrow: bool
@export var _randomize_facial_hair: bool
@export var _randomize_hair: bool
@export_group("Attachments")
@export var _randomize_back_attachment: bool
@export var _randomize_elbow_attachs: bool
@export var _randomize_head_coverings_base_hair: bool
@export var _randomize_head_coverings_no_facial_hair: bool
@export var _randomize_head_coverings_no_hair: bool
@export var _randomize_helmet_attachment: bool
@export var _randomize_hips_attachment: bool
@export var _randomize_knee_attachs: bool
@export var _randomize_shoulder_attachs: bool

func configure(model: ModularCharacter) -> void:
	if _randomize_head: model.head.random_mesh()
	if _randomize_hair: model.hair.random_mesh()
	if _randomize_eyebrow: model.eyebrow.random_mesh()
	if _randomize_ears: model.ears.random_mesh()
	else: model.ears.reset_mesh()
	if _randomize_facial_hair: model.facial_hair.random_mesh()
	else: model.facial_hair.reset_mesh()
	# Gear
	if _randomize_lower_arms:
		model.arm_lower_left.random_mesh()
		model.arm_lower_right.random_mesh()
	if _randomize_upper_arms:
		model.arm_upper_left.random_mesh()
		model.arm_upper_right.random_mesh()
	if _randomize_hands:
		model.hand_left.random_mesh()
		model.hand_right.random_mesh()
	if _randomize_head_no_elements: model.head_no_elements.random_mesh()
	if _randomize_hips: model.hips.random_mesh()
	if _randomize_legs:
		model.leg_left.random_mesh()
		model.leg_right.random_mesh()
	if _randomize_torso: model.torso.random_mesh()
	if _randomize_back_attachment: model.back_attachment.random_mesh()
	if _randomize_elbow_attachs:
		model.elbow_attach_left.random_mesh()
		model.elbow_attach_right.random_mesh()
	if _randomize_head_coverings_base_hair: model.head_coverings_base_hair.random_mesh()
	if _randomize_head_coverings_no_facial_hair: model.head_coverings_no_facial_hair.random_mesh()
	if _randomize_head_coverings_no_hair: model.head_coverings_no_hair.random_mesh()
	if _randomize_helmet_attachment: model.helmet_attachment.random_mesh()
	if _randomize_hips_attachment: model.hips_attachment.random_mesh()
	if _randomize_knee_attachs:
		model.knee_attach_left.random_mesh()
		model.knee_attach_right.random_mesh()
	if _randomize_shoulder_attachs:
		model.shoulder_attach_left.random_mesh()
		model.shoulder_attach_right.random_mesh()
