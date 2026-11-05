@tool
class_name ModularCharacter
extends Model

@export_tool_button("Randomize Base", "RandomNumberGenerator") var randomize_base_action: Callable = randomize_base
@export_tool_button("Randomize Gear", "AudioStreamRandomizer") var randomize_gear_action: Callable = randomize_gear
@export_tool_button("Reset Gear", "Clear") var reset_gear_action: Callable = reset_gear
@export_tool_button("Preview Equipment", "Skeleton3D") var preview_equipment_action: Callable = preview_equipment

## Editor-only: applied in order by [method preview_equipment], without slot or blocking rules
@export var _preview_equipment: Array[EquipmentProfile]

const ITEM_DIRECTORY: String = "res://data/equipment"

@export_group("Item Authoring")
@export_tool_button("Save As Item", "Save") var save_as_item_action: Callable = save_as_item
## Editor-only: [method save_as_item] captures the meshes currently shown in this slot
@export var _item_slot: EquipmentProfile.Slot = EquipmentProfile.Slot.HEAD
## Editor-only: parts of these slots are captured too, and the item will empty them when equipped
@export var _item_blocked_slots: Array[EquipmentProfile.Slot]
## Editor-only: the item is saved to [code]res://data/equipment/<slot>/<name>.tres[/code]
@export var _item_name: String
@export_group("")

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

## Saves the meshes shown in [member _item_slot] as a new [EquipmentProfile]; never overwrites an existing item
## @returns the saved path, or an empty [String] on failure
func save_as_item() -> String:
	if _item_name.strip_edges().is_empty():
		push_error("Set an item name before saving.")
		return ""
	var slot_name: String = EquipmentProfile.Slot.keys()[_item_slot]
	var slot_directory: String = "%s/%s" % [ITEM_DIRECTORY, slot_name.to_lower()]
	var item_path: String = "%s/%s.tres" % [slot_directory, _item_name.strip_edges().to_snake_case()]
	if ResourceLoader.exists(item_path):
		push_error("%s already exists; pick another name or delete it first." % item_path)
		return ""
	var equipment_profile: EquipmentProfile = EquipmentProfile.from_model(self, _item_slot, _item_blocked_slots)
	equipment_profile.name = _item_name.strip_edges()
	if equipment_profile.appearance.parts.is_empty(): push_warning("No visible meshes in slot %s; saving an empty item." % EquipmentProfile.Slot.keys()[_item_slot])
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(slot_directory)
	if directory_error != Error.OK:
		push_error("Could not create %s: %s" % [slot_directory, error_string(directory_error)])
		return ""
	var save_error: Error = ResourceSaver.save(equipment_profile, item_path)
	if save_error != Error.OK:
		push_error("Could not save %s: %s" % [item_path, error_string(save_error)])
		return ""
	print("Saved %s with %d parts." % [item_path, equipment_profile.appearance.parts.size()])
	return item_path

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
