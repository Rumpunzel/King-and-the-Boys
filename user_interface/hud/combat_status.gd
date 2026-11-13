@tool
@icon("uid://cmbhx5v0d8ri8")
class_name CombatStatus
extends VBoxContainer
## Shows what the monsters and blocks do: a banner while the monsters take their turn, and each block's dice with the one that
## counts. When a block waits for the local player (see [member TurnManager.block_choice]), its dice or the ways to push become
## buttons; pressing one only asks the local [PlayerController], the rules live in [TurnManager].

@export var _player_controller_spawner: PlayerControllerSpawner
@export var _turn_manager: TurnManager
## How long a block's dice stay on screen after the strike
@export_range(0.5, 10.0) var dice_duration: float = 2.5

@export_group("Configuration")
@export var _banner: Control
@export var _block_panel: Control
@export var _title: Label
@export var _dice: Container
@export var _ways: Container

var _player_controller: PlayerController
var _hide_tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint(): return
	assert(_player_controller_spawner)
	assert(_turn_manager)
	_banner.hide()
	_block_panel.hide()
	_turn_manager.phase_changed.connect(_on_phase_changed)
	_turn_manager.block_shown.connect(_on_block_shown)
	_turn_manager.block_choice_changed.connect(_on_block_choice_changed)
	_player_controller_spawner.player_controller_created.connect(_on_player_controller_created)
	_on_phase_changed(_turn_manager.phase)
	_on_block_choice_changed()

func _on_player_controller_created(player_controller: PlayerController) -> void:
	if player_controller.player.is_local_player(): _player_controller = player_controller
	_on_block_choice_changed()

func _on_phase_changed(phase: TurnManager.Phase) -> void:
	_banner.visible = phase == TurnManager.Phase.MONSTERS

## The dice as they fell, the one that counts highlighted; they stay a while, then go
func _on_block_shown(attacker: Character, defender: Character, dice: Array[int], chosen: int) -> void:
	_title.text = "%s blocks %s" % [attacker.profile.name, defender.profile.name]
	_clear()
	var marked: bool = false
	for face: int in dice:
		var die: Button = _add_die(face, attacker, defender)
		# Shown, not pressed; one die of the face that counts is marked, even if several show it
		die.disabled = true
		if face == chosen and not marked:
			marked = true
			die.text = "★ %s" % die.text
			die.disabled = false
			die.mouse_filter = Control.MOUSE_FILTER_IGNORE
			die.focus_mode = Control.FOCUS_NONE
	_block_panel.show()
	if _hide_tween: _hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(dice_duration)
	_hide_tween.tween_callback(_hide_unless_choosing)

## A choice for the local player: the dice or the ways as buttons; others see whose choice it is
func _on_block_choice_changed() -> void:
	var choice: Dictionary = _turn_manager.block_choice
	if choice.is_empty():
		_hide_unless_choosing()
		return
	if _hide_tween: _hide_tween.kill()
	var attacker: Character = get_node_or_null(choice[TurnManager.CHOICE_ATTACKER] as NodePath) as Character
	var defender: Character = get_node_or_null(choice[TurnManager.CHOICE_DEFENDER] as NodePath) as Character
	# Figures this peer does not have (yet): nothing to show, and no dice of an earlier block left behind
	if not attacker or not defender:
		_clear()
		_block_panel.hide()
		return
	var choosing: bool = is_instance_valid(_player_controller) and _player_controller.is_choosing_for_block()
	var dice: Array = choice[TurnManager.CHOICE_DICE]
	var ways: Array = choice[TurnManager.CHOICE_WAYS]
	_clear()
	if not dice.is_empty():
		_title.text = "Pick a die: %s blocks %s" % [attacker.profile.name, defender.profile.name] if choosing else "Picking a die…"
		for index: int in dice.size():
			var face: int = dice[index]
			var die: Button = _add_die(face, attacker, defender)
			die.disabled = not choosing
			die.pressed.connect(_choose.bind(index))
	else:
		_title.text = "Push %s which way?" % defender.profile.name if choosing else "Choosing where to push…"
		for way_value: Variant in ways:
			var way: int = way_value
			var button: Button = Button.new()
			button.text = _way_name(way)
			button.disabled = not choosing
			button.pressed.connect(_choose.bind(way))
			_ways.add_child(button)
	_block_panel.show()

func _choose(value: int) -> void:
	if is_instance_valid(_player_controller): _player_controller.request_block_choice(value)

func _hide_unless_choosing() -> void:
	if _turn_manager.block_choice.is_empty() and not (_hide_tween and _hide_tween.is_running()): _block_panel.hide()

func _clear() -> void:
	for container: Container in [_dice, _ways]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()

func _add_die(face: int, attacker: Character, defender: Character) -> Button:
	var die: Button = Button.new()
	die.text = face_name(face as Block.Face, attacker.profile.name, defender.profile.name)
	_dice.add_child(die)
	return die

## @returns what [param face] means for this block, e.g. "Skeleton falls"
static func face_name(face: Block.Face, attacker_name: String, defender_name: String) -> String:
	match face:
		Block.Face.ATTACKER_DOWN: return "%s falls" % attacker_name
		Block.Face.BOTH_DOWN: return "Both fall"
		Block.Face.PUSH: return "Push"
		Block.Face.DEFENDER_STUMBLES: return "%s stumbles" % defender_name
		Block.Face.DEFENDER_DOWN: return "%s falls" % defender_name
	return "?"

static func _way_name(way: int) -> String:
	match way:
		Level.Direction.UP: return "↑ Up"
		Level.Direction.RIGHT: return "→ Right"
		Level.Direction.DOWN: return "↓ Down"
		Level.Direction.LEFT: return "← Left"
	return "?"
