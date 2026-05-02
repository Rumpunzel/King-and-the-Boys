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
@export var model_configuration: ModelConfiguration = preload("uid://c1i0e1p4feqhe")
@export var starting_equipment: Array[GearProfile]

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

func create_model(variation: int) -> Model:
	var model: ModularCharacter = super.create_model(variation)
	setup_model(model)
	return model

func setup_model(model: ModularCharacter) -> void:
	model_configuration.configure(model)
	for gear_profile: GearProfile in starting_equipment: gear_profile.model_configuration.configure(model)

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _to_string() -> String:
	return "<%s, STRENGTH: %d, AGILITY: %d, INTELLIGENCE: %d, SPEED: %d>" % [name, strength, agility, intelligence, speed]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
