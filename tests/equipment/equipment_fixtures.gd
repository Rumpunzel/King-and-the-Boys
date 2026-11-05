## Builds equipment for tests from committed meshes and types only, so suites also run in CI
class_name EquipmentFixtures
extends RefCounted

const MESHES: String = "res://data/characters/people/meshes/gear"
const HELMET_ATTACHMENT: String = MESHES + "/helmet_attachment/modular_character_HelmetAttachment_02.res"
const MASK: String = MESHES + "/head_coverings_no_facial_hair/modular_character_HeadCoverings_No_FacialHair_02.res"
const HAT: String = MESHES + "/head_coverings_base_hair/modular_character_HeadCoverings_Base_Hair_01.res"
const HOOD: String = MESHES + "/head_coverings_no_hair/modular_character_HeadCoverings_No_Hair_01.res"
const TORSO_MALE: String = MESHES + "/male/torso/modular_character_Torso_Male_03.res"
const TORSO_FEMALE: String = MESHES + "/female/torso/modular_character_Torso_Female_03.res"
const HIPS_MALE: String = MESHES + "/male/hips/modular_character_Hips_Male_03.res"
const BELT: String = MESHES + "/hips_attachment/modular_character_HipsAttachment_02.res"
const CAPE: String = MESHES + "/back_attachment/modular_character_BackAttachment_01.res"

const TYPES: String = "res://data/equipment/types"
const MODULAR_CHARACTER: String = "res://data/characters/people/modular_character.tscn"
const CHARACTER: String = "uid://cvj6b1m2b65hd"
const KNIGHT: String = "res://data/characters/people/knight.tres"
## Saved test items live here, as peers may only request items below [constant EquipmentProfile.ITEM_DIRECTORY]
const SAVED_ITEMS: String = EquipmentProfile.ITEM_DIRECTORY + "/__tests__"

static func load_type(type_name: String) -> EquipmentType:
	return load("%s/%s.tres" % [TYPES, type_name])

## A type that may set every part of [param slot] and of [param blocked_slots]
static func make_type(slot: EquipmentProfile.Slot, blocked_slots: Array[EquipmentProfile.Slot] = []) -> EquipmentType:
	var equipment_type: EquipmentType = EquipmentType.new()
	equipment_type.name = "Test %s" % EquipmentProfile.Slot.keys()[slot]
	equipment_type.slot = slot
	equipment_type.parts = EquipmentProfile.get_parts_for(slot, blocked_slots)
	equipment_type.blocked_slots = blocked_slots
	return equipment_type

static func make_item(equipment_type: EquipmentType, part: ModularCharacter.Part, male_mesh_path: String, female_mesh_path: String = "") -> EquipmentProfile:
	var part_mesh: EquipmentPartMesh = EquipmentPartMesh.new()
	part_mesh.part = part
	part_mesh.male_mesh = load(male_mesh_path) if not male_mesh_path.is_empty() else null
	if not female_mesh_path.is_empty(): part_mesh.female_mesh = load(female_mesh_path)
	var item: EquipmentProfile = EquipmentProfile.new()
	item.name = "Test %s" % ModularCharacter.Part.keys()[part]
	item.type = equipment_type
	item.appearance = EquipmentAppearance.new()
	item.appearance.parts = [part_mesh]
	return item

static var _saved_count: int = 0

## Saves [param item] as its own file, as synchronization and starting slots refer to saved items
## Each call gets a file of its own, so a reloaded item is never a stale cached copy
static func save_item(item: EquipmentProfile, file_name: String) -> EquipmentProfile:
	DirAccess.make_dir_recursive_absolute(SAVED_ITEMS)
	_saved_count += 1
	var path: String = SAVED_ITEMS.path_join("%d_%s" % [_saved_count, file_name])
	assert(ResourceSaver.save(item, path) == OK)
	return load(path)

static func remove_saved_items() -> void:
	if not DirAccess.dir_exists_absolute(SAVED_ITEMS): return
	for file_name: String in DirAccess.get_files_at(SAVED_ITEMS): DirAccess.remove_absolute(SAVED_ITEMS.path_join(file_name))
	DirAccess.remove_absolute(SAVED_ITEMS)

static func make_model() -> ModularCharacter:
	var scene: PackedScene = load(MODULAR_CHARACTER)
	var model: ModularCharacter = scene.instantiate()
	model.reset_gear()
	return model

## Empties every starting equipment slot; the profile is cached, so restore it with [method restore_starting_equipment]
static func clear_starting_equipment(profile: CharacterProfile) -> Dictionary:
	var original: Dictionary = {}
	for slot: EquipmentProfile.Slot in EquipmentProfile.Slot.values():
		original[slot] = profile.get_starting_equipment_for(slot)
		profile.set_starting_equipment_for(slot, null)
	return original

static func restore_starting_equipment(profile: CharacterProfile, original: Dictionary) -> void:
	for slot: EquipmentProfile.Slot in original: profile.set_starting_equipment_for(slot, original[slot] as EquipmentProfile)

static func mesh_path(body_part: ModularBodyPart) -> String:
	return body_part.mesh.resource_path if body_part.visible and body_part.mesh else ""
