@tool
class_name TurnStatus
extends PanelContainer
## The local player's turn: the other players' turns, auto-pass, undo and pass buttons and the moves of the character
## the local player controls. The buttons only ask the local [PlayerGhost]; the rules live there and in [TurnManager].

@export var _player_ghost_spawner: PlayerGhostSpawner
@export var _turn_manager: TurnManager

@export_group("Configuration")
@export var _label: Label
@export var _other_players: Container
@export var _auto_pass_toggle: CheckBox
@export var _undo_button: Button
@export var _pass_button: ToggleButton
@export var _moves_bar: MovesBar
@export var _player_turn_status_scene: PackedScene

var _player_ghost: PlayerGhost
# Player id -> row of another player
var _player_rows: Dictionary[int, PlayerTurnStatus] = {}

var _character: Character:
	set(new_character):
		if is_instance_valid(_character):
			_character.movement_points_changed.disconnect(_on_character_turn_changed)
			_character.undo_steps_changed.disconnect(_on_character_turn_changed)
		_character = new_character
		_character.movement_points_changed.connect(_on_character_turn_changed)
		_character.undo_steps_changed.connect(_on_character_turn_changed)
		_moves_bar.character = _character
		_update()


func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Shown once the local player's ghost exists
	hide()
	assert(_player_ghost_spawner)
	assert(_turn_manager)
	# The buttons show the keys of their actions
	_undo_button.text = _with_key_hint(_undo_button.text, &"undo_move")
	_pass_button.untoggled_text = _with_key_hint(_pass_button.untoggled_text, &"end_turn")
	_turn_manager.turn_started.connect(_update.unbind(1))
	_turn_manager.passed_players_changed.connect(_update)
	Lobby.player_disconnected.connect(_on_player_disconnected)
	_player_ghost_spawner.player_ghost_created.connect(_on_player_ghost_created)
	_auto_pass_toggle.toggled.connect(_on_auto_pass_toggled)
	_undo_button.pressed.connect(_on_undo_pressed)
	_pass_button.toggled.connect(_on_pass_toggled)

func _update() -> void:
	if not is_instance_valid(_player_ghost) or not is_instance_valid(_character): return
	_label.text = "Turn %d" % _turn_manager.turn_number
	_undo_button.disabled = not _player_ghost.can_undo()
	# Nothing left to do: the player passes either way, and can not take it back
	var must_pass: bool = _player_ghost.must_pass()
	_pass_button.set_pressed_no_signal(must_pass or _player_ghost.has_passed())
	_pass_button.update_button()
	_pass_button.disabled = must_pass
	for player_id: int in _player_rows: _player_rows[player_id].show_passed(_turn_manager.has_passed(player_id))

## @returns [param text] without a key hint in brackets, followed by the current key of [param action]
static func _with_key_hint(text: String, action: StringName) -> String:
	return "%s [%s]" % [text.get_slice("[", 0).strip_edges(), _get_action_key(action)]

static func _get_action_key(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty(): return "?"
	var event: InputEvent = events.front()
	var key_event: InputEventKey = event as InputEventKey
	if not key_event: return event.as_text()
	# Headless (tests, servers) has no keyboard layout
	if DisplayServer.get_name() == "headless": return OS.get_keycode_string(key_event.physical_keycode)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode))

func _add_player_row(player_ghost: PlayerGhost) -> void:
	var row: PlayerTurnStatus = _player_turn_status_scene.instantiate()
	row.player = player_ghost.player
	row.character = player_ghost.character
	_other_players.add_child(row)
	_player_rows[player_ghost.player.player_id] = row
	player_ghost.tree_exiting.connect(_remove_player_row.bind(player_ghost.player.player_id))
	_update()

func _remove_player_row(player_id: int) -> void:
	if not _player_rows.has(player_id): return
	_player_rows[player_id].queue_free()
	_player_rows.erase(player_id)

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	if not player_ghost.player.is_local_player():
		_add_player_row(player_ghost)
		return
	_player_ghost = player_ghost
	_player_ghost.controlled_character_changed.connect(_on_controlled_character_changed)
	_player_ghost.auto_pass = _auto_pass_toggle.button_pressed
	_character = _player_ghost.get_controlled_character()
	show()

func _on_player_disconnected(player: Player) -> void:
	_remove_player_row(player.player_id)
	_update()

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_character = controlled_character

func _on_character_turn_changed(_value: int) -> void:
	_update()

func _on_auto_pass_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_player_ghost): _player_ghost.auto_pass = toggled_on

func _on_undo_pressed() -> void:
	if is_instance_valid(_player_ghost): _player_ghost.request_undo()

func _on_pass_toggled(toggled_on: bool) -> void:
	# The button shows the pass at once; the host's answer updates it (see _update)
	if is_instance_valid(_player_ghost): _player_ghost.request_pass(toggled_on)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	if not _turn_manager: warnings.append("Missing TurnManager reference.")
	if not _label: warnings.append("Missing Label reference.")
	if not _other_players: warnings.append("Missing other players Container reference.")
	if not _auto_pass_toggle: warnings.append("Missing auto pass CheckBox reference.")
	if not _undo_button: warnings.append("Missing undo Button reference.")
	if not _pass_button: warnings.append("Missing pass ToggleButton reference.")
	if not _moves_bar: warnings.append("Missing MovesBar reference.")
	if not _player_turn_status_scene: warnings.append("Missing PlayerTurnStatus scene.")
	return warnings
