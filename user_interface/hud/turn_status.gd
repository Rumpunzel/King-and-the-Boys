@tool
class_name TurnStatus
extends PanelContainer
## Shows the turn number, the movement points left of the controlled [Character], the controls and who has passed.
## Optionally passes on its own once the controlled [Character] is out of moves and has no step to undo.

@export_group("Configuration")
@export var _state_machine: PlayerStateMachine
@export var _label: Label
@export var _auto_pass_toggle: CheckBox

var _character: Character:
	set(new_character):
		if _character:
			_character.movement_points_changed.disconnect(_on_movement_points_changed)
			_character.undo_steps_changed.disconnect(_on_undo_steps_changed)
		_character = new_character
		_character.movement_points_changed.connect(_on_movement_points_changed)
		_character.undo_steps_changed.connect(_on_undo_steps_changed)
		_update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	assert(turn_manager)
	turn_manager.turn_started.connect(_update.unbind(1))
	turn_manager.passed_players_changed.connect(_update)
	Lobby.player_connected.connect(_update.unbind(1))
	Lobby.player_disconnected.connect(_update.unbind(1))
	_state_machine.controlled_character_changed.connect(_on_controlled_character_changed)
	_auto_pass_toggle.toggled.connect(_on_auto_pass_toggled)
	_character = _state_machine.get_controlled_character()

func _update() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or not _character: return
	var lines: PackedStringArray = [
		"Turn %d" % turn_manager.turn_number,
		"Moves left: %d / %d" % [maxi(_character.movement_points, 0), _character.profile.speed],
		"[%s] undo   [%s] end turn" % [_get_action_key("undo_move"), _get_action_key("end_turn")],
	]
	for player: Player in Lobby.get_connected_players():
		var mark: String = "passed" if turn_manager.has_passed(player.player_id) else "moving"
		lines.append("%s: %s" % [player.player_name, mark])
	_label.text = "\n".join(lines)

static func _get_action_key(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty(): return "?"
	var event: InputEvent = events.front()
	var key_event: InputEventKey = event as InputEventKey
	if not key_event: return event.as_text()
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode))

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_character = controlled_character
	_auto_pass_if_out_of_moves()

func _on_movement_points_changed(_movement_points: int) -> void:
	_update()
	_auto_pass_if_out_of_moves()

func _on_undo_steps_changed(_undo_steps: int) -> void:
	_auto_pass_if_out_of_moves()

func _on_auto_pass_toggled(_toggled_on: bool) -> void:
	_auto_pass_if_out_of_moves()

func _auto_pass_if_out_of_moves() -> void:
	# Every ghost carries a HUD; only the local player's one may pass for them
	if not _state_machine.player_ghost.is_multiplayer_authority(): return
	# Only when nothing is left to do: no moves, and no step to take back
	if not _auto_pass_toggle.button_pressed or _character.movement_points != 0 or _character.undo_steps > 0: return
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or turn_manager.has_passed(multiplayer.get_unique_id()): return
	turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, true)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _state_machine: warnings.append("Missing PlayerStateMachine reference.")
	if not _label: warnings.append("Missing Label reference.")
	if not _auto_pass_toggle: warnings.append("Missing auto pass CheckBox reference.")
	return warnings
