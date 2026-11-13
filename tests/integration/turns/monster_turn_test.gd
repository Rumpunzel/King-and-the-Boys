extends GdUnitTestSuite
## The monster phase: once every player passed, each monster steps as its agent chooses (hunting a hero it sees along
## passages, wandering otherwise) through the same step rule as the players, then the next turn starts

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
## Frames a monster phase may take before a test gives up on it
const MAX_FRAMES: int = 600

var _level: Level
var _turn_manager: TurnManager

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	_turn_manager = auto_free(TurnManager.new())
	_turn_manager.set("_level", _level)
	_turn_manager.combat_random.seed = 42
	add_child(_turn_manager)
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _start_cell() -> Vector2i:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position(spawn_point.global_position)

func _spawn_hero(cell: Vector2i) -> Character:
	var hero: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell))))
	hero.level = _level
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

func _spawn_monster(cell: Vector2i) -> Character:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var agents: Array[Node] = (_level.get("_agent_spawner") as AgentSpawner).get_children()
	return (agents.back() as Agent).character

## @returns the cells exactly [param steps] steps from [param from] along passages
func _cells_at(from: Vector2i, steps: int) -> Array[Vector2i]:
	var distances: Dictionary[Vector2i, int] = {from: 0}
	var frontier: Array[Vector2i] = [from]
	for distance: int in steps:
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for direction: Level.Direction in Level.Direction.values():
				var neighbour: Vector2i = _level.get_step_target(cell, direction)
				if distances.has(neighbour): continue
				distances[neighbour] = distance + 1
				next_frontier.append(neighbour)
		frontier = next_frontier
	return frontier

func _cell_at(steps: int) -> Vector2i:
	var cells: Array[Vector2i] = _cells_at(_start_cell(), steps)
	assert(not cells.is_empty())
	return cells.front()

## @returns a cell [param steps] steps straight from the start along passages, so heroes there see it (vision 3)
func _cell_in_sight(steps: int) -> Vector2i:
	var start: Vector2i = _start_cell()
	for direction: Level.Direction in Level.Direction.values():
		var cell: Vector2i = start
		for _step: int in steps:
			if not _level.is_passage(cell, direction): break
			cell += Level.direction_to_vector(direction)
		if cell == start + Level.direction_to_vector(direction) * steps: return cell
	assert(false, "No straight passage of %d steps from the start" % steps)
	return start

## Passes for the local player and waits until the monsters are done and the next turn started
func _pass_turn() -> void:
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: return
		await await_idle_frame()
	fail("The monster phase did not end")

func test_monsters_act_once_every_player_passed() -> void:
	var monster: Character = await _spawn_monster(_cell_at(2))
	var cell: Vector2i = monster.grid_cell
	# Not a player's piece, not even the host's
	for direction: Level.Direction in Level.Direction.values(): _turn_manager.request_move(monster.get_path(), direction)
	assert_that(monster.grid_cell).is_equal(cell)
	await _pass_turn()
	assert_that(monster.grid_cell).is_not_equal(cell)
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	assert_int(monster.movement_points).is_equal(monster.profile.speed)

func test_monsters_step_along_passages_only() -> void:
	var monster: Character = await _spawn_monster(_cell_at(3))
	var path: Array[Vector2i] = [monster.grid_cell]
	monster.entered_grid_cell.connect(func(cell: Vector2i) -> void: path.append(cell))
	for _turn: int in 5: await _pass_turn()
	assert_int(path.size()).is_greater(1)
	for index: int in range(1, path.size()):
		var from: Vector2i = path[index - 1]
		var direction: Level.Direction = Level.get_direction(from, path[index])
		assert_that(from + Level.direction_to_vector(direction)).is_equal(path[index])
		assert_bool(_level.is_passage(from, direction)).override_failure_message("A monster went from %s to %s through a wall" % [from, path[index]]).is_true()

func test_a_monster_hunts_a_hero_it_sees() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	var monster: Character = await _spawn_monster(_cell_in_sight(2))
	var blocks: Array[Block] = []
	_turn_manager.blocked.connect(func(block: Block) -> void: blocks.append(block))
	var hero_cell: Vector2i = hero.grid_cell
	await _pass_turn()
	# Two steps along passages, its speed: onto the hero's tile, where it blocks the hero at once
	assert_that(monster.grid_cell).is_equal(hero_cell)
	assert_int(blocks.size()).is_equal(1)
	assert_object(blocks[0].attacker).is_same(monster)
	assert_object(blocks[0].defender).is_same(hero)

func test_players_wait_while_monsters_act() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	await _spawn_monster(_cell_in_sight(2))
	_turn_manager.request_pass(true)
	# The hunt's first hop is in sight, so the host waits for it
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.MONSTERS)
	var cell: Vector2i = hero.grid_cell
	for direction: Level.Direction in Level.Direction.values(): _turn_manager.request_move(hero.get_path(), direction)
	_turn_manager.request_pass(false)
	assert_that(hero.grid_cell).is_equal(cell)
	assert_bool(_turn_manager.has_passed(multiplayer.get_unique_id())).is_true()
	for _frame: int in MAX_FRAMES:
		if _turn_manager.phase == TurnManager.Phase.HEROES: break
		await await_idle_frame()
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	assert_bool(_turn_manager.has_passed(multiplayer.get_unique_id())).is_false()

func test_a_hidden_monster_moves_at_once() -> void:
	var far: Vector2i = _cell_at(4)
	var monster: Character = await _spawn_monster(far)
	assert_bool(monster.shown).is_false()
	await _pass_turn()
	await await_idle_frame()
	# Only the start tile is revealed: it is still out of sight, and already where its grid state says
	assert_bool(monster.shown).is_false()
	assert_vector(monster.global_position).is_equal_approx(_level.get_spot_position(monster.grid_cell, monster.tile_spot), Vector3.ONE * 0.001)

func test_a_piece_leaving_during_the_monster_phase_stalls_nothing() -> void:
	# The monster first, the hero after it: the phase meets the hero only after it has gone
	var monster: Character = await _spawn_monster(_cell_in_sight(2))
	var hero: Character = await _spawn_hero(_start_cell())
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.MONSTERS)
	# As a player leaving takes their hero along
	remove_child(hero)
	hero.free()
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: break
		await await_idle_frame()
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	assert_bool(is_instance_valid(monster)).is_true()

func test_loading_stops_the_monster_phase() -> void:
	await _spawn_hero(_start_cell())
	await _spawn_monster(_cell_in_sight(2))
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.MONSTERS)
	# As Game.load_game does
	_turn_manager.stop_monster_phase()
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	# The phase that was waiting ends no turn
	for _frame: int in 120: await await_idle_frame()
	assert_int(_turn_manager.turn_number).is_equal(turn)

func test_the_heroes_turn_ends_before_the_monsters_act() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	await _spawn_monster(_cell_in_sight(2))
	# Out and back: the first step reveals tiles, which closes the way back; the second can be undone
	var out: Level.Direction = Level.get_direction(_start_cell(), _cell_in_sight(1))
	_turn_manager.request_move(hero.get_path(), out)
	await await_idle_frame()
	_turn_manager.request_move(hero.get_path(), Level.get_opposite(out))
	await await_idle_frame()
	assert_int(hero.undo_steps).is_equal(1)
	_turn_manager.request_pass(true)
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.MONSTERS)
	assert_int(hero.undo_steps).is_zero()

func test_the_host_waits_for_a_monster_stepping_out_of_sight() -> void:
	# Only the start tile is revealed: wherever the monster goes, it leaves the heroes' sight
	var monster: Character = await _spawn_monster(_start_cell())
	_turn_manager.request_pass(true)
	assert_that(monster.grid_cell).is_not_equal(_start_cell())
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.MONSTERS)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.phase == TurnManager.Phase.HEROES: break
		await await_idle_frame()
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)

func test_a_hero_a_monster_comes_for_is_on_alert_until_the_next_turn() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	await _spawn_monster(_cell_in_sight(2))
	assert_bool(hero.alerted).is_false()
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	# The monster starts on a tile the hero has not revealed: the hero reacts once it hopped into sight, not as it sets off
	assert_bool(hero.alerted).is_false()
	var alerted_in_phase: Array[bool] = [false]
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: break
		alerted_in_phase[0] = alerted_in_phase[0] or (hero.alerted and _turn_manager.phase == TurnManager.Phase.MONSTERS)
		await await_idle_frame()
	assert_bool(alerted_in_phase[0]).is_true()
	assert_bool(hero.alerted).is_false()

func test_a_monster_out_of_sight_alerts_nobody() -> void:
	var hero: Character = await _spawn_hero(_start_cell())
	# Far off on tiles no hero revealed: whatever it sees, the heroes do not see it coming
	var monster: Character = await _spawn_monster(_cell_at(5))
	var alerted: Array[bool] = [false]
	_turn_manager.phase_changed.connect(func(_phase: TurnManager.Phase) -> void: alerted[0] = alerted[0] or hero.alerted)
	await _pass_turn()
	assert_bool(_level.get_placed_tile(monster.grid_cell).status == Structure.Status.REVEALED).is_false()
	assert_bool(alerted[0] or hero.alerted).is_false()
