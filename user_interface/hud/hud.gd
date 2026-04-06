@icon("uid://bigo28m2mor2y")
class_name HUD
extends CanvasLayer

func _ready() -> void:
	if not is_multiplayer_authority():
		hide()

func update_available_interactions(available_interactions: Array[Interaction]) -> void:
	_clear_all_input_prompts()
	for available_interaction: Interaction in available_interactions:
		var input_prompt_for_interaction: InputPrompt = InputPrompt.create(available_interaction)
		add_child(input_prompt_for_interaction)

func _clear_all_input_prompts() -> void:
	for input_prompt: InputPrompt in get_children():
		input_prompt.hide_prompt()

func _on_available_interactions_changed(available_interactions: Array[Interaction]) -> void:
	update_available_interactions(available_interactions)
