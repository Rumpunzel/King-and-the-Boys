@tool
extends Button

signal sky_box_pressed(sky_box: PanoramaSkyMaterial)

@export var sky_box: PanoramaSkyMaterial

@export_group("Configuration")
@export var _config: Config

func _ready() -> void:
	# Opened on its own in the editor: only the preview hands it a config
	if not _config: return
	var first_button: Node = get_parent().get_children().front()
	var selected: String = _config.get_value_from_config("SkyBox", "selected_sky_box", first_button.name)
	# Each button sets its own state (pressing without the signal does not release the group's others): the saved
	# choice, or the one pressed in the scene file if the saved one is gone
	var shows: bool = name == selected if get_parent().has_node(selected) else button_pressed
	set_pressed_no_signal(shows)
	if shows: sky_box_pressed.emit(sky_box)

func _on_toggled(toggled_on: bool) -> void:
	# Set from the scene file while it is built, before _config is: the saved choice, not a new one
	if not toggled_on or not is_node_ready(): return
	sky_box_pressed.emit(sky_box)
	_config.update_value_in_config(name, "SkyBox", "selected_sky_box")
