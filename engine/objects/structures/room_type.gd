@tool
@icon("uid://5w8hyoyx7uqy")
class_name RoomType
extends Resource

@export var name: String
@export var color: Color = Color.MAROON

func _to_string() -> String:
	return "<%s>" % name
