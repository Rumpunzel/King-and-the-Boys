@tool
class_name LobbyMenu
extends PanelContainer

@export_group("Configuration")
@export var _player_infos_container: Control
@export var _player_info_scene: PackedScene

var _player_infos: Dictionary[Player, PlayerInfo] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.connect(open_menu)
	Multiplayer.disconnected_from_multiplayer.connect(close_menu)
	Lobby.player_connected.connect(create_player_info)

func _ready() -> void:
	if Engine.is_editor_hint():
		create_player_info(Player.create(1, "Player"))
		return
	visible = Multiplayer.is_online()
	var connected_players: Array[Player] = Lobby.get_connected_players()
	for connected_player: Player in connected_players:
		create_player_info(connected_player)

func open_menu() -> void:
	if is_visible_in_tree(): return
	show()

func close_menu() -> void:
	if not is_visible_in_tree(): return
	hide()

func create_player_info(player: Player) -> void:
	assert(player)
	var new_player_info: PlayerInfo = _player_info_scene.instantiate()
	new_player_info.player = player
	player.tree_exiting.connect(remove_player_info.bind(player))
	_player_infos[player] = new_player_info
	_player_infos_container.add_child(new_player_info, true)

func remove_player_info(player: Player) -> void:
	var player_info_to_remove: PlayerInfo = _player_infos[player]
	_player_infos.erase(player)
	player_info_to_remove.queue_free()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_infos_container: warnings.append("Missing player infos container.")
	if not _player_info_scene: warnings.append("Missing PlayerInfo reference.")
	return warnings
