@tool
@icon("uid://cscgs7miwut5n")
@abstract
class_name SpawnPoint
extends Marker3D

## Determines the varation of the [Model]
## If [code]<0[/code] a random [Model] will be used
@export var variation: int = -1

@export_group("Configuration")
@export var _editor_material: Material = preload("uid://dilpjt8kd3s4d")

func _ready() -> void:
	var _variation: int = variation if variation >= 0 else get_profile().get_random_variation()
	if not Engine.is_editor_hint():
		variation = _variation
		return
	var model: Model = get_profile().create_model(_variation)
	if _editor_material: model.apply_material_override(_editor_material)
	add_child(model)

@abstract func get_profile() -> Profile

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
