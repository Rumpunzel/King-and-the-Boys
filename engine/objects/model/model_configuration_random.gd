@tool
@icon("uid://dvhm0wfa1qty8")
class_name ModelConfigurationRandom
extends ModelConfiguration

## Rolls a body: every body part (the parts no slot owns, see [method ModularModel.get_body_parts]) named in
## [member randomized_parts] gets a random mesh, from its pool in [member mesh_pools] if it has one; the others their default

## Names of the model's parts, e.g. "HAIR" or "FACIAL_HAIR"; parts a body lacks are ignored, so one configuration can serve several
@export var randomized_parts: PackedStringArray = []:
	set(new_value):
		randomized_parts = new_value
		changed.emit()
## The meshes a randomized part rolls from, by part name: mesh numbers, e.g. [code]{"FACIAL_HAIR": ["00", "03", "07"]}[/code], where
## [code]"00"[/code] shows none (for parts that may show none). Parts without a pool roll from all their meshes; pools of parts that are
## not randomized are kept, but unused
@export var mesh_pools: Dictionary[String, PackedStringArray] = {}:
	set(new_value):
		mesh_pools = new_value
		changed.emit()

## The body's gender, e.g. a female hero; bodies without gendered parts (dwarves) ignore it. Fixed, not rolled, so every peer builds
## the same body before the rolled meshes arrive (see [method CharacterProfile.create_model]), and the pools are of this gender's meshes
@export var gender: ModularBodyPartGendered.Gender = ModularBodyPartGendered.Gender.MALE:
	set(new_value):
		gender = new_value
		changed.emit()

## The skin colours a body rolls from (stubble and lips follow), see [method ModularModel.set_body_colors]; none keeps the atlas' own
@export var skin_colors: PackedColorArray = []:
	set(new_value):
		skin_colors = new_value
		changed.emit()
## The hair colours a body rolls from (eyebrows and beards too); none keeps the atlas' own
@export var hair_colors: PackedColorArray = []:
	set(new_value):
		hair_colors = new_value
		changed.emit()

func configure(model: ModularModel) -> void:
	model.set_gender(gender)
	var part_keys: PackedStringArray = model.get_part_keys()
	for part: int in model.get_body_parts():
		var body_part: ModularBodyPart = model.get_part(part)
		if not randomized_parts.has(part_keys[part]): body_part.reset_mesh()
		elif mesh_pools.has(part_keys[part]): _roll_from_pool(body_part, part_keys[part])
		else: body_part.random_mesh()
	model.set_body_colors(_roll_color(skin_colors), _roll_color(hair_colors))

## Randomizes [param model] and returns the result as mesh [ResourceId]s, so peers can apply the exact same look
## @returns {part: [int] -> mesh ID: [String]}, an empty ID meaning no mesh, plus the rolled colours (see
## [constant ModularModel.BODY_SKIN_COLOR]) where this configuration has any
func roll(model: ModularModel) -> Dictionary:
	configure(model)
	var body: Dictionary = {}
	for part: int in model.get_body_parts(): body[part] = ResourceId.of(model.get_part(part).mesh)
	if not skin_colors.is_empty(): body[ModularModel.BODY_SKIN_COLOR] = model.skin_color
	if not hair_colors.is_empty(): body[ModularModel.BODY_HAIR_COLOR] = model.hair_color
	return body

## Whether every part of [param body] with a pool shows a mesh from it, and its colours are of this configuration's (none where it
## has none), e.g. a body a peer rolled in the lobby
## @param body {part: [int] -> mesh ID: [String]}, see [method roll]
func allows(model: ModularModel, body: Dictionary) -> bool:
	if not _allows_color(body, ModularModel.BODY_SKIN_COLOR, skin_colors) or not _allows_color(body, ModularModel.BODY_HAIR_COLOR, hair_colors): return false
	var part_keys: PackedStringArray = model.get_part_keys()
	for part: Variant in body:
		if ModularModel.is_body_color_key(part): continue
		if not part is int or not model.has_part(part as int) or not body[part] is String: return false
		var part_key: String = part_keys[part as int]
		if not randomized_parts.has(part_key) or not mesh_pools.has(part_key): continue
		var mesh_id: String = body[part]
		# Parts without meshes (e.g. facial hair on a female body) roll none, whatever their pool
		if mesh_id.is_empty() and model.get_part(part as int).get_mesh_count() == 0: continue
		var mesh_number: String = ModularBodyPart.EMPTY_MESH_NUMBER if mesh_id.is_empty() else ModularBodyPart.get_mesh_number(ResourceId.get_file_path(mesh_id))
		if not mesh_pools[part_key].has(mesh_number): return false
	return true

## Whether [param part_key] may roll the mesh numbered [param mesh_number]: every mesh of a part without a pool may
func is_in_pool(part_key: String, mesh_number: String) -> bool:
	return not mesh_pools.has(part_key) or mesh_pools[part_key].has(mesh_number)

## [member mesh_pools] with [param mesh_number] let in or left out of [param part_key]'s pool; [param all_numbers] are the part's
## options, which a part without a pool rolls from. A pool holding all of them again is dropped, so new meshes join it
func with_pool_number(part_key: String, mesh_number: String, enabled: bool, all_numbers: PackedStringArray) -> Dictionary[String, PackedStringArray]:
	var pools: Dictionary[String, PackedStringArray] = mesh_pools.duplicate(true)
	var pool: PackedStringArray = all_numbers.duplicate()
	if pools.has(part_key): pool = pools[part_key].duplicate()
	if enabled and not pool.has(mesh_number): pool.append(mesh_number)
	if not enabled and pool.has(mesh_number): pool.remove_at(pool.find(mesh_number))
	var sorted: Array = Array(pool)
	sorted.sort_custom(func(first: String, second: String) -> bool: return first.naturalnocasecmp_to(second) < 0)
	pool = PackedStringArray(sorted)
	var complete: bool = Array(all_numbers).all(func(number: String) -> bool: return pool.has(number))
	if complete: pools.erase(part_key)
	else: pools[part_key] = pool
	return pools

## [member mesh_pools] with [param part_key]'s pool set to [param numbers]; all of the part's [param all_numbers] drop the pool
func with_pool(part_key: String, numbers: PackedStringArray, all_numbers: PackedStringArray) -> Dictionary[String, PackedStringArray]:
	var pools: Dictionary[String, PackedStringArray] = mesh_pools.duplicate(true)
	if Array(all_numbers).all(func(number: String) -> bool: return numbers.has(number)): pools.erase(part_key)
	else: pools[part_key] = numbers.duplicate()
	return pools

## The pool's numbers [param body_part] can show: its own meshes, and none where it may show none
func get_pool_options(body_part: ModularBodyPart, part_key: String) -> PackedStringArray:
	var options: PackedStringArray = []
	for mesh_number: String in mesh_pools.get(part_key, PackedStringArray()):
		if (mesh_number == ModularBodyPart.EMPTY_MESH_NUMBER and body_part.allows_none()) or body_part.find_mesh_index(mesh_number) >= 0: options.append(mesh_number)
	return options

func _roll_from_pool(body_part: ModularBodyPart, part_key: String) -> void:
	var options: PackedStringArray = get_pool_options(body_part, part_key)
	# E.g. facial hair on a female body, which has no meshes for it
	if body_part.get_mesh_count() == 0:
		body_part.update_index(-1)
		return
	if options.is_empty():
		push_warning("The pool of %s in %s names none of its meshes; rolling from all." % [part_key, resource_path])
		body_part.random_mesh()
		return
	var mesh_number: String = options[randi() % options.size()]
	body_part.update_index(-1 if mesh_number == ModularBodyPart.EMPTY_MESH_NUMBER else body_part.find_mesh_index(mesh_number))

static func _roll_color(colors: PackedColorArray) -> Color:
	return colors[randi() % colors.size()] if not colors.is_empty() else Color.TRANSPARENT

static func _allows_color(body: Dictionary, key: String, colors: PackedColorArray) -> bool:
	if colors.is_empty(): return not body.has(key)
	var color: Variant = body.get(key)
	return color is Color and colors.has(color as Color)
