@tool
@icon("uid://bkxn2uupbbt34")
class_name InputReader
extends Node
## Collects the local player's interaction input (interact, take or release control) every frame; replicated, so the
## host sees it too

var interaction_input: StringName = ""

func _ready() -> void:
	if Engine.is_editor_hint(): return
	set_process(is_multiplayer_authority())
	if not is_multiplayer_authority(): return
	# Only collect input if this is the local [Player]
	_collect_input()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	assert(is_multiplayer_authority())
	# Only collect input if this is the local [Player]
	_collect_input()

func _collect_input() -> void:
	interaction_input = ""
	if Input.is_action_pressed("interact"): interaction_input = "interact"
	elif Input.is_action_pressed("take_control"): interaction_input = "take_control"
	elif Input.is_action_pressed("release_control"): interaction_input = "release_control"
