class_name Menus
extends Menu

func _on_game_status_changed(new_game_status: Game.GameStatus) -> void:
	if visible and new_game_status == Game.GameStatus.RUNNING: close_menu()
