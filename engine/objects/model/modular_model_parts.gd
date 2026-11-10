class_name ModularModelParts
extends RefCounted

## What a [ModularModel] scene offers equipment, read once from a plain instance: its part names, the parts each slot owns
## and the meshes each part can show. Types, catalogs and the inspector ask this instead of building a model each time

## {scene path: [String] -> [ModularModelParts]}
static var _cache: Dictionary[String, ModularModelParts] = {}

var part_keys: PackedStringArray = []
## {Slot: [enum EquipmentLook.Slot] -> parts: [Array] of [int]}
var slot_parts: Dictionary[EquipmentLook.Slot, Array] = {}
## {part: [int] -> mesh files: [PackedStringArray]}, an empty path first where the part may show none
var mesh_options: Dictionary[int, PackedStringArray] = {}
## The parts no slot owns, see [method ModularModel.get_body_parts]
var body_parts: Array[int] = []

## @returns the parts of [param scene], or [code]null[/code] if it is no [ModularModel]
static func of(scene: PackedScene) -> ModularModelParts:
	if not scene: return null
	if _cache.has(scene.resource_path): return _cache[scene.resource_path]
	var instance: Node = scene.instantiate()
	var model: ModularModel = instance as ModularModel
	if not model:
		instance.free()
		return null
	var model_parts: ModularModelParts = ModularModelParts.new()
	model_parts.part_keys = model.get_part_keys()
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values(): model_parts.slot_parts[slot] = model.get_slot_parts(slot)
	model_parts.body_parts = model.get_body_parts()
	for part: int in model_parts.part_keys.size():
		var body_part: ModularBodyPart = model.get_part(part)
		var options: PackedStringArray = [""] if body_part.allows_none() else []
		options.append_array(body_part.get_mesh_paths())
		model_parts.mesh_options[part] = options
	model.free()
	if not scene.resource_path.is_empty(): _cache[scene.resource_path] = model_parts
	return model_parts

## e.g. "SHOULDER_ATTACH_LEFT", or the number for a part this model lacks
func get_part_key(part: int) -> String:
	return part_keys[part] if part >= 0 and part < part_keys.size() else str(part)

func get_slot_parts(slot: EquipmentLook.Slot) -> Array[int]:
	var parts: Array[int] = []
	parts.assign(slot_parts.get(slot, []) as Array)
	return parts

func get_mesh_options(part: int) -> PackedStringArray:
	return mesh_options.get(part, PackedStringArray())

## @returns the right counterpart of a part named [code]..._LEFT[/code], or [code]-1[/code]
func get_right_partner(part: int) -> int:
	var part_key: String = get_part_key(part)
	if not part_key.ends_with("_LEFT"): return -1
	return part_keys.find(part_key.trim_suffix("_LEFT") + "_RIGHT")

## @returns the parts no slot owns, such as hair, as [method ModularModel.get_body_parts] gave them
func get_body_parts() -> Array[int]:
	return body_parts.duplicate()

## The numbers [param part] can show, in number order, [constant ModularBodyPart.EMPTY_MESH_NUMBER] first where it may show none
func get_mesh_numbers(part: int) -> PackedStringArray:
	var numbers: PackedStringArray = []
	for mesh_path: String in get_mesh_options(part): numbers.append(ModularBodyPart.EMPTY_MESH_NUMBER if mesh_path.is_empty() else ModularBodyPart.get_mesh_number(mesh_path))
	return numbers
