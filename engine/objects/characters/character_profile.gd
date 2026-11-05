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
@export var starting_equipment: Array[EquipmentProfile]:
	set(new_value):
		_forward_changes(starting_equipment, new_value)
		starting_equipment = new_value
		changed.emit()
## Each table rolls one [EquipmentProfile] on top of [member starting_equipment], replacing the item in its slot
@export var random_equipment: Array[SpawnTable]:
	set(new_value):
		_forward_changes(random_equipment, new_value)
		random_equipment = new_value
		changed.emit()

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
	var rolled_equipment: Array[EquipmentProfile] = starting_equipment.duplicate()
	for spawn_table: SpawnTable in random_equipment:
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
	return warnings + super._get_configuration_warnings()
