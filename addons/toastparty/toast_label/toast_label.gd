class_name ToastLabel
extends Label

signal remove_label(ToastLabel)

var resolution = Vector2.ZERO

# Text margin with box parent
const margins = {"left": 12, "top": 7, "right": 12, "bottom": 7}
# margin between buttons
const margin_between = 23

# offset position box with screen position
const offset_position = Vector2(10, 10)

var button_size
var _tween_in: Tween

# local variables
var gravity: Toaster.Gravity = Toaster.Gravity.BOTTOM
var horizontal_position: Toaster.HorizontalPosition = Toaster.HorizontalPosition.CENTER
var vertical_position: Toaster.VerticalPosition = Toaster.VerticalPosition.TOP
var timer_to_destroy: float = 2.0  # seconds by default

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_resolution()
	position.y = get_y_pos(-100, vertical_position)
	button_size = self.size
	# start position
	_tween_destroy_label_timer()

func init(config: Toaster.ToasterConfig) -> void:
	update_text(config.text)
	_set_bg_color(config.bgcolor)
	_set_color(config.color)
	_set_font(config.use_font)
	_set_text_size(config.text_size)
	horizontal_position = config.horizontal_position
	vertical_position = config.vertical_position
	gravity = config.gravity
	_set_margins()

func update_text(new_text: String) -> void:
	text = new_text
	button_size = size
	update_x_position()

func move_to(index: int) -> void:
	update_x_position()
	var offset_y: float = (margin_between + button_size.y) * index
	var _y: float = get_y_pos(offset_y, vertical_position)
	if _tween_in: _tween_in.kill()
	# bottom
	_tween_in = create_tween()
	if gravity == Toaster.Gravity.BOTTOM and index == 0:
		var delayed = 0.03
		_tween_in.tween_property(self, "position", Vector2(position.x, _y), .3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN).set_delay(delayed)
	else:
		_tween_in.tween_property(self, "position", Vector2(position.x, _y), .3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)

func get_position_vector() -> Vector3i:
	return Vector3i(horizontal_position, vertical_position, gravity)

func _tween_destroy_label_complete() -> void:
	# Send event complete
	remove_label.emit(self)
	queue_free()

func _tween_destroy_label_timer():
	# tween alpha to 0
	var tween_alpha: Tween = create_tween()
	tween_alpha.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # pause mode
	tween_alpha.tween_property(self, "modulate:a", 0, 0.8).set_delay(timer_to_destroy)
	tween_alpha.tween_callback(_tween_destroy_label_complete)

func get_y_pos(offset: float, for_vertical_position: Toaster.VerticalPosition) -> float:
	var _y_pos: float = 0.0
	match for_vertical_position:
		Toaster.VerticalPosition.TOP: _y_pos = margins.top + offset_position.y + offset
		Toaster.VerticalPosition.CENTER: _y_pos = (resolution.y / 2.0) - (size.y / 2.0)
		Toaster.VerticalPosition.BOTTOM: _y_pos = resolution.y - margins.top - button_size.y - offset_position.y - offset
		_: push_error("Toaster.VerticalPosition %s not implemented!" % for_vertical_position)
	return _y_pos

func update_x_position() -> void:
	match horizontal_position:
		Toaster.HorizontalPosition.LEFT: position.x = margins.left + offset_position.x
		Toaster.HorizontalPosition.CENTER: position.x = (resolution.x / 2.0) - (size.x / 2.0)
		Toaster.HorizontalPosition.RIGHT: position.x = resolution.x - margins.left - size.x - offset_position.x
		_: push_error("Toaster.HorizontalPosition %s not implemented!" % horizontal_position)

func _set_color(color: Color) -> void:
	# set color
	var theme_override: LabelSettings = self.get("label_settings")
	theme_override.set("font_color", color)

func _set_font(use_font: bool) -> void:
	# set font
	if use_font == false:
		var theme_override = self.get("label_settings")
		theme_override.set("font", null)

func _set_margins() -> void:
	# set margins
	var theme_override = self.get("theme_override_styles/normal")
	theme_override.set("expand_margin_left", margins.left)
	theme_override.set("expand_margin_top", margins.top)
	theme_override.set("expand_margin_right", margins.right)
	theme_override.set("expand_margin_bottom", margins.bottom)

func _set_text_size(text_size: int) -> void:
	# set text size
	var theme_override = self.get("label_settings")
	theme_override.set("font_size", text_size)

func _set_bg_color(color: Color) -> void:
	# set bg color
	var theme_override = self.get("theme_override_styles/normal")
	theme_override.set("bg_color", color)

func _set_resolution():
	resolution.x = get_viewport().get_visible_rect().size.x
	resolution.y = get_viewport().get_visible_rect().size.y
