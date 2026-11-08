@tool
class_name TurnStatus
extends PanelContainer
## Shows the turn number, the moves left of the character the local player controls, the controls and who has passed.
## The auto-pass toggle switches [member PlayerGhost.auto_pass] of the local player.

@export_group("Configuration")
@export var _player_ghost_spawner: PlayerGhostSpawner
@export var _label: Label
@export var _auto_pass_toggle: CheckBox

var _player_ghost: PlayerGhost

var _character: Character:
	set(new_character):
		if is_instance_valid(_character): _character.movement_points_changed.disconnect(_on_movement_points_changed)
		_character = new_character
		_character.movement_points_changed.connect(_on_movement_points_changed)
		_update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Shown once the local player's ghost exists
	hide()
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	assert(turn_manager)
	turn_manager.turn_started.connect(_update.unbind(1))
	turn_manager.passed_players_changed.connect(_update)
	Lobby.player_connected.connect(_update.unbind(1))
	Lobby.player_disconnected.connect(_update.unbind(1))
	_player_ghost_spawner.player_ghost_created.connect(_on_player_ghost_created)
	_auto_pass_toggle.toggled.connect(_on_auto_pass_toggled)

func _update() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager or not is_instance_valid(_character): return
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

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	if not player_ghost.player.is_local_player(): return
	_player_ghost = player_ghost
	_player_ghost.controlled_character_changed.connect(_on_controlled_character_changed)
	_player_ghost.auto_pass = _auto_pass_toggle.button_pressed
	_character = _player_ghost.get_controlled_character()
	show()

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_character = controlled_character

func _on_movement_points_changed(_movement_points: int) -> void:
	_update()

func _on_auto_pass_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_player_ghost): _player_ghost.auto_pass = toggled_on

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_ghost_spawner: warnings.append("Missing PlayerGhostSpawner reference.")
	if not _label: warnings.append("Missing Label reference.")
	if not _auto_pass_toggle: warnings.append("Missing auto pass CheckBox reference.")
	return warnings
