@tool
class_name EquipmentCatalog
extends Resource

## The looks of one [EquipmentType]: mesh combinations stored inside this file, each with its combination key as ID,
## so [ResourceId] names them "uid://<catalog>::05_10" without a file per look
## Each look's [member EquipmentLook.allowed] flag records whether that combination is meant to be used

const CATALOG_DIRECTORY: String = EquipmentLook.ITEM_DIRECTORY + "/catalogs"

@export var type: EquipmentType:
	set(new_value):
		type = new_value
		changed.emit()
@export var looks: Array[EquipmentLook]:
	set(new_value):
		looks = new_value
		changed.emit()

## @returns the saved catalog of [param for_type], or [code]null[/code] if there is none yet
static func find_for(for_type: EquipmentType) -> EquipmentCatalog:
	if not for_type: return null
	for catalog: EquipmentCatalog in find_all():
		if catalog.type == for_type: return catalog
	return null

## @returns the saved catalog of [param for_type], or a new one to be saved at [method get_default_path]
static func find_or_create(for_type: EquipmentType) -> EquipmentCatalog:
	var catalog: EquipmentCatalog = find_for(for_type)
	if catalog: return catalog
	catalog = EquipmentCatalog.new()
	catalog.type = for_type
	return catalog

## @returns every saved catalog
static func find_all() -> Array[EquipmentCatalog]:
	var catalogs: Array[EquipmentCatalog] = []
	if not DirAccess.dir_exists_absolute(CATALOG_DIRECTORY): return catalogs
	for file_name: String in DirAccess.get_files_at(CATALOG_DIRECTORY):
		if file_name.get_extension() != "tres": continue
		var catalog: EquipmentCatalog = load(CATALOG_DIRECTORY.path_join(file_name)) as EquipmentCatalog
		if catalog: catalogs.append(catalog)
	return catalogs

## Stored resource IDs may only hold letters, digits and "_": "21-00 none" becomes "21x00_none"
static func get_look_id(combination_key: String) -> String:
	return combination_key.replace("-", "x").replace(" ", "_")

func get_default_path() -> String:
	return CATALOG_DIRECTORY.path_join("%s.tres" % type.name.to_snake_case())

func get_look(combination_key: String) -> EquipmentLook:
	var look_id: String = get_look_id(combination_key)
	for look: EquipmentLook in looks:
		if look and look.resource_scene_unique_id == look_id: return look
	return null

func get_allowed_looks() -> Array[EquipmentLook]:
	return looks.filter(func(look: EquipmentLook) -> bool: return look and look.allowed)

## Adds [param look] for [param combination_key], replacing an earlier look of that key
func add(look: EquipmentLook, combination_key: String, allowed: bool) -> void:
	assert(look.type == type, "%s is no %s" % [look.name, type.name])
	var earlier: EquipmentLook = get_look(combination_key)
	if earlier: looks.erase(earlier)
	look.resource_scene_unique_id = get_look_id(combination_key)
	if look.name.is_empty(): look.name = type.get_combination_name(combination_key)
	look.allowed = allowed
	looks.append(look)
	changed.emit()

## Adds every combination [param combinations] lists that this catalog lacks, as not allowed, so nothing new slips in unseen
## @returns how many looks were added
func add_missing(combinations: EquipmentCombinations) -> int:
	assert(combinations.type == type)
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = combinations.get_shown_meshes()
	var added: int = 0
	for combination: Dictionary in combinations.list():
		var combination_key: String = combination.key
		if get_look(combination_key): continue
		combinations.show(combination, shown_meshes)
		add(EquipmentLook.from_model(combinations.model, type), combination_key, false)
		added += 1
	combinations.show_meshes(shown_meshes)
	return added

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not type: warnings.append("Missing EquipmentType.")
	for look: EquipmentLook in looks:
		if look and look.type != type: warnings.append("%s is no %s." % [look.name, type.name if type else "look of this catalog's type"])
	return warnings
