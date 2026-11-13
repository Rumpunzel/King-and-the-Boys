extends GdUnitTestSuite
## Blocks on a generated level: engaging, the heroes' blocks as the monster phase starts, blocks on leaving, what each face
## does, assists, and getting up again

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
## Frames a monster phase may take before a test gives up on it
const MAX_FRAMES: int = 600

var _level: Level
var _turn_manager: TurnManager
var _blocks: Array[Block] = []

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
	_blocks.clear()
	_turn_manager.blocked.connect(func(block: Block) -> void: _blocks.append(block))
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

## @returns a direction with a passage out of [param cell] onto a tile with room
func _way_out(cell: Vector2i) -> Level.Direction:
	for direction: Level.Direction in Level.Direction.values():
		if _level.is_passage(cell, direction) and not _level.get_free_spots(cell + Level.direction_to_vector(direction)).is_empty(): return direction
	assert(false, "No way out of %s" % cell)
	return Level.Direction.UP

func _pass_turn() -> void:
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: return
		await await_idle_frame()
	fail("The monster phase did not end")

func test_stepping_onto_a_monsters_tile_ends_the_heros_moves_for_good() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var monster_cell: Vector2i = start + Level.direction_to_vector(way)
	var hero: Character = await _spawn_hero(start)
	await _spawn_monster(monster_cell)
	_turn_manager.request_move(hero.get_path(), way)
	await await_idle_frame()
	assert_that(hero.grid_cell).is_equal(monster_cell)
	assert_int(hero.movement_points).is_zero()
	assert_int(hero.undo_steps).is_zero()
	assert_array(_blocks).is_empty()

func test_an_engaged_hero_blocks_as_the_monster_phase_starts() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start + Level.direction_to_vector(way))
	_turn_manager.request_move(hero.get_path(), way)
	await await_idle_frame()
	await _pass_turn()
	assert_int(_blocks.size()).is_greater_equal(1)
	assert_object(_blocks[0].attacker).is_same(hero)
	assert_object(_blocks[0].defender).is_same(monster)
	assert_int(_blocks[0].dice.size()).is_equal(Block.count_dice(hero.profile.strength, monster.profile.strength))
	assert_bool(_blocks[0].dice.has(_blocks[0].chosen)).is_true()

func test_leaving_an_enemys_tile_takes_a_block_first() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await await_idle_frame()
	assert_int(_blocks.size()).is_equal(1)
	var block: Block = _blocks[0]
	assert_object(block.attacker).is_same(monster)
	assert_object(block.defender).is_same(hero)
	var kept_on: bool = hero.posture == Character.Posture.STANDING and not block.was_pushed()
	assert_bool(hero.grid_cell != start).is_equal(kept_on or block.was_pushed())
	# The step was spent either way
	assert_int(hero.movement_points).is_equal(hero.profile.speed - 1)

func test_each_face_plays_out() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	Block.new(hero, monster).apply(Block.Face.ATTACKER_DOWN, _level, random)
	assert_int(hero.posture).is_equal(Character.Posture.DOWN)
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)
	hero.posture = Character.Posture.STANDING
	Block.new(hero, monster).apply(Block.Face.BOTH_DOWN, _level, random)
	assert_array([hero.posture, monster.posture]).is_equal([Character.Posture.DOWN, Character.Posture.DOWN])
	hero.posture = Character.Posture.STANDING
	monster.posture = Character.Posture.STANDING
	var push: Block = Block.new(hero, monster)
	push.apply(Block.Face.PUSH, _level, random)
	assert_bool(push.was_pushed()).is_true()
	assert_that(monster.grid_cell).is_equal(push.pushed_to)
	assert_bool(_level.get_cells_in_reach(start).has(monster.grid_cell)).is_true()
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)
	# The attacker does not follow
	assert_that(hero.grid_cell).is_equal(start)
	var down: Block = Block.new(monster, hero)
	down.apply(Block.Face.DEFENDER_DOWN, _level, random)
	assert_int(hero.posture).is_equal(Character.Posture.DOWN)
	assert_bool(down.was_pushed()).is_true()

func test_a_stumbling_defender_falls_only_if_clumsier() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	# Equally agile: it keeps its feet
	Block.new(hero, monster).apply(Block.Face.DEFENDER_STUMBLES, _level, random)
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)

func test_a_push_with_nowhere_to_go_leaves_the_defender_where_it_is() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	# Fill every tile next door
	for direction: Level.Direction in Level.Direction.values():
		if not _level.is_passage(start, direction): continue
		var cell: Vector2i = start + Level.direction_to_vector(direction)
		for _spot: int in _level.get_free_spots(cell).size(): await _spawn_monster(cell)
	var push: Block = Block.new(hero, monster)
	push.apply(Block.Face.PUSH, _level, RandomNumberGenerator.new())
	assert_bool(push.was_pushed()).is_false()
	assert_that(monster.grid_cell).is_equal(start)

func test_allies_on_the_tile_assist_unless_more_enemies_stand_there() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var ally: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	assert_int(Block.get_strength(hero, _level)).is_equal(hero.profile.strength + 1)
	assert_int(Block.get_strength(monster, _level)).is_equal(monster.profile.strength)
	# A second monster keeps the ally busy
	await _spawn_monster(start)
	assert_int(Block.get_strength(hero, _level)).is_equal(hero.profile.strength)
	# A fallen ally assists nobody
	ally.posture = Character.Posture.DOWN
	assert_int(Block.get_strength(monster, _level)).is_equal(monster.profile.strength + 1)

func test_a_fallen_figure_gets_up_for_a_move_instead_of_stepping() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	hero.posture = Character.Posture.DOWN
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await await_idle_frame()
	assert_int(hero.posture).is_equal(Character.Posture.STANDING)
	assert_that(hero.grid_cell).is_equal(start)
	assert_int(hero.movement_points).is_equal(hero.profile.speed - 1)

func test_a_fallen_monster_gets_up_in_its_phase() -> void:
	var monster: Character = await _spawn_monster(_start_cell())
	monster.posture = Character.Posture.DOWN
	await _pass_turn()
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)
