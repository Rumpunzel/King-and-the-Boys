@tool
class_name Menus
extends Menu

@export var _pause_menu: PauseMenu

func _on_pause_menu_opened() -> void: open_menu()
func _on_pause_menu_closed() -> void: close_menu()

func _on_game_status_changed(new_game_status: Game.GameStatus) -> void:
	if new_game_status == Game.GameStatus.NONE:
		open_menu()
		assert(_pause_menu)
		_pause_menu.opened.disconnect(_on_pause_menu_opened)
		_pause_menu.closed.disconnect(_on_pause_menu_closed)
	elif new_game_status == Game.GameStatus.RUNNING:
		close_menu()
		assert(_pause_menu)
		_pause_menu.opened.connect(_on_pause_menu_opened)
		_pause_menu.closed.connect(_on_pause_menu_closed)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _pause_menu: warnings.append("Missing PauseMenu reference.")
	return warnings
