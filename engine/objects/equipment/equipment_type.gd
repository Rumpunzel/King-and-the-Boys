@tool
class_name EquipmentType
extends Resource

## A kind of item, such as a helmet or a hood: which body it fits, where it goes, which parts it shows and what it covers

const DIRECTORY: String = "res://data/equipment/types"

@export var name: String:
	set(new_value):
		name = new_value
		changed.emit()
@export var icon: Texture2D:
	set(new_value):
		icon = new_value
		changed.emit()
## The [ModularModel] scene items of this type dress, e.g. the human or the dwarf; [member parts] are numbers of its [code]Part[/code] enum
@export var model: PackedScene:
	set(new_value):
		model = new_value
		notify_property_list_changed()
		changed.emit()
@export var slot: EquipmentLook.Slot = EquipmentLook.Slot.HEAD:
	set(new_value):
		slot = new_value
		changed.emit()
## The parts items of this type set; each must belong to [member slot] or to one of [member blocked_slots]
@export var parts: Array[int]:
	set(new_value):
		parts = new_value
		changed.emit()
## Parts that change together and share a mesh number; left and right parts are linked even without a group
@export var part_groups: Array[EquipmentPartGroup]:
	set(new_value):
		for part_group: EquipmentPartGroup in part_groups:
			if part_group and part_group.changed.is_connected(changed.emit): part_group.changed.disconnect(changed.emit)
		part_groups = new_value
		for part_group: EquipmentPartGroup in part_groups:
			if part_group and not part_group.changed.is_connected(changed.emit): part_group.changed.connect(changed.emit)
		changed.emit()
## Slots emptied while an item of this type is equipped, such as a full helmet blocking [constant EquipmentLook.FACE]
@export var blocked_slots: Array[EquipmentLook.Slot]:
	set(new_value):
		blocked_slots = new_value
		changed.emit()

## @returns every saved type
static func find_all() -> Array[EquipmentType]:
	var types: Array[EquipmentType] = []
	if not DirAccess.dir_exists_absolute(DIRECTORY): return types
	for file_name: String in DirAccess.get_files_at(DIRECTORY):
		if file_name.get_extension() != "tres": continue
		var equipment_type: EquipmentType = load(DIRECTORY.path_join(file_name)) as EquipmentType
		if equipment_type: types.append(equipment_type)
	return types

## What [member model] offers, or [code]null[/code] without one
func get_model_parts() -> ModularModelParts: return ModularModelParts.of(model)

## Whether items of this type can dress [param on_model], i.e. it was made from [member model]
func fits(on_model: ModularModel) -> bool:
	return model != null and on_model != null and on_model.scene_file_path == model.resource_path

## The name of [param part] in [member model]'s [code]Part[/code] enum, e.g. "SHOULDER_ATTACH_LEFT"
func get_part_key(part: int) -> String:
	var model_parts: ModularModelParts = get_model_parts()
	return model_parts.get_part_key(part) if model_parts else str(part)

## The mesh files [param part] can show (the male ones of gendered parts), in number order; an empty path first where it may show none
func get_mesh_options(part: int) -> PackedStringArray:
	var model_parts: ModularModelParts = get_model_parts()
	return model_parts.get_mesh_options(part) if model_parts else PackedStringArray()

## @returns the parts of [member model] that [param for_slot] owns
func get_slot_parts(for_slot: EquipmentLook.Slot) -> Array[int]:
	var model_parts: ModularModelParts = get_model_parts()
	return model_parts.get_slot_parts(for_slot) if model_parts else [] as Array[int]

## @returns every part equipping or unequipping an item of this type resets: all parts of its slot and of the slots it blocks
func get_reset_parts() -> Array[int]:
	var reset_parts: Array[int] = get_slot_parts(slot)
	for blocked_slot: EquipmentLook.Slot in blocked_slots:
		if blocked_slot != slot: reset_parts.append_array(get_slot_parts(blocked_slot))
	return reset_parts

## The right counterpart of a left part among [member parts], or [code]-1[/code]
func get_right_partner(part: int) -> int:
	var model_parts: ModularModelParts = get_model_parts()
	var partner: int = model_parts.get_right_partner(part) if model_parts else -1
	return partner if parts.has(partner) else -1

## The linked parts in the order keys list them: one entry per number of [method get_combination_key], led by its first part
func get_key_links() -> Array[Array]:
	var links: Array[Array] = []
	var keyed: Array[int] = []
	for part: int in parts:
		if keyed.has(part): continue
		var link: Array[int] = get_link_of(part)
		keyed.append_array(link)
		links.append(link)
	return links

## One mesh number per linked group of parts, e.g. "05 03"; linked parts with different numbers are joined, e.g. "05-07"
## @param part_numbers {part: [int] -> mesh number: [String]}; missing parts count as "none"
func get_combination_key(part_numbers: Dictionary) -> String:
	var numbers: PackedStringArray = []
	for link: Array in get_key_links():
		var link_numbers: PackedStringArray = []
		for linked_part: int in link:
			var mesh_number: String = part_numbers.get(linked_part, ModularBodyPart.EMPTY_MESH_NUMBER)
			if not link_numbers.has(mesh_number): link_numbers.append(mesh_number)
		numbers.append("-".join(link_numbers))
	return " ".join(numbers)

## The key of the combination an existing item shows, independent of its file or display name
func get_combination_key_of(equipment_look: EquipmentLook) -> String:
	var part_numbers: Dictionary = {}
	for part_mesh: EquipmentPartMesh in equipment_look.appearance.parts:
		if part_mesh and part_mesh.male_mesh: part_numbers[part_mesh.part] = ModularBodyPart.get_mesh_number(part_mesh.male_mesh.resource_path)
	return get_combination_key(part_numbers)

## The display name for a combination, e.g. "Gloves 05 03"
func get_combination_name(combination_key: String) -> String:
	return "%s %s" % [name, combination_key]

## @returns the linked parts: each [member part_groups] entry, plus left/right pairs not already grouped
func get_links() -> Array[Array]:
	var links: Array[Array] = []
	var grouped: Array[int] = []
	for part_group: EquipmentPartGroup in part_groups:
		if not part_group: continue
		var link: Array[int] = []
		for part: int in part_group.parts:
			if parts.has(part) and not grouped.has(part): link.append(part)
		if link.size() < 2: continue
		links.append(link)
		grouped.append_array(link)
	for part: int in parts:
		var right_part: int = get_right_partner(part)
		if right_part < 0 or grouped.has(part) or grouped.has(right_part): continue
		var pair: Array[int] = [part, right_part]
		links.append(pair)
	return links

## @returns the parts linked with [param part], including itself
func get_link_of(part: int) -> Array[int]:
	for link: Array in get_links():
		if link.has(part):
			var typed_link: Array[int] = []
			typed_link.assign(link)
			return typed_link
	return [part]

## Lists [member parts] by the names of [member model]'s parts
func _validate_property(property: Dictionary) -> void:
	if property.name != "parts": return
	var model_parts: ModularModelParts = get_model_parts()
	if not model_parts: return
	property.hint = PROPERTY_HINT_TYPE_STRING
	property.hint_string = "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, ",".join(model_parts.part_keys)]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var slot_name: String = EquipmentLook.Slot.keys()[slot]
	if name.is_empty(): warnings.append("Missing name.")
	if not model: warnings.append("Missing model.")
	elif not get_model_parts(): warnings.append("Model %s is no ModularModel." % model.resource_path)
	if parts.is_empty() and get_slot_parts(slot).size() > 0: warnings.append("No parts selected.")
	if blocked_slots.has(slot): warnings.append("Slot %s blocks itself." % slot_name)
	var possible_parts: Array[int] = get_reset_parts()
	for part: int in parts:
		if not possible_parts.has(part): warnings.append("Part %s is neither owned by slot %s nor by a blocked slot." % [get_part_key(part), slot_name])
	var grouped: Array[int] = []
	for part_group: EquipmentPartGroup in part_groups:
		if not part_group: continue
		for part: int in part_group.parts:
			if not parts.has(part): warnings.append("Grouped part %s is not one of this type's parts." % get_part_key(part))
			if grouped.has(part): warnings.append("Part %s is in more than one group." % get_part_key(part))
			grouped.append(part)
	return warnings
