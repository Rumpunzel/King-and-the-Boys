@tool
@icon("uid://cmbhx5v0d8ri8")
class_name AbilityBar
extends VBoxContainer
## The abilities of the character the local player controls, one button each with its key, its charges left and a disabled
## look while it can not be used; while a held ability is in use (the lifted tile), its button stays pressed and a hint
## shows its keys. The buttons only ask the [PlayerController]; the rules live there, in the [Ability] and the [TurnManager].

## Shortcuts of the first buttons, in order
const ACTIONS: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3"]

@export_group("Configuration")
@export var _buttons: Container
@export var _aiming_hint: Label

var player_controller: PlayerController

var character: Character:
	set(new_character):
		character = new_character
		_build()

var _abilities: Array[Ability] = []

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var move_keys: String = "".join([_key(&"move_up"), _key(&"move_left"), _key(&"move_down"), _key(&"move_right")])
	_aiming_hint.text = "Turn %s %s or face %s · Set down %s · Cancel %s" % [_key(&"rotate_left"), _key(&"rotate_right"), move_keys, _key(&"confirm_ability"), _key(&"cancel_ability")]
	_build()

## Shows whether each ability can be used now and which one is held
func update() -> void:
	if not is_node_ready() or not is_instance_valid(player_controller) or not is_instance_valid(character): return
	for index: int in _abilities.size():
		var ability: Ability = _abilities[index]
		var button: Button = _buttons.get_child(index) as Button
		button.text = _get_label(ability, index)
		button.disabled = not player_controller.can_arm(ability)
		button.set_pressed_no_signal(character.active_ability_id == ResourceId.of(ability))
	_aiming_hint.visible = not character.active_ability_id.is_empty()

func _build() -> void:
	if not is_node_ready() or Engine.is_editor_hint(): return
	for button: Node in _buttons.get_children():
		_buttons.remove_child(button)
		button.queue_free()
	_abilities.clear()
	if is_instance_valid(character) and character.profile:
		for ability: Ability in character.profile.abilities: if ability: _abilities.append(ability)
	for index: int in _abilities.size():
		var ability: Ability = _abilities[index]
		var button: Button = Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.icon = ability.icon
		button.tooltip_text = ability.description
		if index < ACTIONS.size():
			var action_event: InputEventAction = InputEventAction.new()
			action_event.action = ACTIONS[index]
			button.shortcut = Shortcut.new()
			button.shortcut.events = [action_event]
		button.pressed.connect(_on_ability_pressed.bind(ability))
		_buttons.add_child(button)
	visible = not _abilities.is_empty()
	update()

func _get_label(ability: Ability, index: int) -> String:
	var label: String = ability.name
	if ability.is_passive(): return "%s (passive)" % label
	if index < ACTIONS.size(): label = "%s [%s]" % [label, TurnStatus.get_action_key(ACTIONS[index])]
	var charges_left: int = ability.get_charges_left(character)
	if charges_left >= 0: label = "%s · %d left" % [label, charges_left]
	return label

static func _key(action: StringName) -> String:
	return "[%s]" % TurnStatus.get_action_key(action)

func _on_ability_pressed(ability: Ability) -> void:
	if is_instance_valid(player_controller): player_controller.arm_ability(ability)
	# The button shows the host's answer once it arrives, not the press
	update()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _buttons: warnings.append("Missing buttons Container reference.")
	if not _aiming_hint: warnings.append("Missing aiming hint Label reference.")
	return warnings
