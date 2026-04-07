@abstract
class_name GameEnvironment
extends Node

@abstract func get_player_name(player_id: int) -> String
@abstract func get_player_avatar(player_id: int) -> Texture2D

@abstract func _on_game_quit() -> void
