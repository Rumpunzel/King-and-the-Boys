@icon("uid://duyxd2niq7cle")
class_name Interaction
extends RefCounted

var source: Character
var action: Action

func _init(
	new_source: Character,
	new_action: Action,
) -> void:
	source = new_source
	action = new_action

func is_action_pressed() -> bool:
	return Input.is_action_pressed(action.input_action)

func is_action_just_pressed() -> bool:
	return Input.is_action_just_pressed(action.input_action)

func is_action_just_released() -> bool:
	return Input.is_action_just_released(action.input_action)

func get_input_events() -> Array[InputEvent]:
	return InputMap.action_get_events(action.input_action)

func get_heads_up_anchor() -> Vector3:
	var interaction_target: HitBox = get_target()
	if not interaction_target: return source.get_heads_up_anchor()
	return interaction_target.get_heads_up_anchor()

func get_target() -> HitBox:
	return null
