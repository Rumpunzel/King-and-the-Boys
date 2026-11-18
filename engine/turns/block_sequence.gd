@icon("uid://3xn0cgn4onrw")
class_name BlockSequence
extends RefCounted
## Host only: plays one [Block] out in stages, which every peer follows through [member TurnManager.block_state]: the dice are
## rolled ([constant Stage.ROLLED]), the side that picks may choose a die ([constant Stage.CHOOSING]), then the face that counts
## is known, the attacker strikes and the falls and the push follow ([constant Stage.STRUCK]); then the state clears. Where the
## heroes see the block, each stage gets a moment before the next. [TurnManager] makes one per block and awaits [method run].

enum Stage {
	ROLLED,
	CHOOSING,
	STRUCK,
}

## Keys of [member TurnManager.block_state]: the stage, the paths of attacker and defender, the dice ([enum Block.Face]s), whether
## a push knocks the defender down where it is ([member Block.pinned]); the face that counts from [constant Stage.STRUCK] on; and,
## while choosing, the choice's number, which an answer names, and the id of the player who chooses
const STAGE: StringName = &"stage"
const ATTACKER: StringName = &"attacker"
const DEFENDER: StringName = &"defender"
const DICE: StringName = &"dice"
const PINNED: StringName = &"pinned"
const CHOSEN: StringName = &"chosen"
const CHOICE_ID: StringName = &"choice_id"
const PICKER: StringName = &"picker"

## How long the dice of a block the heroes see lie before it goes on, and how long the strike plays before anything else moves
const _ROLL_PAUSE: float = 0.6
const _STRIKE_PAUSE: float = 0.8
## How often a choice is looked for
const _POLL: float = 0.05

## Counts the choices asked, so an answer counts only for the one it was given for, whichever block asked it
static var _choices_asked: int = 0

var block: Block

var _turn_manager: TurnManager
var _level: Level
var _stage: int = -1
var _cancelled: bool = false
var _choice_id: int = 0
var _picker_id: int = 0
# The die's index chosen, -1 while none came
var _chosen: int = -1

func _init(turn_manager: TurnManager, level: Level, attacker: Character, defender: Character) -> void:
	_turn_manager = turn_manager
	_level = level
	block = Block.new(attacker, defender)

## Rolls, asks for a choice if a player picks among more than one die, strikes and plays the outcome out, pausing where the
## heroes see it. Nothing either figure did before can be undone any more.
## @returns the block, or [code]null[/code] if a figure was gone before the strike or the game moved on (see [method cancel]):
## then the step it belongs to does not go on
func run() -> Block:
	var attacker: Character = block.attacker
	var defender: Character = block.defender
	var in_sight: bool = _turn_manager.is_in_sight(block.defender_cell)
	# Facing the defender, replicated like any turn
	var to_defender: Vector3 = _level.get_spot_position(defender.grid_cell, defender.tile_spot) - _level.get_spot_position(attacker.grid_cell, attacker.tile_spot)
	if to_defender.length_squared() > 0.0001:
		attacker.place_on_grid(attacker.grid_cell, attacker.tile_spot, Character.rotation_to_facing(atan2(to_defender.x, to_defender.z)))
	block.roll(_level, _turn_manager.combat_random)
	_publish(Stage.ROLLED)
	if in_sight: await _pause(_ROLL_PAUSE)
	if not _is_still_on(): return _drop()
	if block.dice.size() > 1:
		var die: int = await _ask()
		if not _is_still_on(): return _drop()
		# The board may have changed meanwhile: whether a push now pins the defender decides the host's pick
		block.update_pinned(_level)
		if die >= 0: block.chosen = block.dice[die]
		else: block.chosen = Block.pick_best(block.dice, block.attacker_picks, block.stumbles_down(), block.pinned)
	_publish(Stage.STRUCK)
	# Before the outcome, so every peer holds the falls and the push until the strike lands
	_turn_manager.broadcast_block(block)
	block.apply(block.chosen, _level)
	_turn_manager.blocked.emit(block)
	_turn_manager.close_undo(attacker)
	_turn_manager.close_undo(defender)
	if in_sight:
		await _pause(_STRIKE_PAUSE)
		if block.was_pushed() and is_instance_valid(block.defender) and not _cancelled: await _turn_manager.wait_for_figure(block.defender)
	# A save loaded meanwhile: struck in the game left behind
	if _cancelled: return null
	_turn_manager.block_state = {}
	return block

## The player asked counts [param value], a die's index, if [param sender_id] is that player and [param choice_id] names the
## choice open now; other answers (late, early, a second click) count for nothing
func answer(sender_id: int, choice_id: int, value: int) -> void:
	if _cancelled or _stage != Stage.CHOOSING or _chosen >= 0: return
	if choice_id != _choice_id or sender_id != _picker_id: return
	if value < 0 or value >= block.dice.size(): return
	_chosen = value

## The game moved on (e.g. a save loaded): a block not yet struck does not happen; the caller clears the state
func cancel() -> void:
	_cancelled = true

## Asks the player controlling the picking side to choose one of the dice, and waits for it at most
## [member TurnManager.choice_timeout], while the player stays.
## @returns the index chosen, [code]-1[/code] to leave it to the host (a monster, nobody to ask, no answer)
func _ask() -> int:
	_picker_id = _get_choosing_player(block.get_picker())
	if _picker_id == 0: return -1
	_choices_asked += 1
	_choice_id = _choices_asked
	_publish(Stage.CHOOSING)
	# By the clock: each poll lasts a frame or more beyond its length
	var deadline: int = Time.get_ticks_msec() + roundi(_turn_manager.choice_timeout * 1000.0)
	while _chosen < 0 and not _cancelled and Time.get_ticks_msec() < deadline and Lobby.get_player(_picker_id):
		await _pause(_POLL)
	return _chosen

## @returns the id of the connected player who chooses for [param chooser], [code]0[/code] if the host chooses (a monster, or
## choices off)
func _get_choosing_player(chooser: Character) -> int:
	if _turn_manager.choice_timeout <= 0.0 or not is_instance_valid(chooser) or chooser.profile.group != CharacterProfile.Groups.HEROES: return 0
	for player: Player in Lobby.get_connected_players():
		if chooser.is_controlled_by(player.player_id): return player.player_id
	return 0

## Tells every peer the block is at [param stage]
func _publish(stage: Stage) -> void:
	_stage = stage
	var dice: Array[int] = []
	dice.assign(block.dice)
	var state: Dictionary = {
		STAGE: stage,
		ATTACKER: block.attacker.get_path(),
		DEFENDER: block.defender.get_path(),
		DICE: dice,
		PINNED: block.pinned,
	}
	if stage == Stage.CHOOSING:
		state[CHOICE_ID] = _choice_id
		state[PICKER] = _picker_id
	if stage == Stage.STRUCK: state[CHOSEN] = block.chosen
	_turn_manager.block_state = state

## A tween, not a timer: it goes with the turn manager (e.g. leaving the game), so nothing resumes on a freed one
func _pause(seconds: float) -> void:
	await _turn_manager.create_tween().tween_interval(seconds).finished

## @returns whether the block still happens: not cancelled, and both figures are still there
func _is_still_on() -> bool:
	return not _cancelled and is_instance_valid(block.attacker) and is_instance_valid(block.defender)

func _drop() -> Block:
	if not _cancelled: _turn_manager.block_state = {}
	return null
