@tool
class_name EquipmentCatalog
extends Resource

## The combinations of one [EquipmentType] that are allowed as items, and the ones decided against
## Allowed combinations are [EquipmentProfile]s stored inside this file, each with its combination key as ID,
## so [ResourceId] names them "uid://<catalog>::05_10" without a file per item

enum Status {
	UNREVIEWED,
	ALLOWED,
	DENIED,
}

const CATALOG_DIRECTORY: String = EquipmentProfile.ITEM_DIRECTORY + "/catalogs"

@export var type: EquipmentType:
	set(new_value):
		type = new_value
		changed.emit()
@export var entries: Array[EquipmentProfile]:
	set(new_value):
		entries = new_value
		changed.emit()
## Combination keys decided against; kept so a decision is documented and not asked again
@export var denied: PackedStringArray:
	set(new_value):
		denied = new_value
		changed.emit()

## @returns the saved catalog of [param for_type], or [code]null[/code] if there is none yet
static func find_for(for_type: EquipmentType) -> EquipmentCatalog:
	if not for_type or not DirAccess.dir_exists_absolute(CATALOG_DIRECTORY): return null
	for file_name: String in DirAccess.get_files_at(CATALOG_DIRECTORY):
		if file_name.get_extension() != "tres": continue
		var catalog: EquipmentCatalog = load(CATALOG_DIRECTORY.path_join(file_name)) as EquipmentCatalog
		if catalog and catalog.type == for_type: return catalog
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
static func get_entry_id(combination_key: String) -> String:
	return combination_key.replace("-", "x").replace(" ", "_")

func get_default_path() -> String:
	return CATALOG_DIRECTORY.path_join("%s.tres" % type.name.to_snake_case())

func get_entry(combination_key: String) -> EquipmentProfile:
	var entry_id: String = get_entry_id(combination_key)
	for entry: EquipmentProfile in entries:
		if entry and entry.resource_scene_unique_id == entry_id: return entry
	return null

func get_status(combination_key: String) -> Status:
	if get_entry(combination_key): return Status.ALLOWED
	if denied.has(combination_key): return Status.DENIED
	return Status.UNREVIEWED

## Adds [param entry] as the item for [param combination_key], replacing an earlier one and any denial
func allow(entry: EquipmentProfile, combination_key: String) -> void:
	assert(entry.type == type, "%s is no %s" % [entry.name, type.name])
	_remove_entry(combination_key)
	_remove_denial(combination_key)
	entry.resource_scene_unique_id = get_entry_id(combination_key)
	if entry.name.is_empty(): entry.name = type.get_combination_name(combination_key)
	entries.append(entry)
	changed.emit()

func deny(combination_key: String) -> void:
	_remove_entry(combination_key)
	if not denied.has(combination_key):
		denied.append(combination_key)
		denied.sort()
	changed.emit()

## Forgets any decision, so [param combination_key] is unreviewed again
func undecide(combination_key: String) -> void:
	_remove_entry(combination_key)
	_remove_denial(combination_key)
	changed.emit()

func _remove_entry(combination_key: String) -> void:
	var entry: EquipmentProfile = get_entry(combination_key)
	if entry: entries.erase(entry)

func _remove_denial(combination_key: String) -> void:
	var denied_index: int = denied.find(combination_key)
	if denied_index >= 0: denied.remove_at(denied_index)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not type: warnings.append("Missing EquipmentType.")
	for entry: EquipmentProfile in entries:
		if entry and entry.type != type: warnings.append("%s is no %s." % [entry.name, type.name if type else "item of this catalog's type"])
	return warnings
