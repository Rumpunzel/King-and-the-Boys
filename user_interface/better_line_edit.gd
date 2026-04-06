@tool
class_name BetterLineEdit
extends LineEdit

signal text_submitted_or_focus_lost(new_text: String)

func _ready() -> void:
	text_submitted.connect(text_submitted_or_focus_lost.emit)
	focus_exited.connect(func() -> void: text_submitted_or_focus_lost.emit(text))
