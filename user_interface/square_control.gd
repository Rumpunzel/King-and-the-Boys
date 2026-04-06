@tool
@icon("uid://c7p5uid5l5mki")
class_name SquareControl
extends Control

func _ready() -> void:
	_on_resized()
	resized.connect(_on_resized)

func _on_resized() -> void:
	if size.x == size.y: return
	var longest_side: float = max(size.x, size.y)
	custom_minimum_size = Vector2(longest_side, longest_side)
