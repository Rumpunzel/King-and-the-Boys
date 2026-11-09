@tool
class_name LobbyMenu
extends Menu

@export_group("Configuration")
@export var _title: Label
@export var _left_player_panels_container: Container
@export var _local_player_panel: LobbyPlayerPanel
@export var _right_player_panels_container: Container
## Where the local player's character stands; other players' characters stand at the same depth and floor, below their
## portraits. Models are built from the chosen profiles, so dwarves show as dwarves
@export var _character_preview: Node3D
## How much further from the camera other players' characters stand than the local one, in metres
@export var _other_characters_depth: float = 0.5
@export_file("*.tscn") var _game_scene_path: String
@export var _guest_player_panel_scene: PackedScene

var _player_panels: Dictionary[Player, LobbyPlayerPanel] = {}
## Each player's character model and the profile it was built from
var _preview_models: Dictionary[Player, Model] = {}
var _preview_profiles: Dictionary[Player, CharacterProfile] = {}
## Where other players' models stand, moved below their portraits every frame
var _preview_anchors: Dictionary[Player, Node3D] = {}

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
			player.player_info_changed.connect(_update_preview.bind(player))
			_update_preview(player)
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
	var anchor: Node3D = Node3D.new()
	_character_preview.add_sibling(anchor)
	_preview_anchors[player] = anchor
	player.player_info_changed.connect(_update_preview.bind(player))
	_update_preview(player)

func _remove_player(player: Player) -> void:
	assert(player)
	var player_panel_to_clear: LobbyPlayerPanel = _player_panels[player]
	player_panel_to_clear.player = null
	player_panel_to_clear.get_character_panel().set_portrait_shown(true)
	_player_panels.erase(player)
	_preview_models.erase(player)
	_preview_profiles.erase(player)
	if _preview_anchors.has(player): _preview_anchors[player].queue_free()
	_preview_anchors.erase(player)

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _preview_anchors.is_empty(): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera: return
	var depth: float = (_character_preview.global_position - camera.global_position).dot(-camera.global_basis.z) + _other_characters_depth
	for player: Player in _preview_anchors:
		var anchor: Node3D = _preview_anchors[player]
		var below_portrait: Vector3 = camera.project_position(_player_panels[player].get_character_panel().get_portrait_screen_center(), depth)
		anchor.global_basis = _character_preview.global_basis
		anchor.global_position = Vector3(below_portrait.x, _character_preview.global_position.y, below_portrait.z)

## Rebuilds a player's model when they chose another profile, as profiles may use other bodies
func _update_preview(player: Player) -> void:
	var profile: CharacterProfile = player.character
	var model: Model = _preview_models.get(player)
	if profile != _preview_profiles.get(player):
		_preview_profiles[player] = profile
		if model: model.queue_free()
		model = profile.create_model(0) if profile else null
		_preview_models[player] = model
		if model:
			model.position = model.preview_offset
			var anchor: Node3D = _preview_anchors.get(player, _character_preview)
			anchor.add_child(model)
		# The model stands where the portrait was
		if _player_panels.has(player): _player_panels[player].get_character_panel().set_portrait_shown(model == null)
	if not model is ModularModel: return
	# Each player's own look, as they rolled it; it is used in game as well. Character and body reach peers one after the other,
	# so a body of the previous character waits until the new one arrives
	var modular_model: ModularModel = model
	profile.dress_model(modular_model, player.body if modular_model.is_complete_body(player.body) else {})

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _title: warnings.append("Missing title reference.")
	if not _left_player_panels_container: warnings.append("Missing left player infos container reference.")
	if not _local_player_panel: warnings.append("Missing local PlayerPanel reference.")
	if not _right_player_panels_container: warnings.append("Missing right player infos container reference.")
	if not _character_preview: warnings.append("Missing character preview reference.")
	if _game_scene_path.is_empty(): warnings.append("Missing game scene path.")
	if not _guest_player_panel_scene: warnings.append("Missing guest LobbyPlayerPanel reference.")
	return warnings
