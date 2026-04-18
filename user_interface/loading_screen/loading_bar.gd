@tool
class_name LoadingBar
extends PanelContainer

enum Mode {
	DECREMENTING = -1,
	INCREMENTING = 1,
}

@export var loading_text: String = "Loading":
	get: return _loading_label.text
	set(new_loading_text): _loading_label.text = new_loading_text

@export var loading_suffix: String = "...":
	set(new_loading_suffix): _suffix_label.text = new_loading_suffix

@export_range(0.0, 1.0, 0.01) var percentage: float = 1.0:
	get: return _progres_bar.value
	set(new_percentage):
		_progres_bar.value = new_percentage
		_progres_bar.indeterminate = new_percentage >= _progres_bar.max_value

@export var _increment_delay: float = 0.25
@export var _decrement_delay: float = 0.1
@export var _rest_delay: float = 1.0

@export_group("Configuration")
@export var _progres_bar: ProgressBar
@export var _loading_label: Label
@export var _suffix_label: Label

var _mode: Mode = Mode.INCREMENTING

@onready var _visible_characters: float = loading_suffix.length()

func _process(delta: float) -> void:
	assert(_suffix_label)
	match _mode:
		Mode.INCREMENTING:
			_visible_characters += delta / _increment_delay
			if _visible_characters >= loading_suffix.length() + _rest_delay: _mode = Mode.DECREMENTING
		Mode.DECREMENTING:
			_visible_characters -= delta / _decrement_delay
			if _visible_characters <= 0 - _rest_delay: _mode = Mode.INCREMENTING
		_: push_error("Mode %s not implemented!" % _mode)
	_visible_characters = clampf(_visible_characters, - _rest_delay, loading_suffix.length() + _rest_delay)
	_suffix_label.visible_characters = maxi(floori(_visible_characters), 0)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _progres_bar: warnings.append("Missing ProgressBar reference.")
	if not _loading_label: warnings.append("Missing loading Label reference.")
	if not _suffix_label: warnings.append("Missing suffix Label reference.")
	return warnings
