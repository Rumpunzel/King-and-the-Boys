@tool
extends BoxContainer

signal tilt_changed(new_tilt: float)
signal tilted_more
signal tilted_less

@export var _inverted: bool = false

@export_group("Configuration")
@export var _tilt_slider: Slider
@export var _config: Config

func _ready() -> void:
	var tilt_from_config: float = _config.get_value_from_config("Camera", "tilt", 0.25)
	_tilt_slider.set_value_no_signal(tilt_from_config)
	tilt_changed.emit(tilt_from_config)

func _on_tilt_slider_value_changed(value: float) -> void:
	var new_tilt: float = (_tilt_slider.max_value - value) if _inverted else value
	tilt_changed.emit(new_tilt)
	_config.update_value_in_config(new_tilt, "Camera", "tilt")

func _on_tilt_more_pressed() -> void:
	tilted_more.emit()

func _on_tilt_less_pressed() -> void:
	tilted_less.emit()

func _on_tilt_value_changed(tilt_value: float) -> void:
	var new_tilt: float = (_tilt_slider.max_value - tilt_value) if _inverted else tilt_value
	_tilt_slider.set_value_no_signal(new_tilt)
	_config.update_value_in_config(new_tilt, "Camera", "tilt")
