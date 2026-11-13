@icon("uid://bn8jblme2siv6")
class_name Action
extends Resource

@export var name: String
@export var input_action: String = "interact"
## If [code]=0[/code] will execture immediately
@export_range(0.0, 10.0, 0.1) var charge_time: float = 0.0
