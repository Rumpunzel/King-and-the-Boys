@tool
class_name LobbyMenu
extends Menu

@export_group("Configuration")
@export var _title: Label
@export var _left_player_panels_container: Container
@export var _local_player_panel: LobbyPlayerPanel
@export var _right_player_panels_container: Container
@export var _local_player_character_preview: ModularCharacter
@export_file("*.tscn") var _game_scene_path: String
@export var _guest_player_panel_scene: PackedScene

var _player_panels: Dictionary[Player, LobbyPlayerPanel] = {}

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	for index: int in range(Multiplayer.MAX_CONNECTIONS):
		if index < ceili(Multiplayer.MAX_CONNECTIONS * 0.5): _create_player_panel(_left_player_panels_container)
		else: _create_player_panel(_right_player_panels_container)
	if Engine.is_editor_hint(): return
	if multiplayer.is_server(): Client.start_game()
	for player: Player in Lobby.get_connected_players():
		if player.is_host(): _title.text = "%s's Lobby" % player.player_name
		if player.is_local_player():
			_local_player_panel.player = player
			player.player_info_changed.connect(_on_local_player_info_changed)
		else: _add_player(player)
	Lobby.player_created.connect(_add_player)

func _create_player_panel(in_container: Container) -> void:
	var new_player_panel: LobbyPlayerPanel = _guest_player_panel_scene.instantiate()
	new_player_panel.player = null
	new_player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_container.add_child(new_player_panel, true)

func _add_player(player: Player) -> void:
	assert(player)
	var empty_player_info: LobbyPlayerPanel = null
	var left_player_panels: Array[LobbyPlayerPanel] = _get_player_panels(_left_player_panels_container)
	left_player_panels.reverse()
	var right_player_panels: Array[LobbyPlayerPanel] = _get_player_panels(_right_player_panels_container)
	var index: int = 0
	while not empty_player_info:
		var adjusted_index: int = floori(index * 0.5)
		var player_panel: LobbyPlayerPanel
		if index % 2 == 0: player_panel = left_player_panels[adjusted_index]
		else: player_panel = right_player_panels[adjusted_index]
		if not player_panel.player: empty_player_info = player_panel
		index += 1
	assert(empty_player_info)
	assert(empty_player_info.player == null)
	empty_player_info.player = player
	player.tree_exiting.connect(_remove_player.bind(player))
	_player_panels[player] = empty_player_info

func _remove_player(player: Player) -> void:
	assert(player)
	var player_panel_to_clear: LobbyPlayerPanel = _player_panels[player]
	player_panel_to_clear.player = null

func _get_player_panels(in_container: Container) -> Array[LobbyPlayerPanel]:
	var children: Array[Node] = in_container.get_children()
	var player_panels: Array[LobbyPlayerPanel] = []
	for child: Node in children: if child is LobbyPlayerPanel: player_panels.append(child)
	return player_panels

func _on_leave_pressed() -> void:
	if Multiplayer.is_online(): Multiplayer.leave_game()
	SceneManager.to_main(false)

func _on_disconnected_from_multiplayer() -> void:
	SceneManager.to_main(false)

func _on_local_player_info_changed() -> void:
	_local_player_character_preview.reset()
	_local_player_panel.player.character.setup_model(_local_player_character_preview)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _title: warnings.append("Missing title reference.")
	if not _left_player_panels_container: warnings.append("Missing left player infos container reference.")
	if not _local_player_panel: warnings.append("Missing local PlayerPanel reference.")
	if not _right_player_panels_container: warnings.append("Missing right player infos container reference.")
	if _game_scene_path.is_empty(): warnings.append("Missing game scene path.")
	if not _guest_player_panel_scene: warnings.append("Missing guest LobbyPlayerPanel reference.")
	return warnings
