@tool
class_name Menus
extends Menu

@export_group("Configuration")

var _game_status: Game.GameStatus

func _on_game_status_changed(new_game_status: Game.GameStatus) -> void:
	_game_status = new_game_status
	if new_game_status == Game.GameStatus.RUNNING: close_menu()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings

func _on_menu_opened() -> void:
	open_menu()

func _on_pause_menu_closed() -> void:
	if _game_status != Game.GameStatus.RUNNING: return
	close_menu()
