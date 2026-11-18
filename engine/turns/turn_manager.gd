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
signal block_shown(attacker: Character, defender: Character, dice: Array[int], chosen: int, pinned: bool)
## Every peer: a block started, went on to its next stage or ended, see [member block_state]
signal block_state_changed

## The parts of a turn, in order: the players move and act; the heroes block the monsters on the tiles they share; the monsters
## move one after another; the monsters block the heroes on the tiles they share (see [method _run_monster_phase])
enum Phase {
	HEROES,
	HERO_BLOCKS,
	MONSTER_MOVES,
	MONSTER_BLOCKS,
}

const GROUP: StringName = "TurnManager"
## How often the host looks whether a monster's figure arrived, and how long it waits for one at most (a figure that never
## arrives must not hold the game)
const _HOP_POLL: float = 0.05
const _MAX_HOP_WAIT: float = 3.0
## How long a phase the heroes see waits before it acts, so its banner reads first
const _PHASE_PAUSE: float = 0.6

## Host only: how long a player has to choose for a block (see [member block_state]) before the host chooses for them; at
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
## The part of the turn under way: the players act only in [constant Phase.HEROES]; a loaded game starts with the heroes (see
## [method stop_monster_phase])
var phase: Phase = Phase.HEROES:
	set(new_phase):
		if new_phase == phase: return
		phase = new_phase
		phase_changed.emit(phase)

## The block under way and its stage (keys and stages in [BlockSequence]), set by the host and replicated, empty while none
## is. Every request but a choice for it waits meanwhile
var block_state: Dictionary = {}:
	set(new_block_state):
		if new_block_state == block_state: return
		block_state = new_block_state
		block_state_changed.emit()

## Host only: rolls the block dice and picks pushes; seed it to block the same again
var combat_random: RandomNumberGenerator = RandomNumberGenerator.new()
# Host only: the block under way
var _block_sequence: BlockSequence

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
## only if it keeps its feet and stays where it is. Stepping onto an enemy's tile ends its moves; the blocks there come in the
## monster phase (see [method _run_monster_phase]).
## [param undoable] steps go onto the character's undo stack; a block closes it. A block may wait for a player's choice
## and pauses where the heroes see it (see [BlockSequence]), so await it.
## @returns whether it stepped
func try_step(character: Character, direction: Level.Direction, undoable: bool = false) -> bool:
	assert(multiplayer.is_server())
	if character.posture != Character.Posture.STANDING:
		_stand_up(character)
		return false
	var target_cell: Vector2i = _level.get_step_target(character.grid_cell, direction)
	if target_cell == character.grid_cell or character.movement_points <= 0 or not _level.has_room(target_cell, character.profile.group, character):
		character.place_on_grid(character.grid_cell, character.tile_spot, direction)
		return false
	character.movement_points -= 1
	var leaving_blocker: Character = _get_enemy_on(character.grid_cell, character)
	if leaving_blocker:
		var block: Block = await _block(leaving_blocker, character)
		if not block or not is_instance_valid(character) or character.posture != Character.Posture.STANDING or block.was_pushed(): return false
		if not _level.has_room(target_cell, character.profile.group, character):
			# Refused like any step into a full tile: it only turns
			character.place_on_grid(character.grid_cell, character.tile_spot, direction)
			return false
	elif undoable:
		# Record before moving: a move that changes the board clears the stack again
		_track(character)
		var undo_stack: Array = _undo_stacks.get_or_add(character, [])
		undo_stack.append(GridStep.new(character))
	# The tile's formation places it (see LevelFormations)
	character.place_on_grid(target_cell, Vector2.ZERO, direction)
	if undoable: _update_undo_steps(character)
	if _get_enemy_on(target_cell, character): _engage(character)
	return true

## Host only: stepping onto an enemy's tile ends [param character]'s moves; a hero can not take the step back any more
func _engage(character: Character) -> void:
	character.movement_points = 0
	if character.profile.group != CharacterProfile.Groups.HEROES: return
	_track(character)
	# The way back is closed: the hero is in the fight
	close_undo(character)

## Host only: a fallen [param character] gets up for a movement point
func _stand_up(character: Character) -> void:
	if character.movement_points <= 0: return
	character.movement_points -= 1
	character.posture = Character.Posture.STANDING

## Host only: [param attacker] blocks [param defender], played out by a [BlockSequence] in stages every peer follows.
## @returns the block, or [code]null[/code] if the game moved on before the strike (a save loaded, a figure gone)
func _block(attacker: Character, defender: Character) -> Block:
	var sequence: BlockSequence = BlockSequence.new(self, _level, attacker, defender)
	_block_sequence = sequence
	var block: Block = await sequence.run()
	if _block_sequence == sequence: _block_sequence = null
	return block

## Host only: every peer that syncs this node sees [param block]'s attacker strike, with its dice and the face that counts
func broadcast_block(block: Block) -> void:
	var dice: Array[int] = []
	dice.assign(block.dice)
	var attacker_path: NodePath = block.attacker.get_path()
	var defender_path: NodePath = block.defender.get_path()
	show_block(attacker_path, defender_path, dice, block.chosen, block.pinned)
	for peer_id: int in _synced_peers:
		if peer_id != multiplayer.get_unique_id(): show_block.rpc_id(peer_id, attacker_path, defender_path, dice, block.chosen, block.pinned)

## Every peer: [param attacker_path]'s figure strikes at [param defender_path]'s; the host calls it on itself and sends it to the
## peers that have this node
@rpc("authority", "call_remote", "reliable")
func show_block(attacker_path: NodePath, defender_path: NodePath, dice: Array[int], chosen: int, pinned: bool) -> void:
	var attacker: Character = get_node_or_null(attacker_path) as Character
	var defender: Character = get_node_or_null(defender_path) as Character
	if not attacker or not defender: return
	attacker.show_block(defender)
	block_shown.emit(attacker, defender, dice, chosen, pinned)

## The player asked to choose for the block under way (see [member block_state]) chooses [param value], a die's index, for the
## choice numbered [param choice_id]; see [method BlockSequence.answer]
@rpc("any_peer", "call_local", "reliable")
func request_block_choice(choice_id: int, value: int) -> void:
	if not multiplayer.is_server() or not _block_sequence: return
	_block_sequence.answer(_get_sender_id(), choice_id, value)

## Host only: a block under way is dropped, e.g. as a save is loaded; one not yet struck does not happen
func _cancel_block() -> void:
	if _block_sequence: _block_sequence.cancel()
	_block_sequence = null
	block_state = {}

## @returns the standing enemy of [param character] on [param cell] who blocks it (its side's lead, see [method Level.get_lead]),
## or [code]null[/code]
func _get_enemy_on(cell: Vector2i, character: Character) -> Character:
	var other_group: CharacterProfile.Groups = CharacterProfile.Groups.MONSTERS
	if character.profile.group == CharacterProfile.Groups.MONSTERS: other_group = CharacterProfile.Groups.HEROES
	return _level.get_lead(cell, other_group)

func close_undo(character: Character) -> void:
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
	# Others may have filled the old tile meanwhile
	if not _level.has_room(previous_step.grid_cell, character.profile.group, character): return
	undo_stack.pop_back()
	character.movement_points += 1
	# Keep facing the way the step went: the figure walks back, which shows it is an undo
	var step_direction: Level.Direction = Level.get_direction(previous_step.grid_cell, character.grid_cell)
	character.place_on_grid(previous_step.grid_cell, previous_step.tile_spot, step_direction)
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
	if not multiplayer.is_server() or not is_heroes_turn() or not block_state.is_empty(): return
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
	# Not while a block is under way: the step it belongs to ends first, then checks again (see request_move)
	if not is_heroes_turn() or not block_state.is_empty(): return
	for player: Player in Lobby.get_connected_players():
		if not has_passed(player.player_id): return
	_run_monster_phase()

## Host only: the heroes' turn ends, then the phases after it run in order (see [enum Phase]): the heroes' blocks on every tile
## they share with monsters, every monster's moves, then the monsters' blocks (see [method _block_on_shared_tiles]); a phase the
## heroes see something of pauses first. The next turn starts once all is done. Players' requests wait meanwhile.
func _run_monster_phase() -> void:
	assert(multiplayer.is_server())
	_end_heroes_turn()
	_monster_phase_run += 1
	var run: int = _monster_phase_run
	await _enter_phase(Phase.HERO_BLOCKS, _has_shared_tile_in_sight())
	if run != _monster_phase_run: return
	await _block_on_shared_tiles(CharacterProfile.Groups.HEROES)
	if run != _monster_phase_run: return
	await _enter_phase(Phase.MONSTER_MOVES, _has_monster_in_sight())
	if run != _monster_phase_run: return
	await _move_monsters()
	if run != _monster_phase_run: return
	await _enter_phase(Phase.MONSTER_BLOCKS, _has_shared_tile_in_sight())
	if run != _monster_phase_run: return
	await _block_on_shared_tiles(CharacterProfile.Groups.MONSTERS)
	if run != _monster_phase_run: return
	phase = Phase.HEROES
	_start_next_turn()

## @returns whether the players act now (see [enum Phase])
func is_heroes_turn() -> bool:
	return phase == Phase.HEROES

## Host only: sets [param next_phase]; one [param in_sight] of the heroes pauses a moment before it acts
func _enter_phase(next_phase: Phase, in_sight: bool) -> void:
	phase = next_phase
	if in_sight: await create_tween().tween_interval(_PHASE_PAUSE).finished

## Host only: each monster in turn steps as its [Agent] chooses (see [method Agent.choose_step]) until it is out of movement
## points or stops (on a hero's tile, its moves end). The host waits for each hop the heroes can see (from or onto a revealed
## tile); hidden monsters move at once.
func _move_monsters() -> void:
	var run: int = _monster_phase_run
	# Pieces may leave while the host waits (a player leaving takes their hero along): each is checked before it is used
	# By index: a figure freed meanwhile may not go into a typed variable
	var monsters: Array[Character] = _get_monsters()
	for index: int in monsters.size():
		if not is_instance_valid(monsters[index]): continue
		var monster: Character = monsters[index]
		if not monster.is_inside_tree() or not monster.visible: continue
		var agent: Agent = monster.get_parent() as Agent
		_alert_heroes_seen_by(monster)
		while is_instance_valid(monster) and monster.is_inside_tree() and monster.movement_points > 0:
			var was_in_sight: bool = is_in_sight(monster.grid_cell)
			if monster.posture != Character.Posture.STANDING:
				_stand_up(monster)
				continue
			var direction: int = agent.choose_step()
			if direction < 0: break
			# A block on leaving plays out within the step (see BlockSequence)
			var stepped: bool = await try_step(monster, direction as Level.Direction)
			if run != _monster_phase_run: return
			if stepped and (was_in_sight or is_in_sight(monster.grid_cell)):
				await wait_for_figure(monster)
				if run != _monster_phase_run: return
			if not stepped: break
			# Once it hopped in: the heroes react to what they see
			if is_instance_valid(monster): _alert_heroes_seen_by(monster)

## @returns whether a monster that may still move stands where the heroes see it
func _has_monster_in_sight() -> bool:
	for monster: Character in _get_monsters():
		if monster.movement_points > 0 and is_in_sight(monster.grid_cell): return true
	return false

## @returns whether standing heroes and monsters meet on a tile the heroes see
func _has_shared_tile_in_sight() -> bool:
	for cell: Vector2i in _get_shared_cells():
		if is_in_sight(cell): return true
	return false

## @returns the cells where standing heroes and monsters meet, in the monsters' turn order
func _get_shared_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for monster: Character in _get_monsters():
		if monster.posture == Character.Posture.STANDING and not cells.has(monster.grid_cell) and _get_enemy_on(monster.grid_cell, monster): cells.append(monster.grid_cell)
	return cells

## Host only: the monsters on the board (not those turned off, see [member Level.monsters_enabled]), in turn order
func _get_monsters() -> Array[Character]:
	var monsters: Array[Character] = []
	for node: Node in get_tree().get_nodes_in_group(Character.GROUP):
		var character: Character = node as Character
		if not character or not character.visible or not character.get_parent() is Agent: continue
		if character.profile.group == CharacterProfile.Groups.MONSTERS: monsters.append(character)
	return monsters

## Host only: [param group]'s side blocks on every tile where standing heroes and monsters meet, in the monsters' turn order.
## The heroes' lead (see [method Level.get_lead]) blocks every standing monster there once; a lead knocked down hands over to the next.
## The monsters' lead blocks the heroes' lead; only if it is knocked down does the next monster block. Waits for each block the
## heroes can see.
func _block_on_shared_tiles(group: CharacterProfile.Groups) -> void:
	var run: int = _monster_phase_run
	for cell: Vector2i in _get_shared_cells():
		var monsters: Array[Character] = []
		for monster: Character in Formation.by_priority(Block.get_standing_on(cell, _level)):
			if monster.profile.group == CharacterProfile.Groups.MONSTERS: monsters.append(monster)
		for index: int in monsters.size():
			# Figures may fall, be pushed away or leave while the host waits; one freed may not go into a typed variable
			if not is_instance_valid(monsters[index]): continue
			var monster: Character = monsters[index]
			if monster.posture != Character.Posture.STANDING or monster.grid_cell != cell: continue
			var hero: Character = _level.get_lead(cell, CharacterProfile.Groups.HEROES)
			if not hero: break
			var by_heroes: bool = group == CharacterProfile.Groups.HEROES
			# Each block pauses where the heroes see it (see BlockSequence)
			if by_heroes: await _block(hero, monster)
			else: await _block(monster, hero)
			if run != _monster_phase_run: return
			# The monsters' lead blocks alone as long as it keeps its feet
			if not by_heroes and is_instance_valid(monster) and monster.posture == Character.Posture.STANDING: break

## Host only: a monster phase under way stops where it waits, e.g. as a save is loaded; the heroes act again, and no turn ends
func stop_monster_phase() -> void:
	assert(multiplayer.is_server())
	_monster_phase_run += 1
	phase = Phase.HEROES
	_cancel_block()
	_clear_alerts()

## Waits until [param character]'s figure arrived, at most [constant _MAX_HOP_WAIT]: its hop may last longer than its move
## animation (delays, body animations). Tweens, not timers: they go with this node (e.g. leaving the game), so nothing resumes
## on a freed one
func wait_for_figure(character: Character) -> void:
	var waited: float = 0.0
	while is_instance_valid(character) and character.is_figure_moving() and waited < _MAX_HOP_WAIT:
		await create_tween().tween_interval(_HOP_POLL).finished
		waited += _HOP_POLL

## Every hero [param monster] sees, as it comes for them where the heroes see it (on a revealed tile), is on alert, see
## [member Character.alerted]
func _alert_heroes_seen_by(monster: Character) -> void:
	if not is_in_sight(monster.grid_cell): return
	var in_sight: Dictionary[Vector2i, bool] = _level.get_cells_in_sight(monster.grid_cell, monster.get_perception())
	for node: Node in get_tree().get_nodes_in_group(Character.GROUP):
		var hero: Character = node as Character
		if not hero or not hero.visible or hero.level != _level or hero.profile.group != CharacterProfile.Groups.HEROES: continue
		if in_sight.has(hero.grid_cell): hero.alerted = true

## After the passes are cleared: a hero that also stops showing its pass then goes straight from its alert to its idles
func _clear_alerts() -> void:
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP): character.alerted = false

## @returns whether the heroes see what happens on [param cell] (its tile is revealed)
func is_in_sight(cell: Vector2i) -> bool:
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
	# While a block is under way, the board holds still
	if not is_heroes_turn() or not block_state.is_empty() or not character or not character.visible: return null
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
