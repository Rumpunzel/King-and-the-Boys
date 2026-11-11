@tool
@icon("uid://bbqobur2kwwup")
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

## Decides the body it fits, the slot, the parts this item may set and the slots it blocks
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
## Deliberately emits no [signal Resource.changed]: the look still looks the same, and previews rebuild on that signal
@export var allowed: bool = true

var slot: Slot:
	get:
		assert(type, "EquipmentLook %s has no EquipmentType!" % resource_path)
		return type.slot if type else Slot.HEAD
var blocked_slots: Array[Slot]:
	get: return type.blocked_slots if type else [] as Array[Slot]

## Captures what [param model] currently shows in the parts of [param for_type] as a new item
## Gendered meshes get their other-gender counterpart if one exists with the same number
static func from_model(model: ModularModel, for_type: EquipmentType) -> EquipmentLook:
	var equipment_look: EquipmentLook = EquipmentLook.new()
	equipment_look.type = for_type
	equipment_look.appearance = EquipmentAppearance.new()
	var parts: Array[EquipmentPartMesh] = []
	for part: int in for_type.parts:
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

## The male mesh [param part] shows in this look, or [code]null[/code] where it shows none
func get_part_mesh(part: int) -> ArrayMesh:
	if not appearance: return null
	for part_mesh: EquipmentPartMesh in appearance.parts:
		if part_mesh and part_mesh.part == part: return part_mesh.male_mesh
	return null

## A copy for its owner to store, e.g. a character's starting look, so it can change without touching this one; meshes and type stay shared
func make_local() -> EquipmentLook:
	return duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as EquipmentLook

## A local copy showing [param male_mesh] on [param part] (none if [code]null[/code]) with its other-gender twin, named after what it shows
func with_part_mesh(part: int, male_mesh: ArrayMesh) -> EquipmentLook:
	var copy: EquipmentLook = make_local()
	if not copy.appearance: copy.appearance = EquipmentAppearance.new()
	var parts: Array[EquipmentPartMesh] = []
	for part_mesh: EquipmentPartMesh in copy.appearance.parts:
		if part_mesh and part_mesh.part != part: parts.append(part_mesh)
	if male_mesh:
		var part_mesh: EquipmentPartMesh = EquipmentPartMesh.new()
		part_mesh.part = part
		part_mesh.male_mesh = male_mesh
		part_mesh.female_mesh = _find_other_gender_mesh(male_mesh, ModularBodyPartGendered.Gender.MALE)
		parts.append(part_mesh)
	parts.sort_custom(func(first: EquipmentPartMesh, second: EquipmentPartMesh) -> bool: return type.parts.find(first.part) < type.parts.find(second.part))
	copy.appearance.parts = parts
	copy.name = type.get_combination_name(type.get_combination_key_of(copy))
	return copy

## @returns every part equipping or unequipping this item resets: all parts of its slot and of the slots it blocks
func get_reset_parts() -> Array[int]: return type.get_reset_parts() if type else [] as Array[int]

## Previews, such as Menagerie, show the item on a plain model of its type
func create_model(_variation: int) -> Model:
	if not type or not type.model: return null
	var model: ModularModel = type.model.instantiate() as ModularModel
	if not model: return null
	model.reset_gear()
	if appearance: appearance.configure(model)
	return model

func get_variation_count() -> int: return 1
func get_random_variation() -> int: return 0

## The look's mesh for its type's first part, e.g. "Torso 05"; looks of one base are variations of each other
func get_base_name() -> String:
	if not type or type.parts.is_empty(): return get_group_name()
	var lead_part: int = type.parts[0]
	var part_name: String = type.get_part_key(lead_part)
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
		var part_name: String = type.get_part_key(part_mesh.part)
		if not type.parts.has(part_mesh.part): warnings.append("Part %s is not used by type %s." % [part_name, type.name])
		if not part_mesh.male_mesh: warnings.append("Part %s has no male mesh." % part_name)
	return warnings
