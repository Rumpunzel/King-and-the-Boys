@tool
@icon("uid://bec8d0jsuhm7n")
class_name PauseMenu
extends Menu

signal save_requested
signal load_requested

@export_group("Configuration")
@export var _save_button: Button
@export var _load_button: Button

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	visible = get_tree().paused
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

func reset_menu() -> void:
	_save_button.disabled = false
	_load_button.disabled = false

func _on_continue_pressed() -> void:
	close_menu()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_load_pressed() -> void:
	load_requested.emit()

func _on_main_menu_pressed() -> void:
	save_requested.emit()
	SceneManager.to_main()

func _on_quit_confirmation_dialog_confirmed() -> void:
	save_requested.emit()
	Client.quit_game()

func _on_opened() -> void:
	Client.pause_game()

func _on_closed() -> void:
	Client.unpause_game()

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
	return warnings
