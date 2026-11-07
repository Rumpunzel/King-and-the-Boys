extends Node
## Headless checks for the turn rules (gdUnit4 is not installed in this project).
## Run: godot --headless --path . --script res://test/run_tests.gd
## Exit code = number of failed checks.

const LEVEL_SCENE: String = "res://data/levels/level.tscn"
const HERO_PROFILE: String = "res://data/characters/people/dwarf.tres"

var _failures: int = 0
var _level: Level
var _turn_manager: TurnManager

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_choose_spot()
	await _setup_world()
	await _test_movement_points()
	await _test_wall_only_turns()
	await _test_undo()
	await _test_shared_tile_spots()
	await _test_pass_and_unpass()
	print("TURN TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(_failures)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
		return
	_failures += 1
	printerr("FAIL ", description)

func _test_choose_spot() -> void:
	_check(Level.choose_spot([]) == Level.CENTER_SPOT, "first piece on an empty tile takes the center")
	_check(Level.choose_spot([0]) == 1, "second piece takes the first corner")
	_check(Level.choose_spot([0, 1, 2]) == 3, "later pieces take the next free corner")
	_check(Level.choose_spot([1, 2, 3, 4]) == Level.CENTER_SPOT, "center is used when only it is free")
	_check(Level.choose_spot([3]) == 1, "a free center is not taken while others stand on the tile")
	_check(Level.choose_spot([0, 1, 2, 3, 4]) == Level.NO_SPOT, "a full tile has no spot")

func _setup_world() -> void:
	Lobby.call("_create_local_player")
	await get_tree().process_frame
	_level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child(_level)
	_level.build_level()
	_turn_manager = TurnManager.new()
	_turn_manager.set("_level", _level)
	add_child(_turn_manager)
	await get_tree().process_frame

func _spawn_hero(grid_cell: Vector2i) -> Character:
	var profile: CharacterProfile = load(HERO_PROFILE)
	var hero: Character = profile.create(0, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(grid_cell)))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await get_tree().process_frame
	return hero

func _start_cell() -> Vector2i:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position((spawn_points.front() as Node3D).global_position)

## @returns a direction with a passage out of [param cell], or -1
func _open_direction(cell: Vector2i) -> int:
	for direction: Level.Direction in Level.Direction.values():
		if _level.get_step_target(cell, direction) != cell: return direction
	return -1

func _blocked_direction(cell: Vector2i) -> int:
	for direction: Level.Direction in Level.Direction.values():
		if _level.get_step_target(cell, direction) == cell: return direction
	return -1

func _move(hero: Character, direction: int) -> void:
	_turn_manager.request_move(hero.get_path(), direction as Level.Direction)
	await get_tree().process_frame

func _undo(hero: Character) -> void:
	_turn_manager.request_undo(hero.get_path())
	await get_tree().process_frame

func _test_movement_points() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	_check(hero.movement_points == hero.profile.speed, "a new character starts with speed movement points")
	var direction: int = _open_direction(hero.grid_cell)
	_check(direction >= 0, "the start tile has a passage")
	var start: Vector2i = hero.grid_cell
	var board_changes: Array[Character] = []
	_level.board_changed.connect(board_changes.append)
	await _move(hero, direction)
	_level.board_changed.disconnect(board_changes.append)
	_check(hero.grid_cell == start + Level.direction_to_vector(direction), "a step moves one cell")
	_check(board_changes == [hero], "the first step into the fresh dungeon changes the board")
	_check(hero.movement_points == hero.profile.speed - 1, "a step costs one point")
	# Walk back and forth until the points run out
	var guard: int = 0
	while hero.movement_points > 0 and guard < 32:
		guard += 1
		var back: int = _open_direction(hero.grid_cell)
		await _move(hero, back)
	var cell_without_points: Vector2i = hero.grid_cell
	await _move(hero, _open_direction(hero.grid_cell))
	_check(hero.grid_cell == cell_without_points, "no step without points left")
	hero.queue_free()
	await get_tree().process_frame
	_turn_manager._start_next_turn()

## @returns a placed, walkable tile next to a wall near the start
func _cell_next_to_wall() -> Vector2i:
	for radius: int in range(1, 6):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var cell: Vector2i = _start_cell() + Vector2i(x, y)
				var tile: Structure = _level.get_placed_tile(cell)
				if not tile or tile.get_connections().is_empty(): continue
				if _blocked_direction(cell) >= 0: return cell
	return _start_cell()

func _test_wall_only_turns() -> void:
	var hero: Character = await _spawn_hero(_cell_next_to_wall())
	var wall: int = _blocked_direction(hero.grid_cell)
	if wall < 0:
		print("SKIP walls: start tile is open on all sides")
	else:
		var points: int = hero.movement_points
		var cell: Vector2i = hero.grid_cell
		await _move(hero, wall)
		_check(hero.grid_cell == cell and hero.movement_points == points, "walking into a wall costs nothing")
		_check(hero.facing == wall, "walking into a wall turns the character")
	hero.queue_free()
	await get_tree().process_frame
	_turn_manager._start_next_turn()

func _test_undo() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var start: Vector2i = hero.grid_cell
	var out: int = _open_direction(start)
	await _move(hero, out)
	var first_cell: Vector2i = hero.grid_cell
	# Stepping back onto the explored start tile should not change the board
	await _move(hero, Level.get_direction(first_cell, start))
	_check(hero.grid_cell == start, "stepped back to the start")
	var points: int = hero.movement_points
	await _undo(hero)
	_check(hero.grid_cell == first_cell, "undo takes back the last step")
	_check(hero.movement_points == points + 1, "undo refunds the point")
	# A step that changed the board can not be undone
	await _move(hero, Level.get_direction(first_cell, start))
	_level.board_changed.emit(hero)
	await _undo(hero)
	_check(hero.grid_cell == start, "undo stops at a step that changed the board")
	_turn_manager._start_next_turn()
	await _move(hero, Level.get_direction(start, first_cell))
	_turn_manager._start_next_turn()
	await _undo(hero)
	_check(hero.grid_cell == first_cell, "undo can not reach into the previous turn")
	hero.queue_free()
	await get_tree().process_frame
	_turn_manager._start_next_turn()

func _test_shared_tile_spots() -> void:
	var first: Character = await _spawn_hero(_start_cell())
	var second: Character = await _spawn_hero(_start_cell())
	_check(first.tile_spot == Level.CENTER_SPOT, "first piece on the tile stands in the center")
	_check(second.tile_spot == 1, "second piece on the tile stands in a corner")
	_check(not second.global_position.is_equal_approx(first.global_position), "pieces on one tile do not overlap")
	var serializer: SynchronizerSerializer = second.get_node(^"CharacterSynchronizer/SynchronizerSerializer")
	var saved: Dictionary[NodePath, Variant] = serializer.collect_properties()
	var saved_names: Array[String] = []
	for property_path: NodePath in saved: saved_names.append(String(property_path.get_concatenated_subnames()))
	_check(saved_names.has("grid_cell") and saved_names.has("tile_spot") and saved_names.has("facing") and saved_names.has("movement_points"), "grid state and points are saved")
	for property_path: NodePath in saved:
		if String(property_path.get_concatenated_subnames()) == "tile_spot": _check(saved[property_path] as int == 1, "the saved spot matches")
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	_turn_manager._start_next_turn()

func _test_pass_and_unpass() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var local_id: int = _turn_manager.multiplayer.get_unique_id()
	var other: Player = Player.create(2, "Other")
	(Lobby.get("_players") as Dictionary)[2] = other
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	_check(_turn_manager.has_passed(local_id), "pass is recorded")
	_check(_turn_manager.turn_number == turn, "the turn waits for the other player")
	await _move(hero, _open_direction(hero.grid_cell))
	_check(hero.movement_points == hero.profile.speed, "a passed player can not move")
	_turn_manager.request_pass(false)
	_check(not _turn_manager.has_passed(local_id), "a pass can be taken back")
	_turn_manager.request_pass(true)
	(Lobby.get("_players") as Dictionary).erase(2)
	Lobby.player_disconnected.emit(other)
	_check(_turn_manager.turn_number == turn + 1, "the turn ends when the last other player disconnects")
	_check(not _turn_manager.has_passed(local_id), "passes reset with the new turn")
	_check(hero.movement_points == hero.profile.speed, "points reset with the new turn")
	other.free()
	hero.queue_free()
	await get_tree().process_frame
