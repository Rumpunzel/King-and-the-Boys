@tool
@icon("uid://r4re5w2nnw4h")
class_name LobbyMenu
extends Menu

## The heroes players pick from in this lobby, see [member Lobby.hero_roster]
@export var _hero_roster: HeroRoster

@export_group("Configuration")
@export var _title: Label
@export var _left_player_panels_container: Container
@export var _local_player_panel: LobbyPlayerPanel
@export var _right_player_panels_container: Container
## Lets the local player pick a hero
@export var _hero_picker: HeroPicker
## Shows the local player's hero
@export var _hero_stats: HeroStats
## Where the local player's character stands. Models are built from the chosen profiles, so dwarves show as dwarves
@export var _character_preview: Node3D
## Where other players' characters stand, below their portraits: one per player panel, the left panels' first, then the right ones'
@export var _other_character_spots: Array[Node3D]
@export_file("*.tscn") var _game_scene_path: String
@export var _guest_player_panel_scene: PackedScene

var _player_panels: Dictionary[Player, LobbyPlayerPanel] = {}
## Each player's character model and the profile it was built from
var _preview_models: Dictionary[Player, Model] = {}
var _preview_profiles: Dictionary[Player, CharacterProfile] = {}
## The body each player's model was last dressed with
var _preview_bodies: Dictionary[Player, Dictionary] = {}
## Where the model of the player shown by a panel stands
var _panel_spots: Dictionary[LobbyPlayerPanel, Node3D] = {}

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	# Before the local player is created (_ready), so the host gives it a hero as it spawns
	Lobby.hero_roster = _hero_roster
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _ready() -> void:
	for index: int in range(Multiplayer.MAX_CONNECTIONS):
		var panel: LobbyPlayerPanel
		if index < ceili(Multiplayer.MAX_CONNECTIONS * 0.5): panel = _create_player_panel(_left_player_panels_container)
		else: panel = _create_player_panel(_right_player_panels_container)
		if index < _other_character_spots.size(): _panel_spots[panel] = _other_character_spots[index]
	if Engine.is_editor_hint(): return
	if multiplayer.is_server(): Client.start_game()
	for player: Player in Lobby.get_connected_players():
		if player.is_host(): _title.text = "%s's Lobby" % player.player_name
		if player.is_local_player():
			_local_player_panel.player = player
			_hero_picker.player = player
			player.player_info_changed.connect(_update_preview.bind(player))
			player.player_info_changed.connect(_show_local_hero.bind(player))
			_update_preview(player)
			_show_local_hero(player)
		else: _add_player(player)
	Lobby.player_created.connect(_add_player)

## Other player info (name, avatar, ready) leaves the stats be
func _show_local_hero(player: Player) -> void:
	if _hero_stats.character != player.character: _hero_stats.character = player.character

func _create_player_panel(in_container: Container) -> LobbyPlayerPanel:
	var new_player_panel: LobbyPlayerPanel = _guest_player_panel_scene.instantiate()
	new_player_panel.player = null
	new_player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_container.add_child(new_player_panel, true)
	return new_player_panel

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
	player.player_info_changed.connect(_update_preview.bind(player))
	_update_preview(player)

func _remove_player(player: Player) -> void:
	assert(player)
	var player_panel_to_clear: LobbyPlayerPanel = _player_panels[player]
	player_panel_to_clear.player = null
	player_panel_to_clear.get_character_panel().set_portrait_shown(true)
	_player_panels.erase(player)
	var model: Model = _preview_models.get(player)
	if model: model.queue_free()
	_preview_models.erase(player)
	_preview_profiles.erase(player)
	_preview_bodies.erase(player)

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

## Rebuilds a player's model when they chose another profile, as profiles may use other bodies, and dresses it when its body changed;
## other player info (name, avatar, ready) leaves it be
func _update_preview(player: Player) -> void:
	var profile: CharacterProfile = player.character
	var model: Model = _preview_models.get(player)
	if profile != _preview_profiles.get(player):
		_preview_profiles[player] = profile
		_preview_bodies.erase(player)
		if model: model.queue_free()
		model = profile.create_model(0) if profile else null
		_preview_models[player] = model
		if model:
			model.position = profile.preview_offset
			var spot: Node3D = _character_preview
			if _player_panels.has(player): spot = _panel_spots.get(_player_panels[player], _character_preview)
			spot.add_child(model)
			# Shows off as it is picked, on every peer
			if profile.selected_animation: model.play_body_animation(profile.selected_animation)
		# The model stands where the portrait was
		if _player_panels.has(player): _player_panels[player].get_character_panel().set_portrait_shown(model == null)
	if not model is ModularModel: return
	# Each player's own look, as they rolled it; it is used in game as well. Character and body reach peers one after the other,
	# so a body of the previous character waits until the new one arrives
	var modular_model: ModularModel = model
	var body: Dictionary = player.body if modular_model.is_complete_body(player.body) else {}
	if _preview_bodies.has(player) and _preview_bodies[player] == body: return
	_preview_bodies[player] = body.duplicate()
	profile.dress_model(modular_model, body)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _hero_roster: warnings.append("Missing hero roster.")
	if not _title: warnings.append("Missing title reference.")
	if not _left_player_panels_container: warnings.append("Missing left player infos container reference.")
	if not _local_player_panel: warnings.append("Missing local PlayerPanel reference.")
	if not _right_player_panels_container: warnings.append("Missing right player infos container reference.")
	if not _hero_picker: warnings.append("Missing HeroPicker reference.")
	if not _hero_stats: warnings.append("Missing HeroStats reference.")
	if not _character_preview: warnings.append("Missing character preview reference.")
	if _other_character_spots.size() < Multiplayer.MAX_CONNECTIONS: warnings.append("Missing a spot for each other player's character.")
	if _game_scene_path.is_empty(): warnings.append("Missing game scene path.")
	if not _guest_player_panel_scene: warnings.append("Missing guest LobbyPlayerPanel reference.")
	return warnings
