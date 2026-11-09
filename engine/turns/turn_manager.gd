@tool
class_name TurnManager
extends Node
## Runs simultaneous turns: every player moves their [Character]s up to their movement points,
## may undo steps, and passes. The turn ends once every connected player has passed.
## The host is the referee; peers send requests and follow the replicated state.

signal turn_started(turn_number: int)
signal passed_players_changed

const GROUP: StringName = "TurnManager"

@export_group("Configuration")
@export var _level: Level
## Hidden from peers until their [TurnManager] exists, see [method start_syncing_peers]
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

# Host only: steps that can still be undone this turn, newest last
var _undo_stacks: Dictionary[Character, Array] = {}

class GridStep extends RefCounted:
	var grid_cell: Vector2i
	var tile_spot: Vector2

	func _init(character: Character) -> void:
		grid_cell = character.grid_cell
		tile_spot = character.tile_spot

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
	Lobby.player_disconnected.connect(_on_player_disconnected)

## Host only: this node is part of the game scene, not spawned, so peers only get synced
## once they have loaded it; call when every peer has, e.g. from [method Game.setup_game]
func start_syncing_peers() -> void:
	assert(multiplayer.is_server())
	for peer_id: int in multiplayer.get_peers(): _synchronizer.set_visibility_for(peer_id, true)

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
	if not character: return
	var target_cell: Vector2i = _level.get_step_target(character.grid_cell, direction)
	var free_spots: Array[Vector2] = _level.get_free_spots(target_cell, character)
	if target_cell == character.grid_cell or character.movement_points <= 0 or free_spots.is_empty():
		character.place_on_grid(character.grid_cell, character.tile_spot, direction)
		return
	# Record before moving: a move that changes the board clears the stack again
	if not _undo_stacks.has(character) and not character.tree_exiting.is_connected(_on_character_exiting.bind(character)):
		# Characters get replaced e.g. when loading a save
		character.tree_exiting.connect(_on_character_exiting.bind(character), CONNECT_ONE_SHOT)
	var undo_stack: Array = _undo_stacks.get_or_add(character, [])
	undo_stack.append(GridStep.new(character))
	character.movement_points -= 1
	var target_spot: Vector2 = free_spots.front()
	character.place_on_grid(target_cell, target_spot, direction)
	_update_undo_steps(character)

## Takes back the last step of [param character_path] this turn and refunds its movement point.
## A pass of the sender is taken back with it, but only if the step could be undone.
@rpc("any_peer", "call_local", "reliable")
func request_undo(character_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = _get_sender_id()
	var character: Character = _get_controlled_character(sender_id, character_path)
	if not character: return
	var undo_stack: Array = _undo_stacks.get(character, [])
	if undo_stack.is_empty(): return
	var previous_step: GridStep = undo_stack.back()
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

## Passes or takes a pass back; the turn ends once every connected player has passed
@rpc("any_peer", "call_local", "reliable")
func request_pass(passed: bool) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = _get_sender_id()
	if not Lobby.get_player(sender_id): return
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
	for player: Player in Lobby.get_connected_players():
		if not has_passed(player.player_id): return
	_start_next_turn()

## Host only: player ids differ between sessions, so passes do not survive loading a game
func clear_passes() -> void:
	assert(multiplayer.is_server())
	passed_player_ids = PackedInt32Array()

func _start_next_turn() -> void:
	assert(multiplayer.is_server())
	_undo_stacks.clear()
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		character.reset_movement_points()
		character.undo_steps = 0
	clear_passes()
	turn_number += 1

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
	if not character or not character.visible: return null
	if not character.is_controlled_by(sender_id): return null
	return character

func _on_board_changed(character: Character) -> void:
	_undo_stacks.erase(character)
	_update_undo_steps(character)

func _on_character_exiting(character: Character) -> void:
	_undo_stacks.erase(character)

func _on_player_disconnected(player: Player) -> void:
	_set_passed(player.player_id, false)
	_end_turn_if_everyone_passed()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _level: warnings.append("Missing Level reference.")
	if not _synchronizer: warnings.append("Missing MultiplayerSynchronizer reference.")
	return warnings
