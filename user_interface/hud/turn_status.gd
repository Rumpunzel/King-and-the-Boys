@tool
class_name TurnStatus
extends PanelContainer
## Shows the turn number, the movement points left, the controls and who has passed

@export var character: Character

@export_group("Configuration")
@export var _label: Label

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	assert(turn_manager)
	turn_manager.turn_started.connect(_update.unbind(1))
	turn_manager.passed_players_changed.connect(_update)
	character.movement_points_changed.connect(_update.unbind(1))
	Lobby.player_connected.connect(_update.unbind(1))
	Lobby.player_disconnected.connect(_update.unbind(1))
	_update()

func _update() -> void:
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	if not turn_manager: return
	var lines: PackedStringArray = [
		"Turn %d" % turn_manager.turn_number,
		"Moves left: %d / %d" % [maxi(character.movement_points, 0), character.profile.speed],
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

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not character: warnings.append("Missing Character reference.")
	if not _label: warnings.append("Missing Label reference.")
	return warnings
