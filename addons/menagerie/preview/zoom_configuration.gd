@tool
extends BoxContainer

signal zoom_changed(new_zoom: float)
signal zoomed_out
signal zoomed_in

@export var _inverted: bool = true

@export_group("Configuration")
@export var _zoom_slider: Slider
@export var _config: Config

func _ready() -> void:
	var zoom_from_config: float = _config.get_value_from_config("Camera", "zoom", 0.5)
	_zoom_slider.set_value_no_signal(zoom_from_config)
	zoom_changed.emit(zoom_from_config)

func _on_zoom_slider_value_changed(value: float) -> void:
	var new_zoom: float = (_zoom_slider.max_value - value) if _inverted else value
	zoom_changed.emit(new_zoom)
	_config.update_value_in_config(new_zoom, "Camera", "zoom")

func _on_zoom_out_pressed() -> void:
	zoomed_out.emit()

func _on_zoom_in_pressed() -> void:
	zoomed_in.emit()

func _on_zoom_value_changed(zoom_value: float) -> void:
	var new_zoom: float = (_zoom_slider.max_value - zoom_value) if _inverted else zoom_value
	_zoom_slider.set_value_no_signal(new_zoom)
	_config.update_value_in_config(new_zoom, "Camera", "zoom")
