@tool
@icon("uid://bec8d0jsuhm7n")
class_name PauseMenu
extends CanvasLayer

signal save_requested
signal load_requested

signal opened
signal closed

@export_group("Configuration")
@export var _save_button: Button
@export var _load_button: Button
@export var _animation_player: AnimationPlayer

var _menu_root: Control
var _tween: Tween

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	for child: Node in get_children():
		if child is Control:
			_menu_root = child
			break
	visible = get_tree().paused
	_menu_root.modulate.a = 0.0 if get_tree().paused else 1.0
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)
	Client.game_paused.connect(open_menu)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_load_button.disabled = not Serializer.has_save_file(Serializer.SAVE_FILE_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	var viewport: Viewport = get_viewport()
	if event.is_action_released("open_menu") and not visible:
		open_menu()
		viewport.set_input_as_handled()
	if not visible or viewport.is_input_handled(): return
	if event.is_action_released("close_menu"):
		close_menu()
	viewport.set_input_as_handled()

func open_menu() -> void:
	if visible: return
	get_tree().call_group("HUD", "hide")
	show()
	if _tween: _tween.kill()
	_tween = get_tree().create_tween()
	_tween.tween_property(_menu_root, "modulate:a", 1.0, 0.1)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	Client.pause_game()
	opened.emit()

func close_menu() -> void:
	if not visible: return
	Client.unpause_game()
	if _tween: _tween.kill()
	_tween = get_tree().create_tween()
	_tween.tween_property(_menu_root, "modulate:a", 0.0, 0.25)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_callback(hide)
	_tween.tween_callback(get_tree().call_group.bind("HUD", "show"))
	closed.emit()

func reset_menu() -> void:
	_save_button.disabled = false
	_load_button.disabled = false

func _on_continue_pressed() -> void:
	close_menu()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_load_pressed() -> void:
	load_requested.emit()

func _on_quit_confirmation_dialog_confirmed() -> void:
	save_requested.emit()
	Client.quit_game()

# [Multiplayer] callbacks
func _on_joining_multiplayer() -> void:
	close_menu()
	_save_button.disabled = true
	_load_button.disabled = true

func _on_disconnected_from_multiplayer() -> void:
	reset_menu()

# [Serializer] callbacks
func _on_saving_finished() -> void:
	_load_button.disabled = not Serializer.has_save_file(Serializer.SAVE_FILE_PATH)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _save_button: warnings.append("Missing save button reference.")
	if not _load_button: warnings.append("Missing load button reference.")
	if not _animation_player: warnings.append("Missing AnimationPlayer reference.")
	return warnings
