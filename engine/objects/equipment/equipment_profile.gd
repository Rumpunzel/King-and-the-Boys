@tool
class_name EquipmentProfile
extends Profile

enum Slot {
	HEAD,
	FACE,
	TORSO,
	HANDS,
	LEGS,
	BACK,
	MAIN_HAND,
	OFF_HAND,
}

## Loaded on demand instead of preloaded, as the [ModularCharacter] scene itself depends on this script
const _PREVIEW_MODEL_UID: String = "uid://c6oheyitbnlpu"

@export var slot: Slot = Slot.HEAD:
	set(new_value):
		slot = new_value
		changed.emit()
@export var appearance: EquipmentAppearance:
	set(new_value):
		appearance = new_value
		changed.emit()
## Slots that are emptied while this item is equipped, such as a full helmet blocking [constant FACE]
@export var blocked_slots: Array[Slot]:
	set(new_value):
		blocked_slots = new_value
		changed.emit()

## Captures what [param model] currently shows in [param for_slot] and [param for_blocked_slots] as a new item
## Gendered meshes get their other-gender counterpart if one exists with the same number
static func from_model(model: ModularCharacter, for_slot: Slot, for_blocked_slots: Array[Slot] = []) -> EquipmentProfile:
	var equipment_profile: EquipmentProfile = EquipmentProfile.new()
	equipment_profile.slot = for_slot
	equipment_profile.blocked_slots = for_blocked_slots
	equipment_profile.appearance = EquipmentAppearance.new()
	var parts: Array[EquipmentPartMesh] = []
	for part: ModularCharacter.Part in equipment_profile.get_allowed_parts():
		var body_part: ModularBodyPart = model.get_part(part)
		if not body_part.visible or not body_part.mesh: continue
		var mesh: ArrayMesh = body_part.mesh
		var part_mesh: EquipmentPartMesh = EquipmentPartMesh.new()
		part_mesh.part = part
		part_mesh.male_mesh = mesh
		if body_part is ModularBodyPartGendered:
			var gendered_body_part: ModularBodyPartGendered = body_part
			var other_gender_mesh: ArrayMesh = _find_other_gender_mesh(mesh, gendered_body_part.gender)
			if not other_gender_mesh: push_warning("No other-gender mesh found for %s; it is used for both." % mesh.resource_path)
			elif gendered_body_part.gender == ModularBodyPartGendered.Gender.FEMALE:
				part_mesh.male_mesh = other_gender_mesh
				part_mesh.female_mesh = mesh
			else: part_mesh.female_mesh = other_gender_mesh
		parts.append(part_mesh)
	equipment_profile.appearance.parts = parts
	return equipment_profile

static func _find_other_gender_mesh(mesh: ArrayMesh, gender: ModularBodyPartGendered.Gender) -> ArrayMesh:
	var mesh_path: String = mesh.resource_path
	var other_mesh_path: String
	match gender:
		ModularBodyPartGendered.Gender.MALE: other_mesh_path = mesh_path.replace("/male/", "/female/").replace("_Male_", "_Female_")
		ModularBodyPartGendered.Gender.FEMALE: other_mesh_path = mesh_path.replace("/female/", "/male/").replace("_Female_", "_Male_")
		_: push_error("Gender %s not implemented!" % gender)
	if other_mesh_path == mesh_path or not ResourceLoader.exists(other_mesh_path): return null
	return load(other_mesh_path)

## @returns the [ModularCharacter.Part]s a [enum Slot] owns and resets on equip
static func get_slot_parts(for_slot: Slot) -> Array[ModularCharacter.Part]:
	match for_slot:
		Slot.HEAD: return [
			ModularCharacter.Part.HEAD_COVERINGS_BASE_HAIR,
			ModularCharacter.Part.HEAD_COVERINGS_NO_HAIR,
			ModularCharacter.Part.HEAD_NO_ELEMENTS,
			ModularCharacter.Part.HELMET_ATTACHMENT,
		]
		Slot.FACE: return [
			ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR,
		]
		Slot.TORSO: return [
			ModularCharacter.Part.TORSO,
			ModularCharacter.Part.ARM_UPPER_LEFT,
			ModularCharacter.Part.ARM_UPPER_RIGHT,
			ModularCharacter.Part.SHOULDER_ATTACH_LEFT,
			ModularCharacter.Part.SHOULDER_ATTACH_RIGHT,
		]
		Slot.HANDS: return [
			ModularCharacter.Part.ARM_LOWER_LEFT,
			ModularCharacter.Part.ARM_LOWER_RIGHT,
			ModularCharacter.Part.HAND_LEFT,
			ModularCharacter.Part.HAND_RIGHT,
			ModularCharacter.Part.ELBOW_ATTACH_LEFT,
			ModularCharacter.Part.ELBOW_ATTACH_RIGHT,
		]
		Slot.LEGS: return [
			ModularCharacter.Part.HIPS,
			ModularCharacter.Part.LEG_LEFT,
			ModularCharacter.Part.LEG_RIGHT,
			ModularCharacter.Part.KNEE_ATTACH_LEFT,
			ModularCharacter.Part.KNEE_ATTACH_RIGHT,
			ModularCharacter.Part.HIPS_ATTACHMENT,
		]
		Slot.BACK: return [
			ModularCharacter.Part.BACK_ATTACHMENT,
		]
		# Weapons attach to bone sockets, not body parts
		Slot.MAIN_HAND, Slot.OFF_HAND: return []
		_: push_error("Slot %s not implemented!" % for_slot)
	assert(false)
	return []

## @returns the [ModularCharacter.Part]s an item in [param for_slot] blocking [param for_blocked_slots] may set
static func get_parts_for(for_slot: Slot, for_blocked_slots: Array[Slot]) -> Array[ModularCharacter.Part]:
	var parts: Array[ModularCharacter.Part] = get_slot_parts(for_slot)
	for blocked_slot: Slot in for_blocked_slots:
		if blocked_slot != for_slot: parts.append_array(get_slot_parts(blocked_slot))
	return parts

## @returns the [ModularCharacter.Part]s this item may set: those of its own [member slot] and its [member blocked_slots]
func get_allowed_parts() -> Array[ModularCharacter.Part]: return get_parts_for(slot, blocked_slots)

## Previews, such as Menagerie, show the item on a plain [ModularCharacter]
func create_model(_variation: int) -> Model:
	var scene: PackedScene = load(_PREVIEW_MODEL_UID)
	var model: ModularCharacter = scene.instantiate()
	model.reset_gear()
	if appearance: appearance.configure(model)
	return model

func get_variation_count() -> int: return 1
func get_random_variation() -> int: return 0

func get_group_name() -> StringName:
	var group_name: StringName = Slot.keys()[slot]
	return group_name.capitalize()

func _get_configuration_warnings() -> PackedStringArray:
	# Equipment has no model variations of its own, so the [Profile] warnings do not apply
	var warnings: PackedStringArray = []
	if not appearance:
		warnings.append("Missing EquipmentAppearance.")
		return warnings
	if blocked_slots.has(slot): warnings.append("Slot %s blocks itself." % Slot.keys()[slot])
	var allowed_parts: Array[ModularCharacter.Part] = get_allowed_parts()
	for part_mesh: EquipmentPartMesh in appearance.parts:
		if not part_mesh:
			warnings.append("Empty EquipmentPartMesh entry.")
			continue
		var part_name: String = ModularCharacter.Part.keys()[part_mesh.part]
		if not allowed_parts.has(part_mesh.part): warnings.append("Part %s is neither owned by slot %s nor by a blocked slot." % [part_name, Slot.keys()[slot]])
		if not part_mesh.male_mesh: warnings.append("Part %s has no male mesh." % part_name)
	return warnings
