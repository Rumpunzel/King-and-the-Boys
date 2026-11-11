@tool
@icon("uid://cyrqlm5mdw05a")
class_name EquipmentCatalog
extends Resource

## The looks of one [EquipmentType]: mesh combinations stored inside this file, each with its combination key as ID,
## so [ResourceId] names them "uid://<catalog>::05_10" without a file per look
## Each look's [member EquipmentLook.allowed] flag records whether that combination is meant to be used

const CATALOG_DIRECTORY: String = EquipmentLook.ITEM_DIRECTORY + "/catalogs"

## Held so [method find_all] keeps finding loaded catalogs in the cache: an unreferenced one is freed and read from disk again
static var _held_catalogs: Array[EquipmentCatalog] = []

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
	_held_catalogs = catalogs
	return catalogs

## Stored resource IDs may only hold letters, digits and "_": "21-00 none" becomes "21x00_none"
static func get_look_id(combination_key: String) -> String:
	return combination_key.replace("-", "x").replace(" ", "_")

## The combination key a stored look is kept under, read back from its ID (see [method get_look_id]); mesh numbers are digits
static func get_key_of(look: EquipmentLook) -> String:
	return look.resource_scene_unique_id.replace("_", " ").replace("x", "-")

## The key of the first allowed look, or of the first look if none is allowed; empty for an empty catalog
func get_first_key() -> String:
	for look: EquipmentLook in looks:
		if look.allowed: return get_key_of(look)
	return get_key_of(looks.front() as EquipmentLook) if not looks.is_empty() else ""

## The numbers the [param link_index]th link takes among the looks that share [param combination_key]'s earlier numbers, in natural order
## So a base (link 0) offers every base, and an attachment only those stored with the shown base
func get_options(combination_key: String, link_index: int) -> PackedStringArray:
	var shown: PackedStringArray = combination_key.split(" ")
	var options: PackedStringArray = []
	for look: EquipmentLook in looks:
		var numbers: PackedStringArray = get_key_of(look).split(" ")
		if numbers.size() != shown.size() or options.has(numbers[link_index]): continue
		if numbers.slice(0, link_index) == shown.slice(0, link_index): options.append(numbers[link_index])
	var sorted: Array = Array(options)
	sorted.sort_custom(func(first: String, second: String) -> bool: return first.naturalnocasecmp_to(second) < 0)
	return PackedStringArray(sorted)

## The key one option further along the [param link_index]th link, wrapping around; later numbers stay where such a look exists,
## otherwise the first look with the new earlier numbers is taken, an allowed one if there is
func step(combination_key: String, link_index: int, direction: int) -> String:
	var options: PackedStringArray = get_options(combination_key, link_index)
	if options.is_empty(): return combination_key
	var numbers: PackedStringArray = combination_key.split(" ")
	numbers[link_index] = options[posmod(options.find(numbers[link_index]) + direction, options.size())]
	var stepped_key: String = " ".join(numbers)
	if get_look(stepped_key): return stepped_key
	var leading: PackedStringArray = numbers.slice(0, link_index + 1)
	var fallback: String = ""
	for look: EquipmentLook in looks:
		var look_key: String = get_key_of(look)
		if look_key.split(" ").slice(0, link_index + 1) != leading: continue
		if look.allowed: return look_key
		if fallback.is_empty(): fallback = look_key
	return fallback

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

## Adds every combination [param combinations] lists that this catalog lacks, allowed: most work, the odd ones are unchecked by hand
## @returns how many looks were added
func add_missing(combinations: EquipmentCombinations) -> int:
	assert(combinations.type == type)
	var shown_meshes: Dictionary[int, Mesh] = combinations.get_shown_meshes()
	var added: int = 0
	for combination: Dictionary in combinations.list():
		var combination_key: String = combination.key
		if get_look(combination_key): continue
		combinations.show(combination, shown_meshes)
		add(EquipmentLook.from_model(combinations.model, type), combination_key, true)
		added += 1
	combinations.show_meshes(shown_meshes)
	return added

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not type: warnings.append("Missing EquipmentType.")
	for look: EquipmentLook in looks:
		if look and look.type != type: warnings.append("%s is no %s." % [look.name, type.name if type else "look of this catalog's type"])
	return warnings
