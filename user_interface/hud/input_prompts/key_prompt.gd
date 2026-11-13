@tool
@icon("uid://cime7w536lpdm")
class_name KeyPrompt
extends Button

# Loaded on use: a preload would load the scene, which uses this script, while the script is still loading
const KEY_PROMPT_SCENE_PATH: String = "uid://bgqwt7hjsgn3o"

var input_event_key: InputEventKey:
	set(new_input_event_key):
		assert(new_input_event_key)
		input_event_key = new_input_event_key
		var localized_keycode: Key = DisplayServer.keyboard_get_label_from_physical(input_event_key.physical_keycode)
		text = OS.get_keycode_string(localized_keycode)

static func create(for_input_event_key: InputEventKey) -> KeyPrompt:
	assert(for_input_event_key)
	var new_key_prompt: KeyPrompt = (load(KEY_PROMPT_SCENE_PATH) as PackedScene).instantiate()
	new_key_prompt.input_event_key = for_input_event_key
	return new_key_prompt

func _on_resized() -> void:
	var new_side: float = max(size.x, size.y)
	size = Vector2(new_side, new_side)
