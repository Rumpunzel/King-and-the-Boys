@tool
@icon("uid://btd64iwc2p3sh")
class_name CharacterProfile
extends Profile

enum Groups {
	HEROES,
	MONSTERS,
}

# miniature_move_animation.tres, the default of both move animations
const _MOVE_ANIMATION: ModelAnimation = preload("uid://bwiaycc13h0eo")

@export var group: Groups = Groups.HEROES:
	set(new_value):
		group = new_value
		changed.emit()

@export_category("Attributes")
@export var strength: int = 3:
	set(new_value):
		strength = new_value
		changed.emit()
@export var agility: int = 3:
	set(new_value):
		agility = new_value
		changed.emit()
@export var intelligence: int = 3:
	set(new_value):
		intelligence = new_value
		changed.emit()
@export var speed: int = 3:
	set(new_value):
		speed = new_value
		changed.emit()
## Of several heroes on a tile, the one with the lowest number is the one a monster blocks (and blocks a monster leaving it)
@export var block_priority: int = 0

@export var vision: float = 1.5
@export var dark_vision: float = 2.5

@export_category("Abilities")
@export var abilities: Array[Ability]:
	set(new_value):
		abilities = new_value
		changed.emit()

@export_category("Model")
## Moves the character's model in menu previews (e.g. the lobby), so characters of other sizes stay framed alike, e.g. raises the
## smaller dwarf
@export var preview_offset: Vector3 = Vector3.ZERO
## Repaints the gear's blue highlights (cloth, banners, shield panels) to fit the character; transparent keeps the atlas' colour
@export var gear_primary_color: Color = Color.TRANSPARENT
## Repaints the gear's gold highlights (trims, emblems); transparent keeps the atlas' colour
@export var gear_secondary_color: Color = Color.TRANSPARENT
@export var model_configuration: ModelConfigurationRandom = preload("uid://c1i0e1p4feqhe"):
	set(new_value):
		_forward_changes([model_configuration], [new_value])
		model_configuration = new_value
		changed.emit()
## Each table rolls one [EquipmentLook] on top of the starting equipment, replacing the item in its slot
@export var random_equipment: Array[SpawnTable]:
	set(new_value):
		_forward_changes(random_equipment, new_value)
		random_equipment = new_value
		changed.emit()

## One look per slot, named after it (the group drops the "starting_" in the inspector), see [method set_starting_equipment_for]
## Usually a copy stored in this profile, so each character can be dressed part by part; hand-made look files are referenced
@export_group("Starting Equipment", "starting_")
@export var starting_head: EquipmentLook:
	set(new_value):
		starting_head = _accept_equipment(starting_head, new_value, EquipmentLook.Slot.HEAD)
		changed.emit()
@export var starting_face: EquipmentLook:
	set(new_value):
		starting_face = _accept_equipment(starting_face, new_value, EquipmentLook.Slot.FACE)
		changed.emit()
@export var starting_torso: EquipmentLook:
	set(new_value):
		starting_torso = _accept_equipment(starting_torso, new_value, EquipmentLook.Slot.TORSO)
		changed.emit()
@export var starting_hands: EquipmentLook:
	set(new_value):
		starting_hands = _accept_equipment(starting_hands, new_value, EquipmentLook.Slot.HANDS)
		changed.emit()
@export var starting_legs: EquipmentLook:
	set(new_value):
		starting_legs = _accept_equipment(starting_legs, new_value, EquipmentLook.Slot.LEGS)
		changed.emit()
@export var starting_back: EquipmentLook:
	set(new_value):
		starting_back = _accept_equipment(starting_back, new_value, EquipmentLook.Slot.BACK)
		changed.emit()
@export var starting_waist: EquipmentLook:
	set(new_value):
		starting_waist = _accept_equipment(starting_waist, new_value, EquipmentLook.Slot.WAIST)
		changed.emit()
@export var starting_main_hand: EquipmentLook:
	set(new_value):
		starting_main_hand = _accept_equipment(starting_main_hand, new_value, EquipmentLook.Slot.MAIN_HAND)
		changed.emit()
@export var starting_off_hand: EquipmentLook:
	set(new_value):
		starting_off_hand = _accept_equipment(starting_off_hand, new_value, EquipmentLook.Slot.OFF_HAND)
		changed.emit()
@export_group("")

@export_category("Animations")
@export var spawn_animation: ModelAnimation = preload("uid://djq27fwrmrv2")
@export var move_animation: ModelAnimation = _MOVE_ANIMATION
@export var fast_move_animation: ModelAnimation = _MOVE_ANIMATION
## Played when undo walks a step back; the move animation if empty
@export var undo_animation: ModelAnimation
## What the character's model rests in when nothing else plays, e.g. a few idles in turn; its body's own idle if empty
@export var idle_animations: BodyAnimations
## What the model rests in while its player has passed, in place of its idles: e.g. sitting down (its entry), sitting, and
## getting up again (its exit) as the pass ends (taken back, or a new turn)
@export var passed_animations: BodyAnimations
## What the model rests in while a monster is in the hero's sight during the monster phase, in place of its idles and passed
## animations, e.g. drawing a weapon (its entry), holding it ready, and putting it away again (its exit) as the next turn
## starts; without any, its idles
@export var alert_animations: BodyAnimations
## What the model rests in while knocked down (see [member Character.posture]), e.g. falling back (its entry), lying, and getting
## up again (its exit)
@export var down_animations: BodyAnimations
## Played as the character blocks another, e.g. a sword stroke; then it rests again
@export var block_animation: Animation
## Played once as a player picks the character in the lobby, e.g. drawing a sword; then the idles
@export var selected_animation: Animation

@export_category("")
@export_group("Configuration")

## The body and random equipment previews show, see [method setup_model]
var _preview_body: Dictionary = {}
## The model scene [member _preview_body] was rolled for; another one (e.g. a dwarf instead of a human) rolls anew
var _preview_model_path: String = ""
var _preview_random_equipment: Array[EquipmentLook] = []

func create(variation: int, spawn_transform: Transform3D) -> Character:
	var scene: PackedScene = load("uid://cvj6b1m2b65hd")
	var new_character: Character = scene.instantiate()
	new_character.variation = variation
	new_character.profile = self
	new_character.transform = spawn_transform
	return new_character

## Rolls the variation, the body and [member random_equipment], so only call this where character data is authored, i.e. on the server
## [param chosen_body] (e.g. the one a player picked in the lobby, see [member Player.body]) is used if it is a complete body of the model
## and keeps to [member model_configuration]'s pools
func create_character_data(variation: int, spawn_transform: Transform3D, chosen_body: Dictionary = {}) -> Dictionary[StringName, Variant]:
	var rolled_variation: int = variation if variation >= 0 else get_random_variation()
	var model: Model = create_model(rolled_variation)
	var body: Dictionary = {}
	if model is ModularModel:
		var modular_model: ModularModel = model
		var allowed: bool = not model_configuration or model_configuration.allows(modular_model, chosen_body)
		if modular_model.is_complete_body(chosen_body) and allowed: body = chosen_body.duplicate()
		elif model_configuration: body = model_configuration.roll(modular_model)
	if model: model.free()
	var equipment_ids: PackedStringArray = []
	for equipment_look: EquipmentLook in roll_equipment():
		var equipment_id: String = ResourceId.of(equipment_look)
		assert(not equipment_id.is_empty(), "EquipmentLook %s must be saved to be synchronized!" % equipment_look.name)
		equipment_ids.append(equipment_id)
	var character_data: Dictionary[StringName, Variant] = {
		Character.VARIATION: rolled_variation,
		Character.PROFILE_PATH: resource_path,
		Character.SPAWN_TRANSFORM: spawn_transform,
		Character.BODY: body,
		Character.EQUIPMENT: equipment_ids,
	}
	Character.validate_character_data(character_data)
	return character_data

## The starting equipment plus one roll of each [member random_equipment] table
func roll_equipment() -> Array[EquipmentLook]:
	var rolled_equipment: Array[EquipmentLook] = get_starting_equipment()
	rolled_equipment.append_array(_roll_random_equipment())
	return rolled_equipment

func _roll_random_equipment() -> Array[EquipmentLook]:
	var rolled_equipment: Array[EquipmentLook] = []
	for spawn_table: SpawnTable in random_equipment:
		# Empty entries are left over from editing the array in the inspector
		if not spawn_table: continue
		var rolled_profile: Profile = spawn_table.get_spawn()
		if rolled_profile is EquipmentLook: rolled_equipment.append(rolled_profile)
		else: push_error("SpawnTable in random_equipment of %s rolled %s, which is no EquipmentLook!" % [name, rolled_profile])
	return rolled_equipment

func create_model(variation: int) -> Model:
	var model: Model = super.create_model(variation)
	if model: model.idle_animations = idle_animations
	if model is ModularModel:
		var modular_model: ModularModel = model
		modular_model.set_gear_colors(gear_primary_color, gear_secondary_color)
		# Before any body is rolled or applied: they name meshes of the body's gender
		if model_configuration: modular_model.set_gender(model_configuration.gender)
	# In game the server rolls the look once and sends it as [constant Character.BODY]
	if model is ModularModel and Engine.is_editor_hint(): setup_model(model as ModularModel)
	return model

## Rolls a body for [param variation]'s model, see [method ModelConfigurationRandom.roll]; empty for models without one
func roll_body(variation: int) -> Dictionary:
	var model: Model = create_model(variation)
	var body: Dictionary = model_configuration.roll(model as ModularModel) if model is ModularModel and model_configuration else {}
	if model: model.free()
	return body

## Rolls the body and [member random_equipment] locally, for previews only; later previews keep that roll, so editing the
## profile (e.g. its outfit) does not change the face, until [param reroll] asks for a new one
func setup_model(model: ModularModel, reroll: bool = false) -> void:
	model.reset_gear()
	# A body that no longer fits (another scene, the configuration's gender, pools or colours changed) rolls anew
	var allowed: bool = not model_configuration or model_configuration.allows(model, _preview_body)
	if reroll or _preview_body.is_empty() or _preview_model_path != model.scene_file_path or not model.is_complete_body(_preview_body) or not allowed:
		_preview_model_path = model.scene_file_path
		_preview_body = model_configuration.roll(model) if model_configuration else {}
		_preview_random_equipment = _roll_random_equipment()
	dress_model(model, _preview_body, _preview_random_equipment)

## The mesh numbers [param part] of [param model] may show for this profile: its pool, or all its meshes (and none where it may show
## none) if it has no pool; only its default if it is not randomized
func get_body_options(model: ModularModel, part: int) -> PackedStringArray:
	var body_part: ModularBodyPart = model.get_part(part)
	var part_key: String = model.get_part_keys()[part]
	var options: PackedStringArray = [ModularBodyPart.EMPTY_MESH_NUMBER] if body_part.allows_none() else []
	options.append_array(body_part.get_mesh_numbers())
	if not model_configuration or not model_configuration.randomized_parts.has(part_key): return options
	if model_configuration.mesh_pools.has(part_key): return model_configuration.get_pool_options(body_part, part_key)
	return options

## Shows the mesh numbered [param mesh_number] on [param part] of the preview [param model], and keeps it in the preview's body
## (see [method setup_model]), so rebuilds show it too
func set_preview_body_part(model: ModularModel, part: int, mesh_number: String) -> void:
	var body_part: ModularBodyPart = model.get_part(part)
	body_part.update_index(-1 if mesh_number == ModularBodyPart.EMPTY_MESH_NUMBER else body_part.find_mesh_index(mesh_number))
	# By mesh, not visibility: gear may hide the part (a helmet the beard)
	if _preview_model_path == model.scene_file_path: _preview_body[part] = ResourceId.of(body_part.mesh) if body_part.mesh else ""

## Shows [param body] and the starting equipment plus [param extra_equipment] on [param model], e.g. a player's body in the lobby
func dress_model(model: ModularModel, body: Dictionary, extra_equipment: Array[EquipmentLook] = []) -> void:
	model.reset_gear()
	model.apply_body(body)
	# A detached [CharacterEquipment] applies the same slot and blocking rules as in game
	var preview_equipment: CharacterEquipment = CharacterEquipment.new()
	preview_equipment.apply_to(model)
	var shown_equipment: Array[EquipmentLook] = get_starting_equipment()
	shown_equipment.append_array(extra_equipment)
	for equipment_look: EquipmentLook in shown_equipment: preview_equipment.equip(equipment_look)
	preview_equipment.free()

## Whether items of [param equipment_type] fit one of this profile's model variations, e.g. dwarf gear a dwarf
func fits(equipment_type: EquipmentType) -> bool:
	if not equipment_type or not equipment_type.model: return false
	for model_variation: PackedScene in _model_variations:
		if model_variation and model_variation.resource_path == equipment_type.model.resource_path: return true
	return false

## @returns the starting items in slot order, empty slots left out
func get_starting_equipment() -> Array[EquipmentLook]:
	var starting_equipment: Array[EquipmentLook] = []
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		var equipment_look: EquipmentLook = get_starting_equipment_for(slot)
		if equipment_look: starting_equipment.append(equipment_look)
	return starting_equipment

func get_starting_equipment_for(slot: EquipmentLook.Slot) -> EquipmentLook:
	return get(get_slot_property(slot))

## A look stored inside another file, such as a catalog entry, is copied into this profile (see [method EquipmentLook.make_local])
func set_starting_equipment_for(slot: EquipmentLook.Slot, equipment_look: EquipmentLook) -> void:
	if equipment_look and equipment_look.resource_path.contains(ResourceId.SEPARATOR) and equipment_look.resource_path.get_slice(ResourceId.SEPARATOR, 0) != resource_path:
		equipment_look = equipment_look.make_local()
	set(get_slot_property(slot), equipment_look)

## Each slot's field is named after it, e.g. [member starting_head] for [constant EquipmentLook.HEAD]
static func get_slot_property(slot: EquipmentLook.Slot) -> StringName:
	var slot_name: String = EquipmentLook.Slot.keys()[slot]
	return StringName("starting_" + slot_name.to_lower())

## Profiles saved before slots held looks stored a [ResourceId] under the slot's plain name; it loads as a local copy
func _set(property: StringName, value: Variant) -> bool:
	if not value is String: return false
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		var slot_name: String = EquipmentLook.Slot.keys()[slot]
		if property != StringName(slot_name.to_lower()): continue
		var legacy_id: String = value
		if not legacy_id.is_empty(): set_starting_equipment_for(slot, ResourceId.find(legacy_id) as EquipmentLook)
		return true
	return false

## Keeps [param old_look] if [param new_look] is untyped or of another slot, so a field never holds a mismatching look
func _accept_equipment(old_look: EquipmentLook, new_look: EquipmentLook, slot: EquipmentLook.Slot) -> EquipmentLook:
	if new_look:
		var slot_name: String = EquipmentLook.Slot.keys()[slot]
		if not new_look.type:
			push_error("%s has no EquipmentType and cannot be starting equipment of %s." % [new_look.name, name])
			return old_look
		if new_look.slot != slot:
			var look_slot_name: String = EquipmentLook.Slot.keys()[new_look.slot]
			push_error("%s goes into slot %s, not %s." % [new_look.name, look_slot_name.capitalize(), slot_name.capitalize()])
			return old_look
	_forward_changes([old_look], [new_look])
	return new_look

## Re-emits [signal Resource.changed] of nested resources, so previews also update when an item is edited
func _forward_changes(old_resources: Array, new_resources: Array) -> void:
	for resource: Resource in old_resources:
		if resource and resource.changed.is_connected(changed.emit): resource.changed.disconnect(changed.emit)
	for resource: Resource in new_resources:
		if resource and not resource.changed.is_connected(changed.emit): resource.changed.connect(changed.emit)

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _to_string() -> String:
	return "<%s, STRENGTH: %d, AGILITY: %d, INTELLIGENCE: %d, SPEED: %d>" % [name, strength, agility, intelligence, speed]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	for equipment_look: EquipmentLook in get_starting_equipment():
		if not fits(equipment_look.type): warnings.append("%s is not made for this profile's models." % equipment_look.name)
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots:
			var blocked_profile: EquipmentLook = get_starting_equipment_for(blocked_slot)
			if blocked_profile: warnings.append("%s blocks %s, so %s is never worn." % [equipment_look.name, EquipmentLook.Slot.keys()[blocked_slot], blocked_profile.name])
	return warnings + super._get_configuration_warnings()
