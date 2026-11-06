@tool
class_name EquipmentLook
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
	# Appended last, as slots are stored by number in saved types
	WAIST,
}

## Where items live; peers may only request items from here
const ITEM_DIRECTORY: String = "res://data/equipment"

## Loaded on demand instead of preloaded, as the [ModularCharacter] scene itself depends on this script
const _PREVIEW_MODEL_UID: String = "uid://c6oheyitbnlpu"

## Decides the slot, the parts this item may set and the slots it blocks
@export var type: EquipmentType:
	set(new_value):
		if type and type.changed.is_connected(changed.emit): type.changed.disconnect(changed.emit)
		type = new_value
		if type and not type.changed.is_connected(changed.emit): type.changed.connect(changed.emit)
		changed.emit()
@export var appearance: EquipmentAppearance:
	set(new_value):
		if appearance and appearance.changed.is_connected(changed.emit): appearance.changed.disconnect(changed.emit)
		appearance = new_value
		if appearance and not appearance.changed.is_connected(changed.emit): appearance.changed.connect(changed.emit)
		changed.emit()
## Whether this look is meant to be used; unchecked looks of a catalog stay recorded but are not offered or worn
@export var allowed: bool = true:
	set(new_value):
		allowed = new_value
		changed.emit()

var slot: Slot:
	get:
		assert(type, "EquipmentLook %s has no EquipmentType!" % resource_path)
		return type.slot if type else Slot.HEAD
var blocked_slots: Array[Slot]:
	get: return type.blocked_slots if type else [] as Array[Slot]

## Captures what [param model] currently shows in the parts of [param for_type] as a new item
## Gendered meshes get their other-gender counterpart if one exists with the same number
static func from_model(model: ModularCharacter, for_type: EquipmentType) -> EquipmentLook:
	var equipment_look: EquipmentLook = EquipmentLook.new()
	equipment_look.type = for_type
	equipment_look.appearance = EquipmentAppearance.new()
	var parts: Array[EquipmentPartMesh] = []
	for part: ModularCharacter.Part in for_type.parts:
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
	equipment_look.appearance.parts = parts
	return equipment_look

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
		]
		Slot.WAIST: return [
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

## @returns the [ModularCharacter.Part]s of [param for_slot] and [param for_blocked_slots]
static func get_parts_for(for_slot: Slot, for_blocked_slots: Array[Slot]) -> Array[ModularCharacter.Part]:
	var parts: Array[ModularCharacter.Part] = get_slot_parts(for_slot)
	for blocked_slot: Slot in for_blocked_slots:
		if blocked_slot != for_slot: parts.append_array(get_slot_parts(blocked_slot))
	return parts

## @returns every part equipping or unequipping this item resets: all parts of its slot and of the slots it blocks
func get_reset_parts() -> Array[ModularCharacter.Part]: return get_parts_for(slot, blocked_slots)

## Previews, such as Menagerie, show the item on a plain [ModularCharacter]
func create_model(_variation: int) -> Model:
	var scene: PackedScene = load(_PREVIEW_MODEL_UID)
	var model: ModularCharacter = scene.instantiate()
	model.reset_gear()
	if appearance: appearance.configure(model)
	return model

func get_variation_count() -> int: return 1
func get_random_variation() -> int: return 0

## The look's mesh for its type's first part, e.g. "Torso 05"; looks of one base are variations of each other
func get_base_name() -> String:
	if not type or type.parts.is_empty(): return get_group_name()
	var lead_part: ModularCharacter.Part = type.parts[0]
	var part_name: String = ModularCharacter.Part.keys()[lead_part]
	if appearance:
		for part_mesh: EquipmentPartMesh in appearance.parts:
			if part_mesh and part_mesh.part == lead_part and part_mesh.male_mesh:
				return "%s %s" % [part_name.capitalize(), ModularBodyPart.get_mesh_number(part_mesh.male_mesh.resource_path)]
	return "No %s" % part_name.capitalize()

func get_group_name() -> StringName:
	return StringName(type.name) if type else &"Untyped"

func _get_configuration_warnings() -> PackedStringArray:
	# Equipment has no model variations of its own, so the [Profile] warnings do not apply
	var warnings: PackedStringArray = []
	if not type: warnings.append("Missing EquipmentType.")
	if not appearance: warnings.append("Missing EquipmentAppearance.")
	if not type or not appearance: return warnings
	for part_mesh: EquipmentPartMesh in appearance.parts:
		if not part_mesh:
			warnings.append("Empty EquipmentPartMesh entry.")
			continue
		var part_name: String = ModularCharacter.Part.keys()[part_mesh.part]
		if not type.parts.has(part_mesh.part): warnings.append("Part %s is not used by type %s." % [part_name, type.name])
		if not part_mesh.male_mesh: warnings.append("Part %s has no male mesh." % part_name)
	return warnings
