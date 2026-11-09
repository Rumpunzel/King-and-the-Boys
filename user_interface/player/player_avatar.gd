@tool
class_name PlayerAvatar
extends TextureRect
## Shows a player's avatar (e.g. from Steam) and follows changes; keeps its placeholder texture until there is one

@export var player: Player:
	set(new_player):
		if player and player.player_info_changed.is_connected(_update): player.player_info_changed.disconnect(_update)
		player = new_player
		if not player or Engine.is_editor_hint(): return
		player.player_info_changed.connect(_update)
		_update()

@onready var _placeholder: Texture2D = texture

func _ready() -> void:
	if player: _update()

func _update() -> void:
	if not is_node_ready(): return
	texture = player.player_avatar if player.player_avatar else _placeholder
