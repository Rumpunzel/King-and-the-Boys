extends Toaster

func _on_game_hosted(_ip_address: StringName, _port: int) -> void:
	toast_success("Game hosted!")

func _on_game_joined(host_player_info: Dictionary) -> void:
	Player.validate_player_info(host_player_info)
	toast_success("Joined %s's game!" % host_player_info[Player.NAME])

func _on_player_joined(player: Player) -> void:
	toast_success("%s joined!" % player.player_name)

func _on_player_disconnected(player: Player) -> void:
	toast_warning("%s left!" % player.player_name)
