@tool
@icon("uid://k8xnriynpwgn")
class_name PlayerName
extends Label
## Shows a player's name and follows changes

@export var player: Player:
	set(new_player):
		if player and player.player_info_changed.is_connected(_update): player.player_info_changed.disconnect(_update)
		player = new_player
		if not player or Engine.is_editor_hint(): return
		player.player_info_changed.connect(_update)
		_update()

func _update() -> void:
	text = player.player_name
