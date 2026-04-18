@tool
class_name LoadingScreen
extends CanvasLayer

@export_group("Configuration")
@export var _loading_bar: LoadingBar

func set_loading_progress(progress: float) -> void:
	assert(_loading_bar)
	_loading_bar.percentage = progress

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _loading_bar: warnings.append("Missing LoadingBar reference.")
	return warnings
