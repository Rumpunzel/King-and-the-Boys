@tool
class_name LoadingScreen
extends CanvasLayer

@export_group("Configuration")
@export var _progress_bar: ProgressBar

func set_loading_progress(progress: float) -> void:
	assert(_progress_bar)
	_progress_bar.value = progress
	_progress_bar.indeterminate = progress >= _progress_bar.max_value

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _progress_bar: warnings.append("Missing ProgressBar reference.")
	return warnings
