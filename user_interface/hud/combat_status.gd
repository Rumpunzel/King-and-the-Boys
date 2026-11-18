@tool
@icon("uid://cmbhx5v0d8ri8")
class_name CombatStatus
extends VBoxContainer
## Shows what the monsters and blocks do: a banner while the monsters take their turn, and each block's dice with the one that
## counts. When a block waits for the local player (see [member TurnManager.block_state]), its dice become buttons; pressing one
## only asks the local [PlayerController], the rules live in [TurnManager].

@export var _player_controller_spawner: PlayerControllerSpawner
@export var _turn_manager: TurnManager
## How long a block's dice stay on screen after the strike
@export_range(0.5, 10.0) var dice_duration: float = 2.5

@export_group("Configuration")
@export var _banner: Control
@export var _block_panel: Control
@export var _title: Label
@export var _dice: Container

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
	_turn_manager.block_state_changed.connect(_on_block_state_changed)
	_player_controller_spawner.player_controller_created.connect(_on_player_controller_created)
	_on_phase_changed(_turn_manager.phase)
	_on_block_state_changed()

func _on_player_controller_created(player_controller: PlayerController) -> void:
	if player_controller.player.is_local_player(): _player_controller = player_controller
	_on_block_state_changed()

func _on_phase_changed(phase: TurnManager.Phase) -> void:
	_banner.visible = phase != TurnManager.Phase.HEROES

## The dice as they fell, the one that counts highlighted; they stay a while, then go
func _on_block_shown(attacker: Character, defender: Character, dice: Array[int], chosen: int, pinned: bool) -> void:
	_title.text = "%s blocks %s" % [attacker.profile.name, defender.profile.name]
	_clear()
	var marked: bool = false
	for face: int in dice:
		var die: Button = _add_die(face, attacker, defender, pinned)
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

## A choice for the local player: the dice as buttons; others see whose choice it is
func _on_block_state_changed() -> void:
	var choice: Dictionary = _turn_manager.block_state
	if choice.is_empty():
		_hide_unless_choosing()
		return
	var stage: int = choice[BlockSequence.STAGE]
	if stage != BlockSequence.Stage.CHOOSING: return
	if _hide_tween: _hide_tween.kill()
	var attacker_path: NodePath = choice[BlockSequence.ATTACKER]
	var defender_path: NodePath = choice[BlockSequence.DEFENDER]
	var attacker: Character = get_node_or_null(attacker_path) as Character
	var defender: Character = get_node_or_null(defender_path) as Character
	# Figures this peer does not have (yet): nothing to show, and no dice of an earlier block left behind
	if not attacker or not defender:
		_clear()
		_block_panel.hide()
		return
	var choosing: bool = is_instance_valid(_player_controller) and _player_controller.is_choosing_for_block()
	var dice: Array = choice[BlockSequence.DICE]
	_clear()
	_title.text = "Pick a die: %s blocks %s" % [attacker.profile.name, defender.profile.name] if choosing else "Picking a die…"
	var pinned: bool = choice.get(BlockSequence.PINNED, false)
	for index: int in dice.size():
		var face: int = dice[index]
		var die: Button = _add_die(face, attacker, defender, pinned)
		die.disabled = not choosing
		die.pressed.connect(_choose.bind(index))
	_block_panel.show()

func _choose(value: int) -> void:
	if is_instance_valid(_player_controller): _player_controller.request_block_choice(value)

func _hide_unless_choosing() -> void:
	if _turn_manager.block_state.is_empty() and not (_hide_tween and _hide_tween.is_running()): _block_panel.hide()

func _clear() -> void:
	for child: Node in _dice.get_children():
		_dice.remove_child(child)
		child.queue_free()

func _add_die(face: int, attacker: Character, defender: Character, pinned: bool) -> Button:
	var die: Button = Button.new()
	die.text = face_name(face as Block.Face, attacker.profile.name, defender.profile.name, pinned)
	_dice.add_child(die)
	return die

## @returns what [param face] means for this block, e.g. "Skeleton falls"; a defender [param pinned] (see [member Block.pinned])
## falls against the wall where it would be pushed
static func face_name(face: Block.Face, attacker_name: String, defender_name: String, pinned: bool = false) -> String:
	match face:
		Block.Face.ATTACKER_DOWN: return "%s falls" % attacker_name
		Block.Face.BOTH_DOWN: return "Both fall"
		Block.Face.PUSH: return "Push: %s falls against the wall" % defender_name if pinned else "Push"
		Block.Face.DEFENDER_STUMBLES: return "%s stumbles and falls against the wall" % defender_name if pinned else "%s stumbles" % defender_name
		Block.Face.DEFENDER_DOWN: return "%s falls" % defender_name
	return "?"
