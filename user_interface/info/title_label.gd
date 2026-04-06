@tool
@icon("uid://m6jbgbc37stw")
class_name TitleLabel
extends Label

func _ready() -> void:
	text = ProjectSettings.get_setting("application/config/name")
