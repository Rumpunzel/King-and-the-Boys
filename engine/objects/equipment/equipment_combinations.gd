class_name EquipmentCombinations
extends RefCounted

## Walks the mesh combinations of an [EquipmentType]'s parts on a [ModularCharacter]
## Linked parts (see [method EquipmentType.get_links]) form one dimension led by their first part: combinations use the leader's
## mesh numbers, and a partner lacking that number keeps the mesh it showed when the walk began
## Combinations are counted like an odometer; each is named by its key (see [method EquipmentType.get_combination_key])

## Walking more is refused; vary fewer parts instead
const MAX_COMBINATIONS: int = 5000

var type: EquipmentType
var model: ModularCharacter
## Parts the walk varies, all of the type's by default; the others keep their mesh
var varied_parts: Array[ModularCharacter.Part] = []

func _init(for_type: EquipmentType, on_model: ModularCharacter) -> void:
	type = for_type
	model = on_model
	varied_parts = for_type.parts.duplicate()

## @returns the trailing number of the mesh [param body_part] shows, such as [code]"05"[/code], or [constant ModularBodyPart.EMPTY_MESH_NUMBER] if it shows none
static func get_mesh_number(body_part: ModularBodyPart) -> String:
	if not body_part.visible or not body_part.mesh: return ModularBodyPart.EMPTY_MESH_NUMBER
	return ModularBodyPart.get_mesh_number(body_part.mesh.resource_path)

## @returns whether a key names only bare or no meshes, e.g. "00 00"
static func is_empty_key(combination_key: String) -> bool:
	for number: String in combination_key.replace("-", " ").split(" "):
		if number != ModularBodyPart.EMPTY_MESH_NUMBER: return false
	return true

## The key of what [member model] shows now
func get_shown_key() -> String:
	var part_numbers: Dictionary = {}
	for part: ModularCharacter.Part in type.parts: part_numbers[part] = get_mesh_number(model.get_part(part))
	return type.get_combination_key(part_numbers)

## Shows the mesh numbered [param mesh_number]; [constant ModularBodyPart.EMPTY_MESH_NUMBER] hides a part without such a mesh
## @returns [code]false[/code] if the part has no such mesh
func show_mesh_number(part: ModularCharacter.Part, mesh_number: String) -> bool:
	var body_part: ModularBodyPart = model.get_part(part)
	var mesh_index: int = body_part.find_mesh_index(mesh_number)
	if mesh_index < 0 and (mesh_number != ModularBodyPart.EMPTY_MESH_NUMBER or not body_part.allows_none()): return false
	body_part.update_index(mesh_index)
	return true

## Shows the combination [param combination_key] names; each linked group takes the first of its numbers each part has
## @returns [code]false[/code] if the key does not fit this type
func show_key(combination_key: String) -> bool:
	var links: Array[Array] = _get_links_in_key_order()
	var tokens: PackedStringArray = combination_key.split(" ")
	if tokens.size() != links.size(): return false
	for link_index: int in links.size():
		var numbers: PackedStringArray = tokens[link_index].split("-")
		for part: ModularCharacter.Part in links[link_index]:
			var shown: bool = false
			for mesh_number: String in numbers:
				if show_mesh_number(part, mesh_number):
					shown = true
					break
			if not shown: return false
	return true

## The links of [member type] in the order its keys list them
func _get_links_in_key_order() -> Array[Array]:
	var links: Array[Array] = []
	var keyed: Array[ModularCharacter.Part] = []
	for part: ModularCharacter.Part in type.parts:
		if keyed.has(part): continue
		var link: Array[ModularCharacter.Part] = type.get_link_of(part)
		keyed.append_array(link)
		links.append(link)
	return links

## The varied parts split into dimensions; linked varied parts form one, led by the first
func get_dimensions() -> Array[Array]:
	var dimensions: Array[Array] = []
	var assigned: Array[ModularCharacter.Part] = []
	for part: ModularCharacter.Part in type.parts:
		if assigned.has(part) or not varied_parts.has(part): continue
		var dimension: Array[ModularCharacter.Part] = []
		for linked_part: ModularCharacter.Part in type.get_link_of(part):
			if varied_parts.has(linked_part): dimension.append(linked_part)
		assigned.append_array(dimension)
		dimensions.append(dimension)
	return dimensions

## The leader's mesh numbers, plus [constant ModularBodyPart.EMPTY_MESH_NUMBER] for no mesh if it allows that
func get_options(dimension: Array) -> PackedStringArray:
	var leader: ModularCharacter.Part = dimension[0]
	var body_part: ModularBodyPart = model.get_part(leader)
	var options: PackedStringArray = body_part.get_mesh_numbers()
	if body_part.allows_none() and not options.has(ModularBodyPart.EMPTY_MESH_NUMBER): options.insert(0, ModularBodyPart.EMPTY_MESH_NUMBER)
	return options

## Counts up to [constant MAX_COMBINATIONS] + 1
func count() -> int:
	var total: int = 1
	for dimension: Array in get_dimensions():
		total *= get_options(dimension).size()
		if total > MAX_COMBINATIONS: return total
	return total

func get_shown_meshes() -> Dictionary[ModularCharacter.Part, Mesh]:
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = {}
	for part: ModularCharacter.Part in type.parts:
		var body_part: ModularBodyPart = model.get_part(part)
		shown_meshes[part] = body_part.mesh if body_part.visible else null
	return shown_meshes

func show_meshes(meshes: Dictionary[ModularCharacter.Part, Mesh]) -> void:
	for part: ModularCharacter.Part in meshes: model.get_part(part).apply_mesh(meshes[part] as ArrayMesh)

## Every non-empty combination of the varied parts as {counters: [Array] of [int], key: [String]}; shows what it showed before afterwards
## @returns an empty list if there are more than [constant MAX_COMBINATIONS]
func list() -> Array[Dictionary]:
	var combinations: Array[Dictionary] = []
	if count() > MAX_COMBINATIONS: return combinations
	var dimensions: Array[Array] = get_dimensions()
	var options: Array[Array] = []
	for dimension: Array in dimensions: options.append(Array(get_options(dimension)))
	var shown_meshes: Dictionary[ModularCharacter.Part, Mesh] = get_shown_meshes()
	var counters: Array[int] = []
	counters.resize(dimensions.size())
	counters.fill(0)
	while true:
		if _apply(dimensions, options, counters, shown_meshes):
			var combination_key: String = get_shown_key()
			if not is_empty_key(combination_key): combinations.append({counters = counters.duplicate(), key = combination_key})
		if not _advance(options, counters): break
	show_meshes(shown_meshes)
	return combinations

## Shows one combination from [method list], walked from the same shown meshes
func show(combination: Dictionary, fallback_meshes: Dictionary[ModularCharacter.Part, Mesh]) -> void:
	var dimensions: Array[Array] = get_dimensions()
	var options: Array[Array] = []
	for dimension: Array in dimensions: options.append(Array(get_options(dimension)))
	var counters: Array[int] = []
	counters.assign(combination.counters as Array)
	_apply(dimensions, options, counters, fallback_meshes)

## @returns [code]false[/code] if a leader cannot show its option
func _apply(dimensions: Array[Array], options: Array[Array], counters: Array[int], fallback_meshes: Dictionary[ModularCharacter.Part, Mesh]) -> bool:
	for dimension_index: int in dimensions.size():
		var mesh_number: String = options[dimension_index][counters[dimension_index]]
		var dimension: Array = dimensions[dimension_index]
		for part_index: int in dimension.size():
			var part: ModularCharacter.Part = dimension[part_index]
			if show_mesh_number(part, mesh_number): continue
			if part_index == 0: return false
			if fallback_meshes.has(part): model.get_part(part).apply_mesh(fallback_meshes[part] as ArrayMesh)
	return true

## @returns [code]false[/code] once every combination was visited
static func _advance(options: Array[Array], counters: Array[int]) -> bool:
	for dimension_index: int in counters.size():
		counters[dimension_index] += 1
		if counters[dimension_index] < options[dimension_index].size(): return true
		counters[dimension_index] = 0
	return false
