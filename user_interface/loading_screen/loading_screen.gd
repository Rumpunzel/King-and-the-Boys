@tool
class_name LoadingScreen
extends CanvasLayer

@export_group("Configuration")
@export var _background: Control
@export var _loading_bar: LoadingBar

func _ready() -> void:
	if not _background: return
	_background.visible = not Panorama.is_showing_panorama()

func set_loading_message(message: String) -> void:
	assert(_loading_bar)
	_loading_bar.loading_text = message

func set_loading_progress(progress: float) -> void:
	assert(_loading_bar)
	_loading_bar.percentage = progress

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _background: warnings.append("Missing background reference.")
	if not _loading_bar: warnings.append("Missing LoadingBar reference.")
	return warnings
