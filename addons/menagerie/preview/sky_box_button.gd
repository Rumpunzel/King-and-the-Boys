@tool
extends Button

signal sky_box_pressed(sky_box: PanoramaSkyMaterial)

@export var sky_box: PanoramaSkyMaterial

@export_group("Configuration")
@export var _config: Config

func _ready() -> void:
	var selected_sky_box_from_camera: String = _config.get_value_from_config("SkyBox", "selected_sky_box", get_parent().get_children().front().name)
	if name == selected_sky_box_from_camera:
		set_pressed_no_signal(true)
		sky_box_pressed.emit(sky_box)

func _on_toggled(toggled_on: bool) -> void:
	if not toggled_on: return
	sky_box_pressed.emit(sky_box)
	_config.update_value_in_config(name, "SkyBox", "selected_sky_box")
