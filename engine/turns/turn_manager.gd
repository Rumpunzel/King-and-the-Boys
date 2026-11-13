@tool
@icon("uid://3xn0cgn4onrw")
class_name TurnManager
extends Node
## Runs simultaneous turns: every player moves their [Character]s up to their movement points,
## uses their abilities, may undo steps and uses, and passes. Once every connected player has passed, the monsters take
## their turn one after another (see [method _run_monster_phase]), then the next turn starts.
## The host is the referee; peers send requests and follow the replicated state.

signal turn_started(turn_number: int)
signal passed_players_changed
signal phase_changed(phase: Phase)
## Host only: a block was rolled and played out on the board
signal blocked(block: Block)
## Every peer: a block's attacker strikes; [param dice] are the faces rolled ([enum Block.Face]), [param chosen] the one that counts
signal block_shown(attacker: Character, defender: Character, dice: Array[int], chosen: int)
## Every peer: a player is asked to choose for a block, or no longer is, see [member block_choice]
signal block_choice_changed

enum Phase {
	HEROES,
	MONSTERS,
}

const GROUP: StringName = "TurnManager"
## How often the host looks whether a monster's figure arrived, and how long it waits for one at most (a figure that never
## arrives must not hold the game)
const _HOP_POLL: float = 0.05
const _MAX_HOP_WAIT: float = 3.0
## How long the host lets a block in sight play before the phase goes on
const _BLOCK_PAUSE: float = 0.8

## Keys of [member block_choice]
const CHOICE_ID: StringName = &"id"
const CHOICE_PICKER: StringName = &"picker"
const CHOICE_ATTACKER: StringName = &"attacker"
const CHOICE_DEFENDER: StringName = &"defender"
const CHOICE_DICE: StringName = &"dice"
const CHOICE_WAYS: StringName = &"ways"

## Host only: how long a player has to choose for a block (see [member block_choice]) before the host chooses for them; at
## [code]0[/code] the host always chooses (e.g. in tests)
@export var choice_timeout: float = 20.0

@export_group("Configuration")
@export var _level: Level
## Hidden from peers until their [TurnManager] exists, see [method start_syncing_peer]
@export var _synchronizer: MultiplayerSynchronizer

# Replicated from the host
var turn_number: int = 1:
	set(new_turn_number):
		if new_turn_number == turn_number: return
		turn_number = new_turn_number
		turn_started.emit(turn_number)
var passed_player_ids: PackedInt32Array = PackedInt32Array():
	set(new_passed_player_ids):
		if new_passed_player_ids == passed_player_ids: return
		passed_player_ids = new_passed_player_ids
		passed_players_changed.emit()
## Who acts: the players, or the monsters while the heroes wait; a loaded game starts with the heroes (see
## [method stop_monster_phase])
var phase: Phase = Phase.HEROES:
	set(new_phase):
		if new_phase == phase: return
		phase = new_phase
		phase_changed.emit(phase)

## The choice a block waits for, set by the host and replicated, empty while none is asked: its number, which an answer names
## ([constant CHOICE_ID]), the player id who chooses ([constant CHOICE_PICKER]), the paths of attacker and defender, and either the dice to pick one of ([constant CHOICE_DICE],
## [enum Block.Face]s) or the ways to push the defender ([constant CHOICE_WAYS], [enum Level.Direction]s). Every request but
## the choice waits meanwhile
var block_choice: Dictionary = {}:
	set(new_block_choice):
		if new_block_choice == block_choice: return
		block_choice = new_block_choice
		block_choice_changed.emit()

## Host only: rolls the block dice and picks pushes; seed it to block the same again
var combat_random: RandomNumberGenerator = RandomNumberGenerator.new()
# Host only: the choice made for the block waiting, -1 while none came; counted runs end a choice the game moved on from
var _chosen: int = -1
var _choice_run: int = 0
# Host only: counts the choices asked, so an answer counts only for the one it was given for
var _choice_count: int = 0

# Host only: steps and ability uses (GridStep, AbilityStep) that can still be undone this turn, newest last
var _undo_stacks: Dictionary[Character, Array] = {}
# Host only: uses of each Ability this turn, by character
var _ability_uses: Dictionary[Character, Dictionary] = {}
# Host only: held abilities in use, see Ability.held
var _held_abilities: Dictionary[Character, HeldAbility] = {}
# Host only: uses that act once the turn ends, in the order they were made
var _pending_steps: Array[AbilityStep] = []
# Host only: an ability that changes the board while it is used can not be undone
var _using_character: Character
var _board_changed_during_use: bool = false
# Host only: counts monster phases started or stopped, so a phase that was stopped (e.g. by loading) ends where it waits
var _monster_phase_run: int = 0
# Host only: heroes that stepped onto a monster's tile this turn, in the order they did; the first on a tile blocks a monster
# there as the monster phase starts. Not saved: a loaded game starts a fresh turn
var _engaged: Array[Character] = []
# Host only: the blocks of the step under way, so the monster phase lets each play out, see _wait_for_block
var _step_blocks: Array[Block] = []
# Host only: peers whose game scene has this node (see start_syncing_peer); only they get its RPCs
var _synced_peers: Array[int] = []

class GridStep extends RefCounted:
	var grid_cell: Vector2i
	var tile_spot: Vector2

	func _init(character: Character) -> void:
		grid_cell = character.grid_cell
		tile_spot = character.tile_spot

class HeldAbility extends RefCounted:
	var ability: Ability
	var target: Vector2i
	var argument: int = 0

	func _init(held_ability: Ability, held_target: Vector2i) -> void:
		ability = held_ability
		target = held_target

static func get_instance(tree: SceneTree) -> TurnManager:
	return tree.get_first_node_in_group(GROUP)

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	add_to_group(GROUP)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not multiplayer.is_server():
		# RPCs to the host need the host to be visible to this peer's synchronizer
		_synchronizer.set_visibility_for(Multiplayer.HOST_ID, true)
		return
	_level.board_changed.connect(_on_board_changed)
	_level.tile_rotated.connect(_on_tile_rotated)
	Lobby.player_disconnected.connect(_on_player_disconnected)

## Host only: this node is part of the game scene, not spawned, so a peer only gets synced once it has loaded it;
## [Game] calls this when the peer reports its part of the game arrived
func start_syncing_peer(peer_id: int) -> void:
	assert(multiplayer.is_server())
	_synchronizer.set_visibility_for(peer_id, true)
	if not _synced_peers.has(peer_id): _synced_peers.append(peer_id)

func has_passed(player_id: int) -> bool:
	return passed_player_ids.has(player_id)

## Steps [param character_path] one cell into [param direction] if a wall, its movement points
## and the target tile allow it; otherwise only turns it. Turning is free.
@rpc("any_peer", "call_local", "reliable")
func request_move(character_path: NodePath, direction: Level.Direction) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = _get_sender_id()
	if has_passed(sender_id): return
	var character: Character = _get_controlled_character(sender_id, character_path)
	if not character or _held_abilities.has(character): return
	await try_step(character, direction, true)
	# A player who left while the step's block waited for a choice may have been the last one not passed
	_end_turn_if_everyone_passed()

## Host only, the one rule for every step, the players' and the monsters': steps [param character] one cell into
## [param direction] if a wall, its movement points and the target tile allow it; otherwise only turns it. Turning is free.
## A fallen figure gets up instead, for a movement point. A standing enemy on the tile it leaves blocks it first: it steps on
## only if it keeps its feet and stays where it is. Stepping onto an enemy's tile ends its moves: a hero blocks a monster
## there as the monster phase starts, a monster blocks a hero at once.
## [param undoable] steps go onto the character's undo stack; a block closes it. A block may wait for a player's choice
## (see [member block_choice]), so await it.
## @returns whether it stepped
func try_step(character: Character, direction: Level.Direction, undoable: bool = false) -> bool:
	assert(multiplayer.is_server())
	if character.posture != Character.Posture.STANDING:
		_stand_up(character)
		return false
	var target_cell: Vector2i = _level.get_step_target(character.grid_cell, direction)
	var free_spots: Array[Vector2] = _level.get_free_spots(target_cell, character)
	if target_cell == character.grid_cell or character.movement_points <= 0 or free_spots.is_empty():
		character.place_on_grid(character.grid_cell, character.tile_spot, direction)
		return false
	character.movement_points -= 1
	var leaving_blocker: Character = _get_enemy_on(character.grid_cell, character)
	if leaving_blocker:
		var block: Block = await _block(leaving_blocker, character)
		if not block or not is_instance_valid(character) or character.posture != Character.Posture.STANDING or block.was_pushed(): return false
		free_spots = _level.get_free_spots(target_cell, character)
		if free_spots.is_empty():
			# Refused like any step into a full tile: it only turns
			character.place_on_grid(character.grid_cell, character.tile_spot, direction)
			return false
	elif undoable:
		# Record before moving: a move that changes the board clears the stack again
		_track(character)
		var undo_stack: Array = _undo_stacks.get_or_add(character, [])
		undo_stack.append(GridStep.new(character))
	var target_spot: Vector2 = free_spots.front()
	character.place_on_grid(target_cell, target_spot, direction)
	if undoable: _update_undo_steps(character)
	var enemy: Character = _get_enemy_on(target_cell, character)
	if enemy: await _engage(character, enemy)
	return true

## Host only: stepping onto [param enemy]'s tile ends [param character]'s moves; a hero blocks later (see [member _engaged]),
## a monster at once
func _engage(character: Character, enemy: Character) -> void:
	character.movement_points = 0
	if character.profile.group != CharacterProfile.Groups.HEROES:
		await _block(character, enemy)
		return
	_track(character)
	_engaged.append(character)
	# The way back is closed: the hero is in the fight
	_close_undo(character)

## Host only: a fallen [param character] gets up for a movement point
func _stand_up(character: Character) -> void:
	if character.movement_points <= 0: return
	character.movement_points -= 1
	character.posture = Character.Posture.STANDING

## Host only: [param attacker] blocks [param defender]: the dice are rolled, the side that picks chooses a die and an attacking
## player the way to push (each a [member block_choice] the host waits for), then every peer sees the attack, the falls and the
## push. Nothing either did before can be undone any more.
## @returns the block, or [code]null[/code] if the game moved on while it waited (a save loaded, a figure gone)
func _block(attacker: Character, defender: Character) -> Block:
	var block: Block = Block.new(attacker, defender)
	# Facing the defender, replicated like any turn
	var to_defender: Vector3 = _level.get_spot_position(defender.grid_cell, defender.tile_spot) - _level.get_spot_position(attacker.grid_cell, attacker.tile_spot)
	if to_defender.length_squared() > 0.0001:
		attacker.place_on_grid(attacker.grid_cell, attacker.tile_spot, Character.rotation_to_facing(atan2(to_defender.x, to_defender.z)))
	block.roll(_level, combat_random)
	var run: int = _choice_run
	var dice: Array[int] = []
	dice.assign(block.dice)
	if dice.size() > 1:
		var die: int = await _ask(block.get_picker(), block, dice, [])
		if not _is_still_on(block, run): return null
		if die >= 0: block.chosen = block.dice[die]
	if Block.pushes(block.chosen):
		var ways: Array[int] = []
		ways.assign(block.get_push_ways(_level))
		if ways.size() > 1:
			block.push_way = await _ask(attacker, block, [], ways)
			if not _is_still_on(block, run): return null
	# Before the outcome, so every peer holds the falls and the push until the strike lands
	show_block(attacker.get_path(), defender.get_path(), dice, block.chosen)
	for peer_id: int in _synced_peers:
		if peer_id != multiplayer.get_unique_id(): show_block.rpc_id(peer_id, attacker.get_path(), defender.get_path(), dice, block.chosen)
	block.apply(block.chosen, _level, combat_random)
	_step_blocks.append(block)
	blocked.emit(block)
	_close_undo(attacker)
	_close_undo(defender)
	return block

## @returns whether [param block] still happens after waiting for a choice: no choice was dropped since [param run] (a save
## loaded) and both figures are still there
func _is_still_on(block: Block, run: int) -> bool:
	return run == _choice_run and is_instance_valid(block.attacker) and is_instance_valid(block.defender)

## Every peer: [param attacker_path]'s figure strikes at [param defender_path]'s; the host calls it on itself and sends it to the
## peers that have this node
@rpc("authority", "call_remote", "reliable")
func show_block(attacker_path: NodePath, defender_path: NodePath, dice: Array[int], chosen: int) -> void:
	var attacker: Character = get_node_or_null(attacker_path) as Character
	var defender: Character = get_node_or_null(defender_path) as Character
	if not attacker or not defender: return
	attacker.show_block(defender)
	block_shown.emit(attacker, defender, dice, chosen)

## Host only: asks the player controlling [param chooser] to pick one of [param dice] (indices) or of [param ways] for
## [param block], and waits for the choice, at most [member choice_timeout], while the player stays.
## @returns the index or way chosen, [code]-1[/code] to leave it to the host (a monster, nobody to ask, no answer)
func _ask(chooser: Character, block: Block, dice: Array[int], ways: Array[int]) -> int:
	var picker_id: int = _get_choosing_player(chooser)
	if picker_id == 0: return -1
	var run: int = _choice_run
	_chosen = -1
	_choice_count += 1
	block_choice = {
		CHOICE_ID: _choice_count,
		CHOICE_PICKER: picker_id,
		CHOICE_ATTACKER: block.attacker.get_path(),
		CHOICE_DEFENDER: block.defender.get_path(),
		CHOICE_DICE: dice,
		CHOICE_WAYS: ways,
	}
	var waited: float = 0.0
	# A tween, not a timer: it goes with this node (e.g. leaving the game), so nothing resumes on a freed one
	while _chosen < 0 and run == _choice_run and waited < choice_timeout and Lobby.get_player(picker_id):
		await create_tween().tween_interval(_HOP_POLL).finished
		waited += _HOP_POLL
	if run != _choice_run: return -1
	block_choice = {}
	return _chosen

## @returns the id of the connected player who chooses for [param chooser], [code]0[/code] if the host chooses (a monster, or
## choices off)
func _get_choosing_player(chooser: Character) -> int:
	if choice_timeout <= 0.0 or not is_instance_valid(chooser) or chooser.profile.group != CharacterProfile.Groups.HEROES: return 0
	for player: Player in Lobby.get_connected_players():
		if chooser.is_controlled_by(player.player_id): return player.player_id
	return 0

## The player asked by [member block_choice] numbered [param choice_id] chooses [param value]: a die's index, or a way to push.
## An answer to an earlier choice (a late or second click) counts for nothing
@rpc("any_peer", "call_local", "reliable")
func request_block_choice(choice_id: int, value: int) -> void:
	if not multiplayer.is_server() or block_choice.is_empty() or _chosen >= 0: return
	var open_id: int = block_choice[CHOICE_ID]
	var picker_id: int = block_choice[CHOICE_PICKER]
	if choice_id != open_id or _get_sender_id() != picker_id: return
	var dice: Array = block_choice[CHOICE_DICE]
	var ways: Array = block_choice[CHOICE_WAYS]
	if not dice.is_empty() and (value < 0 or value >= dice.size()): return
	if dice.is_empty() and not ways.has(value): return
	_chosen = value

## Host only: a choice under way is dropped, e.g. as a save is loaded; the block that waited for it does not happen
func _cancel_choice() -> void:
	_choice_run += 1
	block_choice = {}

## @returns the standing enemy of [param character] on [param cell] who blocks it: the first by
## [member CharacterProfile.block_priority], or [code]null[/code]
func _get_enemy_on(cell: Vector2i, character: Character) -> Character:
	var enemy: Character = null
	for other: Character in Block.get_standing_on(cell, _level):
		if other.profile.group == character.profile.group: continue
		if not enemy or other.profile.block_priority < enemy.profile.block_priority: enemy = other
	return enemy

func _close_undo(character: Character) -> void:
	_undo_stacks.erase(character)
	_update_undo_steps(character)

## Takes back the last step of [param character_path] this turn and refunds its movement point.
## A pass of the sender is taken back with it, but only if the step could be undone.
@rpc("any_peer", "call_local", "reliable")
func request_undo(character_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = _get_sender_id()
	var character: Character = _get_controlled_character(sender_id, character_path)
	if not character or _held_abilities.has(character): return
	var undo_stack: Array = _undo_stacks.get(character, [])
	if undo_stack.is_empty(): return
	var last_step: RefCounted = undo_stack.back()
	if last_step is AbilityStep:
		_undo_ability(last_step as AbilityStep)
		_set_passed(sender_id, false)
		return
	var previous_step: GridStep = last_step
	# Not off nor onto a tile someone holds up: like steps, undo waits until it is set down
	for cell: Vector2i in [character.grid_cell, previous_step.grid_cell]:
		var tile: Structure = _level.get_placed_tile(cell)
		if tile and tile.is_lifted(): return
	# Another piece may have taken the old spot meanwhile
	var free_spots: Array[Vector2] = _level.get_free_spots(previous_step.grid_cell, character)
	if free_spots.is_empty(): return
	var spot: Vector2 = previous_step.tile_spot if free_spots.has(previous_step.tile_spot) else free_spots.front()
	undo_stack.pop_back()
	character.movement_points += 1
	# Keep facing the way the step went: the figure walks back, which shows it is an undo
	var step_direction: Level.Direction = Level.get_direction(previous_step.grid_cell, character.grid_cell)
	character.place_on_grid(previous_step.grid_cell, spot, step_direction)
	_update_undo_steps(character)
	_set_passed(sender_id, false)

## Uses the [Ability] named [param ability_id] of [param character_path] on [param target_cell] with [param argument]
## (its choice, e.g. how far to turn), if the profile lists it and its uses, charges and the movement points allow it.
## For a [member Ability.held] ability in use this confirms it on its target; one that can not be used then is cancelled.
@rpc("any_peer", "call_local", "reliable")
func request_ability(character_path: NodePath, ability_id: String, target_cell: Vector2i, argument: int) -> void:
	if not multiplayer.is_server(): return
	var character: Character = _get_unpassed_character(character_path)
	var ability: Ability = character.get_ability(ability_id) if character else null
	if not ability or ability.is_passive(): return
	var held: HeldAbility = _held_abilities.get(character)
	if held and held.ability != ability: return
	# Held abilities are used as the host accepted and showed them (e.g. the lifted tile's turns), whatever the client sent
	if held:
		target_cell = held.target
		argument = held.argument
	# Held abilities checked their limits when they began
	elif ability.held or not _has_uses_left(character, ability): return
	var cost: int = ability.get_cost(character, target_cell, argument)
	if cost > character.movement_points or not ability.can_use(character, target_cell, argument, _level):
		_cancel_held(character)
		return
	_end_held(character)
	_use_ability(character, ability, target_cell, argument)

## Starts using the [member Ability.held] ability [param ability_id] of [param character_path] on [param target_cell];
## the character can neither step, undo nor use another ability until it is confirmed with [method request_ability] or cancelled
@rpc("any_peer", "call_local", "reliable")
func request_ability_begin(character_path: NodePath, ability_id: String, target_cell: Vector2i) -> void:
	if not multiplayer.is_server(): return
	var character: Character = _get_unpassed_character(character_path)
	if not character or _held_abilities.has(character): return
	var ability: Ability = character.get_ability(ability_id)
	if not ability or not ability.held or not _has_uses_left(character, ability): return
	if not ability.can_begin(character, target_cell, _level): return
	_track(character)
	_held_abilities[character] = HeldAbility.new(ability, target_cell)
	character.active_ability_id = ability_id
	character.held_cost = ability.get_cost(character, target_cell, 0)
	ability.begin(character, target_cell, _level)

## Changes the choice of the held ability in use, if the movement points can pay for it
@rpc("any_peer", "call_local", "reliable")
func request_ability_adjust(character_path: NodePath, argument: int) -> void:
	if not multiplayer.is_server(): return
	var character: Character = _get_controlled_character(_get_sender_id(), character_path)
	if not character: return
	var held: HeldAbility = _held_abilities.get(character)
	if not held or held.ability.get_cost(character, held.target, argument) > character.movement_points: return
	held.argument = argument
	character.held_cost = held.ability.get_cost(character, held.target, argument)
	held.ability.adjust(character, held.target, argument, _level)

## Stops using the held ability in use; nothing is paid
@rpc("any_peer", "call_local", "reliable")
func request_ability_cancel(character_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var character: Character = _get_controlled_character(_get_sender_id(), character_path)
	if not character: return
	_cancel_held(character)

## Passes or takes a pass back; the turn ends once every connected player has passed.
## Passing cancels the held abilities of the sender's characters.
@rpc("any_peer", "call_local", "reliable")
func request_pass(passed: bool) -> void:
	if not multiplayer.is_server() or phase != Phase.HEROES or not block_choice.is_empty(): return
	var sender_id: int = _get_sender_id()
	if not Lobby.get_player(sender_id): return
	if passed: _cancel_held_of(sender_id)
	_set_passed(sender_id, passed)
	_end_turn_if_everyone_passed()

## Passes for the sender only if [param character_path] really is out of moves. Auto-pass uses this, as a peer may
## still see the moves of the last turn while the new turn's state is on its way.
@rpc("any_peer", "call_local", "reliable")
func request_auto_pass(character_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = _get_sender_id()
	var character: Character = _get_controlled_character(sender_id, character_path)
	if not character or character.movement_points != 0: return
	request_pass(true)

func _end_turn_if_everyone_passed() -> void:
	# Not while a block waits for a choice: the step it belongs to ends first, then checks again (see request_move)
	if phase != Phase.HEROES or not block_choice.is_empty(): return
	for player: Player in Lobby.get_connected_players():
		if not has_passed(player.player_id): return
	_run_monster_phase()

## Host only: the heroes' turn ends, then every monster in turn steps as its [Agent] chooses (see [method Agent.choose_step])
## until it is out of movement points or stops; the next turn starts once all are done. Players' requests wait meanwhile.
## The host waits for each hop the heroes can see (from or onto a revealed tile); hidden monsters move at once.
func _run_monster_phase() -> void:
	assert(multiplayer.is_server())
	_end_heroes_turn()
	phase = Phase.MONSTERS
	_monster_phase_run += 1
	var run: int = _monster_phase_run
	# The heroes who stepped onto a monster's tile block first, one per tile
	var engaged: Array[Character] = _engaged
	_engaged = []
	var blocked_cells: Dictionary[Vector2i, bool] = {}
	for index: int in engaged.size():
		# Heroes may leave while the host waits, like monsters below
		if not is_instance_valid(engaged[index]): continue
		var hero: Character = engaged[index]
		if hero.posture != Character.Posture.STANDING or blocked_cells.has(hero.grid_cell): continue
		var monster: Character = _get_enemy_on(hero.grid_cell, hero)
		if not monster: continue
		blocked_cells[hero.grid_cell] = true
		var block: Block = await _block(hero, monster)
		if run != _monster_phase_run: return
		if not block or not _is_in_sight(hero.grid_cell): continue
		await _wait_for_block(block)
		if run != _monster_phase_run: return
	# Pieces may leave while the host waits (a player leaving takes their hero along): each is checked before it is used
	var nodes: Array[Node] = get_tree().get_nodes_in_group(Character.GROUP)
	for index: int in nodes.size():
		if not is_instance_valid(nodes[index]): continue
		var character: Character = nodes[index] as Character
		var agent: Agent = character.get_parent() as Agent if character else null
		if not agent or character.profile.group != CharacterProfile.Groups.MONSTERS: continue
		_alert_heroes_seen_by(character)
		while is_instance_valid(character) and character.is_inside_tree() and character.movement_points > 0:
			var was_in_sight: bool = _is_in_sight(character.grid_cell)
			if character.posture != Character.Posture.STANDING:
				_stand_up(character)
				continue
			var direction: int = agent.choose_step()
			if direction < 0: break
			_step_blocks.clear()
			var stepped: bool = await try_step(character, direction as Level.Direction)
			if run != _monster_phase_run: return
			# Blocks on leaving or arriving play out before anyone moves on, whatever they did
			var blocks: Array[Block] = _step_blocks.duplicate()
			if was_in_sight or _is_in_sight(character.grid_cell):
				if stepped: await _wait_for_figure(character)
				for block: Block in blocks:
					if run != _monster_phase_run: return
					await _wait_for_block(block)
				if run != _monster_phase_run: return
			if not stepped: break
			# Once it hopped in: the heroes react to what they see
			if is_instance_valid(character): _alert_heroes_seen_by(character)
	phase = Phase.HEROES
	_start_next_turn()

## Host only: a monster phase under way stops where it waits, e.g. as a save is loaded; the heroes act again, and no turn ends
func stop_monster_phase() -> void:
	assert(multiplayer.is_server())
	_monster_phase_run += 1
	phase = Phase.HEROES
	_cancel_choice()
	_engaged.clear()
	_clear_alerts()

## Waits until [param character]'s figure arrived, at most [constant _MAX_HOP_WAIT]: its hop may last longer than its move
## animation (delays, body animations). Tweens, not timers: they go with this node (e.g. leaving the game), so nothing resumes
## on a freed one
func _wait_for_figure(character: Character) -> void:
	var waited: float = 0.0
	while is_instance_valid(character) and character.is_figure_moving() and waited < _MAX_HOP_WAIT:
		await create_tween().tween_interval(_HOP_POLL).finished
		waited += _HOP_POLL

## Every hero [param monster] sees, as it comes for them where the heroes see it (on a revealed tile), is on alert, see
## [member Character.alerted]
func _alert_heroes_seen_by(monster: Character) -> void:
	if not _is_in_sight(monster.grid_cell): return
	var in_sight: Dictionary[Vector2i, bool] = _level.get_cells_in_sight(monster.grid_cell, monster.get_vision())
	for node: Node in get_tree().get_nodes_in_group(Character.GROUP):
		var hero: Character = node as Character
		if not hero or not hero.visible or hero.level != _level or hero.profile.group != CharacterProfile.Groups.HEROES: continue
		if in_sight.has(hero.grid_cell): hero.alerted = true

## After the passes are cleared: a hero that also stops showing its pass then goes straight from its alert to its idles
func _clear_alerts() -> void:
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP): character.alerted = false

## Lets a block play: the attack, then the pushed figure's move
func _wait_for_block(block: Block) -> void:
	await create_tween().tween_interval(_BLOCK_PAUSE).finished
	if block.was_pushed() and is_instance_valid(block.defender): await _wait_for_figure(block.defender)

func _is_in_sight(cell: Vector2i) -> bool:
	var tile: Structure = _level.get_placed_tile(cell)
	return tile != null and tile.status == Structure.Status.REVEALED

## Host only: player ids differ between sessions, so passes do not survive loading a game
func clear_passes() -> void:
	assert(multiplayer.is_server())
	passed_player_ids = PackedInt32Array()

## Host only, before the monsters act: held abilities are cancelled, uses that act at the turn's end resolve, and nothing done
## this turn can be undone any more
func _end_heroes_turn() -> void:
	assert(multiplayer.is_server())
	for character: Character in _held_abilities.keys(): _cancel_held(character)
	var pending_steps: Array[AbilityStep] = _pending_steps
	_pending_steps = []
	for step: AbilityStep in pending_steps: step.resolve_at_turn_end(_level)
	_undo_stacks.clear()
	_ability_uses.clear()
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP): character.undo_steps = 0

func _start_next_turn() -> void:
	assert(multiplayer.is_server())
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP): character.reset_movement_points()
	clear_passes()
	_clear_alerts()
	turn_number += 1

func _use_ability(character: Character, ability: Ability, target_cell: Vector2i, argument: int) -> void:
	_track(character)
	_using_character = character
	_board_changed_during_use = false
	var step: AbilityStep = ability.use(character, target_cell, argument, _level)
	_using_character = null
	character.movement_points -= step.cost
	var uses: Dictionary = _ability_uses.get_or_add(character, {})
	var used: int = uses.get(ability, 0)
	uses[ability] = used + 1
	character.count_charges(ability, 1)
	if step.acts_at_turn_end(): _pending_steps.append(step)
	if not _board_changed_during_use and step.can_be_undone():
		var undo_stack: Array = _undo_stacks.get_or_add(character, [])
		undo_stack.append(step)
	_update_undo_steps(character)

func _undo_ability(step: AbilityStep) -> void:
	var character: Character = step.character
	var undo_stack: Array = _undo_stacks[character]
	assert(undo_stack.back() == step)
	undo_stack.pop_back()
	step.undo(_level)
	character.movement_points += step.cost
	var uses: Dictionary = _ability_uses.get(character, {})
	var used: int = uses.get(step.ability, 0)
	uses[step.ability] = maxi(used - 1, 0)
	character.count_charges(step.ability, -1)
	_pending_steps.erase(step)
	_update_undo_steps(character)

func _has_uses_left(character: Character, ability: Ability) -> bool:
	if ability.get_charges_left(character) == 0: return false
	if ability.uses_per_turn <= 0: return true
	var uses: Dictionary = _ability_uses.get(character, {})
	var used: int = uses.get(ability, 0)
	return used < ability.uses_per_turn

func _cancel_held(character: Character) -> void:
	var held: HeldAbility = _end_held(character)
	if held: held.ability.cancel(character, held.target, _level)

## Forgets the held ability of [param character], used or cancelled
## @returns it, or [code]null[/code] if none was held
func _end_held(character: Character) -> HeldAbility:
	var held: HeldAbility = _held_abilities.get(character)
	if not held: return null
	_held_abilities.erase(character)
	character.active_ability_id = ""
	character.held_cost = 0
	return held

func _cancel_held_of(player_id: int) -> void:
	for character: Character in _held_abilities.keys():
		if character.is_controlled_by(player_id): _cancel_held(character)

## Characters get replaced e.g. when loading a save: their host state goes with them
func _track(character: Character) -> void:
	if character.tree_exiting.is_connected(_on_character_exiting.bind(character)): return
	character.tree_exiting.connect(_on_character_exiting.bind(character), CONNECT_ONE_SHOT)

func _update_undo_steps(character: Character) -> void:
	var undo_stack: Array = _undo_stacks.get(character, [])
	character.undo_steps = undo_stack.size()

func _set_passed(player_id: int, passed: bool) -> void:
	if passed == has_passed(player_id): return
	var new_passed_player_ids: PackedInt32Array = passed_player_ids.duplicate()
	if passed: new_passed_player_ids.append(player_id)
	else: new_passed_player_ids.remove_at(new_passed_player_ids.find(player_id))
	passed_player_ids = new_passed_player_ids

func _get_sender_id() -> int:
	var sender_id: int = multiplayer.get_remote_sender_id()
	return sender_id if sender_id != 0 else multiplayer.get_unique_id()

## @returns the [Character] at [param character_path] if [param sender_id] controls it
func _get_controlled_character(sender_id: int, character_path: NodePath) -> Character:
	var character: Character = get_node_or_null(character_path) as Character
	# While a block waits for a choice, the board holds still
	if phase != Phase.HEROES or not block_choice.is_empty() or not character or not character.visible: return null
	# Monsters belong to the host's agents, not to its player
	if character.profile.group == CharacterProfile.Groups.MONSTERS: return null
	if not character.is_controlled_by(sender_id): return null
	return character

## @returns the [Character] at [param character_path] if the sender controls it and has not passed
func _get_unpassed_character(character_path: NodePath) -> Character:
	var sender_id: int = _get_sender_id()
	if has_passed(sender_id): return null
	return _get_controlled_character(sender_id, character_path)

func _on_board_changed(character: Character) -> void:
	if character == _using_character: _board_changed_during_use = true
	_undo_stacks.erase(character)
	_update_undo_steps(character)

## The way back of other characters whose steps this turn crossed the turned tile may be closed: their steps are forgotten.
## The turning character's own steps are undone after the turn, which puts the tile back first.
func _on_tile_rotated(tile: Structure, turning_character: Character) -> void:
	var grid_position: Vector2i = tile.get_grid_position()
	for character: Character in _undo_stacks.keys():
		if character == turning_character: continue
		var crossed: bool = character.grid_cell == grid_position
		for step: RefCounted in _undo_stacks[character]:
			if step is GridStep and (step as GridStep).grid_cell == grid_position: crossed = true
		if not crossed: continue
		_undo_stacks.erase(character)
		_update_undo_steps(character)

func _on_character_exiting(character: Character) -> void:
	_undo_stacks.erase(character)
	_engaged.erase(character)
	_ability_uses.erase(character)
	# Its lifted tile is set down again, so it does not hang on for good
	_cancel_held(character)
	for step: AbilityStep in _pending_steps.duplicate():
		if step.character == character: _pending_steps.erase(step)

func _on_player_disconnected(player: Player) -> void:
	_synced_peers.erase(player.player_id)
	_cancel_held_of(player.player_id)
	_set_passed(player.player_id, false)
	_end_turn_if_everyone_passed()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _level: warnings.append("Missing Level reference.")
	if not _synchronizer: warnings.append("Missing MultiplayerSynchronizer reference.")
	return warnings
