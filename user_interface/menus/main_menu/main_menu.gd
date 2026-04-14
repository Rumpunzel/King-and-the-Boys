@tool
@icon("uid://bgjmcb04v358t")
class_name MainMenu
extends Menu

signal game_requested

@export_group("Configuration")

func start_new_game() -> void:
	assert(multiplayer.is_server())
	close_menu()
	game_requested.emit()
	print_debug("Starting new game...")

func load_game() -> Error:
	assert(multiplayer.is_server())
	close_menu()
	print_debug("Loading game...")
	return Error.OK#error

func _on_start_pressed() -> void:
	start_new_game()

func _on_load_pressed() -> void:
	load_game()

func _on_quit_confirmation_dialog_confirmed() -> void:
	Client.quit_game()

func _on_game_status_changed(new_game_status: Game.GameStatus) -> void:
	if new_game_status == Game.GameStatus.NONE: open_menu()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
