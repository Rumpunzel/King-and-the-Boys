@tool
@icon("uid://c4udocqr7qeyj")
@abstract
class_name Profile
extends Resource

@export var name: String:
	set(new_value):
		name = new_value
		changed.emit()
@export var portrait: Texture:
	set(new_value):
		portrait = new_value
		changed.emit()
@export var color: Color = Color("#e0e0e0"):
	set(new_value):
		color = new_value
		changed.emit()

@export_category("Model")
# TODO: refactor into @export_file("*.tscn") var _model_variations: Array[String]
@export var _model_variations: Array[PackedScene]:
	set(new_value):
		_model_variations = new_value
		changed.emit()

@export var heads_up_display_offset: Vector3 = Vector3(0.0, 2.0, 0.0):
	set(new_value):
		heads_up_display_offset = new_value
		changed.emit()

@export_category("")
@export_group("Configuration")

func create_model(variation: int) -> Model:
	if _model_variations.is_empty(): return null
	assert(variation >= 0)
	assert(variation < get_variation_count())
	var model: PackedScene = _model_variations[variation]
	return model.instantiate()

## @returns a random model variation, or [code]-1[/code] for a profile without models (e.g. in tests)
func get_random_variation() -> int:
	if _model_variations.is_empty(): return -1
	return randi() % get_variation_count()

func get_variation_count() -> int:
	return _model_variations.size()

@abstract func get_group_name() -> StringName

func get_default_icon() -> Texture2D:
	var global_class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var own_global_class: Dictionary
	for global_class: Dictionary in global_class_list:
		var own_script: GDScript = get_script()
		if global_class.class == own_script.get_global_name():
			own_global_class = global_class
			break
	var own_global_class_icon_path: String = own_global_class.icon
	assert(own_global_class_icon_path is String)
	if own_global_class_icon_path.is_empty(): return null
	return load(own_global_class_icon_path)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings
