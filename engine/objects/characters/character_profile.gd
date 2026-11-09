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

@export var vision: float = 1.5
@export var dark_vision: float = 2.5

@export_category("Model")
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

## One item per slot, as [ResourceId]s (a catalog entry lives inside another file, which an export cannot point into)
## Each field only accepts items of its slot and is named after it, see [method set_starting_equipment_for]
@export_group("Starting Equipment")
@export var head: String:
	set(new_value):
		head = _accept_equipment(head, new_value, EquipmentLook.Slot.HEAD)
		changed.emit()
@export var face: String:
	set(new_value):
		face = _accept_equipment(face, new_value, EquipmentLook.Slot.FACE)
		changed.emit()
@export var torso: String:
	set(new_value):
		torso = _accept_equipment(torso, new_value, EquipmentLook.Slot.TORSO)
		changed.emit()
@export var hands: String:
	set(new_value):
		hands = _accept_equipment(hands, new_value, EquipmentLook.Slot.HANDS)
		changed.emit()
@export var legs: String:
	set(new_value):
		legs = _accept_equipment(legs, new_value, EquipmentLook.Slot.LEGS)
		changed.emit()
@export var back: String:
	set(new_value):
		back = _accept_equipment(back, new_value, EquipmentLook.Slot.BACK)
		changed.emit()
@export var waist: String:
	set(new_value):
		waist = _accept_equipment(waist, new_value, EquipmentLook.Slot.WAIST)
		changed.emit()
@export var main_hand: String:
	set(new_value):
		main_hand = _accept_equipment(main_hand, new_value, EquipmentLook.Slot.MAIN_HAND)
		changed.emit()
@export var off_hand: String:
	set(new_value):
		off_hand = _accept_equipment(off_hand, new_value, EquipmentLook.Slot.OFF_HAND)
		changed.emit()
@export_group("")

@export_category("Animations")
@export var spawn_animation: ModelAnimation = preload("uid://djq27fwrmrv2")
@export var move_animation: ModelAnimation = _MOVE_ANIMATION
@export var fast_move_animation: ModelAnimation = _MOVE_ANIMATION
## Played when undo walks a step back; the move animation if empty
@export var undo_animation: ModelAnimation

@export_category("")
@export_group("Configuration")

## The body and random equipment previews show, see [method setup_model]
var _preview_body: Dictionary = {}
var _preview_random_equipment: Array[EquipmentLook] = []

func create(variation: int, spawn_transform: Transform3D) -> Character:
	var scene: PackedScene = load("uid://cvj6b1m2b65hd")
	var new_character: Character = scene.instantiate()
	new_character.variation = variation
	new_character.profile = self
	new_character.transform = spawn_transform
	return new_character

## Rolls the variation, the body and [member random_equipment], so only call this where character data is authored, i.e. on the server
func create_character_data(variation: int, spawn_transform: Transform3D) -> Dictionary[StringName, Variant]:
	var rolled_variation: int = variation if variation >= 0 else get_random_variation()
	var model: ModularCharacter = create_model(rolled_variation)
	var body: Dictionary = model_configuration.roll(model)
	model.free()
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
	var model: ModularCharacter = super.create_model(variation)
	# In game the server rolls the look once and sends it as [constant Character.BODY]
	if model and Engine.is_editor_hint(): setup_model(model)
	return model

## Rolls the body and [member random_equipment] locally, for previews only; later previews keep that roll, so editing the
## profile (e.g. its outfit) does not change the face, until [param reroll] asks for a new one
func setup_model(model: ModularCharacter, reroll: bool = false) -> void:
	model.reset_gear()
	if reroll or _preview_body.is_empty():
		_preview_body = model_configuration.roll(model)
		_preview_random_equipment = _roll_random_equipment()
	for part: int in _preview_body:
		model.get_part(part as ModularCharacter.Part).apply_mesh(ResourceId.find(_preview_body[part] as String) as ArrayMesh)
	# A detached [CharacterEquipment] applies the same slot and blocking rules as in game
	var preview_equipment: CharacterEquipment = CharacterEquipment.new()
	preview_equipment.apply_to(model)
	var shown_equipment: Array[EquipmentLook] = get_starting_equipment()
	shown_equipment.append_array(_preview_random_equipment)
	for equipment_look: EquipmentLook in shown_equipment: preview_equipment.equip(equipment_look)
	preview_equipment.free()

## @returns the starting items in slot order, empty slots left out
func get_starting_equipment() -> Array[EquipmentLook]:
	var starting_equipment: Array[EquipmentLook] = []
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		var equipment_look: EquipmentLook = get_starting_equipment_for(slot)
		if equipment_look: starting_equipment.append(equipment_look)
	return starting_equipment

func get_starting_equipment_for(slot: EquipmentLook.Slot) -> EquipmentLook:
	return ResourceId.find(get_starting_equipment_id(slot)) as EquipmentLook

func get_starting_equipment_id(slot: EquipmentLook.Slot) -> String:
	return get(get_slot_property(slot))

## [param equipment_look] must be saved, as the slot stores its [ResourceId]
func set_starting_equipment_for(slot: EquipmentLook.Slot, equipment_look: EquipmentLook) -> void:
	var equipment_id: String = ResourceId.of(equipment_look)
	assert(equipment_look == null or not equipment_id.is_empty(), "Only saved EquipmentProfiles can be starting equipment!")
	set(get_slot_property(slot), equipment_id)

## Each slot's field is named after it, e.g. [member head] for [constant EquipmentLook.HEAD]
static func get_slot_property(slot: EquipmentLook.Slot) -> StringName:
	var slot_name: String = EquipmentLook.Slot.keys()[slot]
	return StringName(slot_name.to_lower())

## Keeps [param old_id] if [param new_id] names no item, an untyped one or one of another slot, so a field never holds a mismatching item
func _accept_equipment(old_id: String, new_id: String, slot: EquipmentLook.Slot) -> String:
	var new_profile: EquipmentLook = ResourceId.find(new_id) as EquipmentLook
	if not new_id.is_empty():
		var slot_name: String = EquipmentLook.Slot.keys()[slot]
		if not new_profile:
			push_error("%s names no EquipmentLook; %s keeps its %s." % [new_id, name, slot_name.capitalize()])
			return old_id
		if not new_profile.type:
			push_error("%s has no EquipmentType and cannot be starting equipment of %s." % [new_id, name])
			return old_id
		if new_profile.slot != slot:
			var item_slot_name: String = EquipmentLook.Slot.keys()[new_profile.slot]
			push_error("%s goes into slot %s, not %s." % [new_profile.name, item_slot_name.capitalize(), slot_name.capitalize()])
			return old_id
	_forward_changes([ResourceId.find(old_id)], [new_profile])
	return new_id

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
		# Kept rather than refused, so unchecking a look in a catalog never silently empties a slot
		if not equipment_look.allowed: warnings.append("%s is unchecked in its catalog." % equipment_look.name)
		for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots:
			var blocked_profile: EquipmentLook = get_starting_equipment_for(blocked_slot)
			if blocked_profile: warnings.append("%s blocks %s, so %s is never worn." % [equipment_look.name, EquipmentLook.Slot.keys()[blocked_slot], blocked_profile.name])
	return warnings + super._get_configuration_warnings()
