@tool
@icon("uid://cmbhx5v0d8ri8")
class_name TurnStatus
extends PanelContainer
## The local player's turn: the other players' turns, auto-pass, undo and pass buttons and the moves and abilities of
## the character the local player controls. The buttons only ask the local [PlayerController]; the rules live there and in [TurnManager].

@export var _player_controller_spawner: PlayerControllerSpawner
@export var _turn_manager: TurnManager

@export_group("Configuration")
@export var _label: Label
@export var _other_players: Container
@export var _auto_pass_toggle: CheckBox
@export var _undo_button: Button
@export var _pass_button: ToggleButton
@export var _moves_bar: MovesBar
@export var _ability_bar: AbilityBar
@export var _player_turn_status_scene: PackedScene

var _player_controller: PlayerController
# Player id -> row of another player
var _player_rows: Dictionary[int, PlayerTurnStatus] = {}

var _character: Character:
	set(new_character):
		if is_instance_valid(_character):
			_character.movement_points_changed.disconnect(_on_character_turn_changed)
			_character.undo_steps_changed.disconnect(_on_character_turn_changed)
			_character.active_ability_changed.disconnect(_update)
			_character.ability_uses_changed.disconnect(_update)
		_character = new_character
		_character.movement_points_changed.connect(_on_character_turn_changed)
		_character.undo_steps_changed.connect(_on_character_turn_changed)
		_character.active_ability_changed.connect(_update)
		_character.ability_uses_changed.connect(_update)
		_moves_bar.character = _character
		_ability_bar.player_controller = _player_controller
		_ability_bar.character = _character
		_update()


func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Shown once the local player's controller exists
	hide()
	assert(_player_controller_spawner)
	assert(_turn_manager)
	# The buttons show the keys of their actions
	_undo_button.text = _with_key_hint(_undo_button.text, &"undo_move")
	_pass_button.untoggled_text = _with_key_hint(_pass_button.untoggled_text, &"end_turn")
	_turn_manager.turn_started.connect(_update.unbind(1))
	_turn_manager.passed_players_changed.connect(_update)
	Lobby.player_disconnected.connect(_on_player_disconnected)
	_player_controller_spawner.player_controller_created.connect(_on_player_controller_created)
	_auto_pass_toggle.toggled.connect(_on_auto_pass_toggled)
	_undo_button.pressed.connect(_on_undo_pressed)
	_pass_button.toggled.connect(_on_pass_toggled)

func _update() -> void:
	if not is_instance_valid(_player_controller) or not is_instance_valid(_character): return
	_label.text = "Turn %d" % _turn_manager.turn_number
	_undo_button.disabled = not _player_controller.can_undo()
	# Nothing left to do: the player passes either way, and can not take it back
	var must_pass: bool = _player_controller.must_pass()
	_pass_button.set_pressed_no_signal(must_pass or _player_controller.has_passed())
	_pass_button.update_button()
	_pass_button.disabled = must_pass
	for player_id: int in _player_rows: _player_rows[player_id].show_passed(_turn_manager.has_passed(player_id))
	_ability_bar.update()

## @returns [param text] without a key hint in brackets, followed by the current key of [param action]
static func _with_key_hint(text: String, action: StringName) -> String:
	return "%s [%s]" % [text.get_slice("[", 0).strip_edges(), get_action_key(action)]

## @returns the label of the first keyboard key of [param action] on this keyboard
static func get_action_key(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty(): return "?"
	# Keys first: the move actions list a joypad axis before their keys
	var key_event: InputEventKey = null
	for event: InputEvent in events:
		key_event = event as InputEventKey
		if key_event: break
	if not key_event: return events[0].as_text()
	# Headless (tests, servers) has no keyboard layout
	if DisplayServer.get_name() == "headless": return OS.get_keycode_string(key_event.physical_keycode)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode))

func _add_player_row(player_controller: PlayerController) -> void:
	var row: PlayerTurnStatus = _player_turn_status_scene.instantiate()
	row.player = player_controller.player
	row.character = player_controller.character
	_other_players.add_child(row)
	_player_rows[player_controller.player.player_id] = row
	player_controller.tree_exiting.connect(_remove_player_row.bind(player_controller.player.player_id))
	_update()

func _remove_player_row(player_id: int) -> void:
	if not _player_rows.has(player_id): return
	_player_rows[player_id].queue_free()
	_player_rows.erase(player_id)

func _on_player_controller_created(player_controller: PlayerController) -> void:
	if not player_controller.player.is_local_player():
		_add_player_row(player_controller)
		return
	_player_controller = player_controller
	_player_controller.controlled_character_changed.connect(_on_controlled_character_changed)
	_player_controller.auto_pass = _auto_pass_toggle.button_pressed
	_character = _player_controller.get_controlled_character()
	show()

func _on_player_disconnected(player: Player) -> void:
	_remove_player_row(player.player_id)
	_update()

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_character = controlled_character

func _on_character_turn_changed(_value: int) -> void:
	_update()

func _on_auto_pass_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_player_controller): _player_controller.auto_pass = toggled_on

func _on_undo_pressed() -> void:
	if is_instance_valid(_player_controller): _player_controller.request_undo()

func _on_pass_toggled(toggled_on: bool) -> void:
	# The button shows the pass at once; the host's answer updates it (see _update)
	if is_instance_valid(_player_controller): _player_controller.request_pass(toggled_on)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_controller_spawner: warnings.append("Missing PlayerControllerSpawner reference.")
	if not _turn_manager: warnings.append("Missing TurnManager reference.")
	if not _label: warnings.append("Missing Label reference.")
	if not _other_players: warnings.append("Missing other players Container reference.")
	if not _auto_pass_toggle: warnings.append("Missing auto pass CheckBox reference.")
	if not _undo_button: warnings.append("Missing undo Button reference.")
	if not _pass_button: warnings.append("Missing pass ToggleButton reference.")
	if not _moves_bar: warnings.append("Missing MovesBar reference.")
	if not _ability_bar: warnings.append("Missing AbilityBar reference.")
	if not _player_turn_status_scene: warnings.append("Missing PlayerTurnStatus scene.")
	return warnings
