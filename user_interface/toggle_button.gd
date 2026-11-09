@tool
class_name ToggleButton
extends Button

@export_multiline var toggled_text: String
@export var toggled_icon: Texture

## Text while not toggled; set this rather than [member Button.text], which shows the current state
@onready var untoggled_text: String = text:
	set(new_untoggled_text):
		untoggled_text = new_untoggled_text
		# Not while the onready values are still being set: the icon is not stored yet
		if is_node_ready(): update_button()
@onready var _untoggled_icon: Texture = icon

func _ready() -> void:
	toggle_mode = true
	toggled.connect(_on_toggled)

func update_button() -> void:
	text = toggled_text if button_pressed else untoggled_text
	icon = toggled_icon if button_pressed else _untoggled_icon

func _on_toggled(_toggled_on: bool) -> void:
	update_button()
