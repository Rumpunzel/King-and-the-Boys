@tool
@abstract
class_name ModularModel
extends Model

## A [Model] built from [ModularBodyPart]s, dressed part by part by equipment. Each kind of body (see [ModularCharacter],
## [DwarfCharacter]) names its parts in its own [code]Part[/code] enum and decides which of them each [enum EquipmentLook.Slot] owns
## Parts no slot owns make up the body (hair, faces), rolled per character instead of equipped

@export_tool_button("Randomize Body", "RandomNumberGenerator") var randomize_body_action: Callable = randomize_body
@export_tool_button("Randomize Gear", "AudioStreamRandomizer") var randomize_gear_action: Callable = randomize_gear
@export_tool_button("Reset Gear", "Clear") var reset_gear_action: Callable = reset_gear

## The names of this body's parts, i.e. the keys of its [code]Part[/code] enum; part numbers index into them
@abstract func get_part_keys() -> PackedStringArray

## @returns the parts [param slot] owns and resets on equip
@abstract func get_slot_parts(slot: EquipmentLook.Slot) -> Array[int]

## Every body part export is named like its part in lower case
func get_part(part: int) -> ModularBodyPart:
	var part_name: String = get_part_keys()[part]
	var body_part: ModularBodyPart = get(part_name.to_lower())
	assert(body_part, "Part %s not implemented!" % part_name)
	return body_part

func has_part(part: int) -> bool: return part >= 0 and part < get_part_keys().size()

## Shows a rolled body (see [method ModelConfigurationRandom.roll]); an entry that does not fit (see [method fits_part]) is skipped,
## e.g. from a save made when the profile still used another body
## @param body {part: [int] -> mesh [ResourceId]: [String]}, an empty ID meaning no mesh
func apply_body(body: Dictionary) -> void:
	for part: Variant in body:
		if not part is int or not body[part] is String or not fits_part(part as int, body[part] as String):
			push_warning("%s does not fit part %s of %s; skipped." % [body[part], part, scene_file_path])
			continue
		get_part(part as int).apply_mesh(ResourceId.find(body[part] as String) as ArrayMesh)

## Whether [param body] names a mesh for exactly this body's body parts (see [method get_body_parts]), each fitting its part, e.g. a
## body a peer rolled in the lobby
func is_complete_body(body: Dictionary) -> bool:
	if body.size() != get_body_parts().size(): return false
	for part: int in get_body_parts():
		if not body.get(part) is String or not fits_part(part, body[part] as String): return false
	return true

## Whether [param mesh_id] names one of [param part]'s own meshes, or none where the part may show none; checked by file path, so
## IDs from peers are never loaded unless they fit
func fits_part(part: int, mesh_id: String) -> bool:
	if not has_part(part): return false
	var body_part: ModularBodyPart = get_part(part)
	if mesh_id.is_empty(): return body_part.allows_none()
	return body_part.get_mesh_paths().has(ResourceId.get_file_path(mesh_id))

## @returns every part some slot owns
func get_gear_parts() -> Array[int]:
	var gear_parts: Array[int] = []
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		for part: int in get_slot_parts(slot):
			if not gear_parts.has(part): gear_parts.append(part)
	return gear_parts

## @returns the parts no slot owns, such as hair
func get_body_parts() -> Array[int]:
	var gear_parts: Array[int] = get_gear_parts()
	var body_parts: Array[int] = []
	for part: int in get_part_keys().size():
		if not gear_parts.has(part): body_parts.append(part)
	return body_parts

## What the body parts show, e.g. "Head 03 · Eyebrow 07 · Hair 12" (also where gear hides them); parts without a mesh read "none"
func describe_body() -> String:
	var shown: PackedStringArray = []
	var part_keys: PackedStringArray = get_part_keys()
	for part: int in get_body_parts():
		var body_part: ModularBodyPart = get_part(part)
		var showing: bool = body_part.mesh != null
		shown.append("%s %s" % [part_keys[part].capitalize(), ModularBodyPart.get_mesh_number(body_part.mesh.resource_path) if showing else "none"])
	return " · ".join(shown)

func randomize_body() -> void:
	for part: int in get_body_parts(): get_part(part).random_mesh()

func randomize_gear() -> void:
	for part: int in get_gear_parts(): get_part(part).random_mesh()

func reset() -> void:
	for part: int in get_part_keys().size(): get_part(part).reset_mesh()

func reset_gear() -> void:
	for part: int in get_gear_parts(): get_part(part).reset_mesh()
