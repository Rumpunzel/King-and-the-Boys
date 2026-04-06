@tool
@icon("uid://btd64iwc2p3sh")
class_name CharacterProfile
extends Profile

enum Groups {
	PEOPLE,
	GHOSTS,
}

@export var group: Groups = Groups.PEOPLE:
	set(new_value):
		group = new_value
		changed.emit()

@export_category("Attributes")
@export var move_speed: float = 8.0:
	set(new_value):
		move_speed = new_value
		changed.emit()
@export var acceleration: float = 32.0:
	set(new_value):
		acceleration = new_value
		changed.emit()
@export var deceleration: float = 32.0:
	set(new_value):
		deceleration = new_value
		changed.emit()
@export var turn_rate: float = 12.0:
	set(new_value):
		turn_rate = new_value
		changed.emit()

@export_custom(PROPERTY_HINT_RANGE, "0.01,10000.0,exp,suffix:Newtons") var push_force: float = 750.0:
	set(new_value):
		push_force = new_value
		changed.emit()

@export_category("")
@export_group("Configuration")

func create(variation: int, spawn_transform: Transform3D) -> Character:
	var new_character: Character = PackedScenes.CHARACTER_SCENE.instantiate()
	new_character.variation = variation
	new_character.profile = self
	new_character.transform = spawn_transform
	return new_character

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
