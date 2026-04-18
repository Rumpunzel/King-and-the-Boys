@icon("uid://m54bkmd348w1")
class_name Toaster
extends Node

enum Type {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
}

enum Gravity {
	TOP,
	BOTTOM,
}

enum HorizontalPosition {
	LEFT = -1,
	CENTER,
	RIGHT,
}

enum VerticalPosition {
	TOP = -1,
	CENTER,
	BOTTOM,
}

const text_colors: Dictionary[Type, Color] = {
	Type.INFO: Color.WHITE,
	Type.SUCCESS: Color.WHITE,
	Type.WARNING: Color.BLACK,
	Type.ERROR: Color.WHITE,
}

const background_colors: Dictionary[Type, Color] = {
	Type.INFO: Color("#196ab1"),
	Type.SUCCESS: Color("#158a43"),
	Type.WARNING: Color("#c4850e"),
	Type.ERROR: Color("#c02f1d"),
}

@export var _horizontal_position: HorizontalPosition = HorizontalPosition.CENTER
@export var _vertical_position: VerticalPosition = VerticalPosition.TOP
@export var _gravity: Gravity = Gravity.BOTTOM
@export var _text_size: int = 18
@export var _custom_toast_font: bool = false

static func show_toast(
	message: String,
	type: Type,
	horizontal_position: HorizontalPosition,
	vertical_position: VerticalPosition,
	gravity: Gravity,
	text_size: int, 
	custom_toast_font: bool,
) -> void:
	assert(not message.is_empty())
	ToastParty.show(ToasterConfig.new(message, type, horizontal_position, vertical_position, gravity, text_size, custom_toast_font))

func toast_info(message: String) -> void:
	show_toast(message, Type.INFO, _horizontal_position, _vertical_position, _gravity, _text_size, _custom_toast_font)

func toast_success(message: String) -> void:
	show_toast(message, Type.SUCCESS, _horizontal_position, _vertical_position, _gravity, _text_size, _custom_toast_font)

func toast_warning(message: String) -> void:
	show_toast(message, Type.WARNING, _horizontal_position, _vertical_position, _gravity, _text_size, _custom_toast_font)

func toast_error(message: String) -> void:
	show_toast(message, Type.ERROR, _horizontal_position, _vertical_position, _gravity, _text_size, _custom_toast_font)

class ToasterConfig extends RefCounted:
	var text: String
	var bgcolor: Color
	var color: Color
	var horizontal_position: HorizontalPosition
	var vertical_position: VerticalPosition
	var gravity: Gravity
	var text_size: int
	var use_font: bool
	
	func _init(
		with_message: String,
		type: Type,
		with_horizontal_position: HorizontalPosition,
		with_vertical_position: VerticalPosition,
		with_gravity: Gravity,
		with_text_size: int,
		with_custom_font: bool
	) -> void:
		text = with_message
		bgcolor = background_colors[type]
		color = text_colors[type]
		horizontal_position = with_horizontal_position
		vertical_position = with_vertical_position
		gravity = with_gravity
		text_size = with_text_size
		use_font = with_custom_font
