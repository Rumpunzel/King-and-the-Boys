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

enum Direction {
	CENTER,
	LEFT,
	RIGHT,
}

const text_colors: Dictionary[Type, Color] = {
	Type.INFO: Color.WHITE,
	Type.SUCCESS: Color.BLACK,
	Type.WARNING: Color.BLACK,
	Type.ERROR: Color.WHITE,
}

const background_colors: Dictionary[Type, Color] = {
	Type.INFO: Color("#3b6b8a"),
	Type.SUCCESS: Color("#527a5e"),
	Type.WARNING: Color("#c4850e"),
	Type.ERROR: Color("#a34136"),
}

@export var _gravity: Gravity = Gravity.TOP
@export var _direction: Direction = Direction.CENTER
@export var _text_size: int = 18
@export var _custom_toast_font: bool = false

static func show_toast(
	message: String,
	type: Type,
	gravity: Gravity,
	direction: Direction,
	text_size: int, 
	custom_toast_font: bool,
) -> void:
	assert(not message.is_empty())
	ToastParty.show({
		"text": message,
		"bgcolor": background_colors[type],
		"color": text_colors[type],
		"gravity": _parse_gravity(gravity),
		"direction": _parse_direction(direction),
		"text_size": text_size,
		"use_font": custom_toast_font,
	})

func toast_info(message: String) -> void:
	show_toast(message, Type.INFO, _gravity, _direction, _text_size, _custom_toast_font)

func toast_success(message: String) -> void:
	show_toast(message, Type.SUCCESS, _gravity, _direction, _text_size, _custom_toast_font)

func toast_warning(message: String) -> void:
	show_toast(message, Type.WARNING, _gravity, _direction, _text_size, _custom_toast_font)

func toast_error(message: String) -> void:
	show_toast(message, Type.ERROR, _gravity, _direction, _text_size, _custom_toast_font)

static func _parse_gravity(gravity: Gravity) -> String:
	match(gravity):
		Gravity.TOP: return "top"
		Gravity.BOTTOM: return "bottom"
	assert(false, "Match case for Gravity is not exhaustive!")
	return ""

static func _parse_direction(direction: Direction) -> String:
	match(direction):
		Direction.CENTER: return "center"
		Direction.LEFT: return "left"
		Direction.RIGHT: return "right"
	assert(false, "Match case for Direction is not exhaustive!")
	return ""
