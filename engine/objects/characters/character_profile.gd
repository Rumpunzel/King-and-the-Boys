@tool
@icon("uid://btd64iwc2p3sh")
class_name CharacterProfile
extends Profile

enum Groups {
	HEROES,
	MONSTERS,
}

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
## Each table rolls one [EquipmentProfile] on top of the starting equipment, replacing the item in its slot
@export var random_equipment: Array[SpawnTable]:
	set(new_value):
		_forward_changes(random_equipment, new_value)
		random_equipment = new_value
		changed.emit()

## One item per slot; each field only accepts items of its slot, see [method set_starting_equipment_for]
@export_group("Starting Equipment")
@export var head: EquipmentProfile:
	set(new_value):
		head = _accept_equipment(head, new_value, EquipmentProfile.Slot.HEAD)
		changed.emit()
@export var face: EquipmentProfile:
	set(new_value):
		face = _accept_equipment(face, new_value, EquipmentProfile.Slot.FACE)
		changed.emit()
@export var torso: EquipmentProfile:
	set(new_value):
		torso = _accept_equipment(torso, new_value, EquipmentProfile.Slot.TORSO)
		changed.emit()
@export var hands: EquipmentProfile:
	set(new_value):
		hands = _accept_equipment(hands, new_value, EquipmentProfile.Slot.HANDS)
		changed.emit()
@export var legs: EquipmentProfile:
	set(new_value):
		legs = _accept_equipment(legs, new_value, EquipmentProfile.Slot.LEGS)
		changed.emit()
@export var back: EquipmentProfile:
	set(new_value):
		back = _accept_equipment(back, new_value, EquipmentProfile.Slot.BACK)
		changed.emit()
@export var main_hand: EquipmentProfile:
	set(new_value):
		main_hand = _accept_equipment(main_hand, new_value, EquipmentProfile.Slot.MAIN_HAND)
		changed.emit()
@export var off_hand: EquipmentProfile:
	set(new_value):
		off_hand = _accept_equipment(off_hand, new_value, EquipmentProfile.Slot.OFF_HAND)
		changed.emit()
@export_group("")

@export_category("Animations")
@export var spawn_animation: ModelAnimation = preload("uid://djq27fwrmrv2")
@export var move_animation: ModelAnimation = preload("uid://bwiaycc13h0eo")
@export var fast_move_animation: ModelAnimation = preload("uid://bwiaycc13h0eo")

@export_category("")
@export_group("Configuration")

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
	var equipment_paths: PackedStringArray = []
	for equipment_profile: EquipmentProfile in roll_equipment():
		assert(equipment_profile.resource_path.is_absolute_path(), "EquipmentProfile %s must be saved as its own file to be synchronized!" % equipment_profile.name)
		equipment_paths.append(equipment_profile.resource_path)
	var character_data: Dictionary[StringName, Variant] = {
		Character.VARIATION: rolled_variation,
		Character.PROFILE_PATH: resource_path,
		Character.SPAWN_TRANSFORM: spawn_transform,
		Character.BODY: body,
		Character.EQUIPMENT: equipment_paths,
	}
	Character.validate_character_data(character_data)
	return character_data

func roll_equipment() -> Array[EquipmentProfile]:
	var rolled_equipment: Array[EquipmentProfile] = get_starting_equipment()
	for spawn_table: SpawnTable in random_equipment:
		# Empty entries are left over from editing the array in the inspector
		if not spawn_table: continue
		var rolled_profile: Profile = spawn_table.get_spawn()
		if rolled_profile is EquipmentProfile: rolled_equipment.append(rolled_profile)
		else: push_error("SpawnTable in random_equipment of %s rolled %s, which is no EquipmentProfile!" % [name, rolled_profile])
	return rolled_equipment

func create_model(variation: int) -> Model:
	var model: ModularCharacter = super.create_model(variation)
	# In game the server rolls the look once and sends it as [constant Character.BODY]
	if Engine.is_editor_hint(): setup_model(model)
	return model

## Randomizes the look and equipment locally, for previews only
func setup_model(model: ModularCharacter) -> void:
	model.reset_gear()
	model_configuration.configure(model)
	# A detached [CharacterEquipment] applies the same slot and blocking rules as in game
	var preview_equipment: CharacterEquipment = CharacterEquipment.new()
	preview_equipment.apply_to(model)
	for equipment_profile: EquipmentProfile in roll_equipment(): preview_equipment.equip(equipment_profile)
	preview_equipment.free()

## @returns the starting items in slot order, empty slots left out
func get_starting_equipment() -> Array[EquipmentProfile]:
	var starting_equipment: Array[EquipmentProfile] = []
	for slot: EquipmentProfile.Slot in EquipmentProfile.Slot.values():
		var equipment_profile: EquipmentProfile = get_starting_equipment_for(slot)
		if equipment_profile: starting_equipment.append(equipment_profile)
	return starting_equipment

func get_starting_equipment_for(slot: EquipmentProfile.Slot) -> EquipmentProfile:
	return get(_get_slot_property(slot))

func set_starting_equipment_for(slot: EquipmentProfile.Slot, equipment_profile: EquipmentProfile) -> void:
	set(_get_slot_property(slot), equipment_profile)

## Each slot's field is named after it, e.g. [member head] for [constant EquipmentProfile.HEAD]
static func _get_slot_property(slot: EquipmentProfile.Slot) -> StringName:
	var slot_name: String = EquipmentProfile.Slot.keys()[slot]
	return StringName(slot_name.to_lower())

## Keeps [param old_value] if [param new_value] belongs to another slot, so a field never holds a mismatching item
func _accept_equipment(old_value: EquipmentProfile, new_value: EquipmentProfile, slot: EquipmentProfile.Slot) -> EquipmentProfile:
	var slot_name: String = EquipmentProfile.Slot.keys()[slot]
	if new_value and not new_value.type:
		push_error("%s has no EquipmentType and cannot be starting equipment of %s." % [new_value.resource_path, name])
		return old_value
	if new_value and new_value.slot != slot:
		var item_slot_name: String = EquipmentProfile.Slot.keys()[new_value.slot]
		push_error("%s goes into slot %s, not %s." % [new_value.resource_path, item_slot_name.capitalize(), slot_name.capitalize()])
		return old_value
	_forward_changes([old_value], [new_value])
	return new_value

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
	for equipment_profile: EquipmentProfile in get_starting_equipment():
		for blocked_slot: EquipmentProfile.Slot in equipment_profile.blocked_slots:
			var blocked_profile: EquipmentProfile = get_starting_equipment_for(blocked_slot)
			if blocked_profile: warnings.append("%s blocks %s, so %s is never worn." % [equipment_profile.name, EquipmentProfile.Slot.keys()[blocked_slot], blocked_profile.name])
	return warnings + super._get_configuration_warnings()
