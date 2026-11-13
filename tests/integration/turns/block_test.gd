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
	# The host chooses for every block, unless a test asks the player
	_turn_manager.choice_timeout = 0.0
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

func test_the_attacker_turns_to_face_the_defender() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await await_idle_frame()
	var block: Block = _blocks[0]
	assert_object(block.attacker).is_same(monster)
	# Where the hero stood as the monster struck
	var to_defender: Vector3 = _level.get_spot_position(start, block.defender_spot) - _level.get_spot_position(start, monster.tile_spot)
	assert_int(monster.facing).is_equal(Character.rotation_to_facing(atan2(to_defender.x, to_defender.z)))

func test_the_monster_phase_lets_a_block_in_sight_play_out() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	await _spawn_hero(start)
	# Next door, in the hero's sight: it steps onto the hero's tile and blocks at once
	await _spawn_monster(start + Level.direction_to_vector(way))
	var times: Dictionary[StringName, int] = {}
	_turn_manager.blocked.connect(func(_block: Block) -> void: times[&"blocked"] = Time.get_ticks_msec())
	_turn_manager.phase_changed.connect(func(phase: TurnManager.Phase) -> void:
		if phase == TurnManager.Phase.HEROES: times[&"done"] = Time.get_ticks_msec()
	)
	await _pass_turn()
	assert_bool(times.has(&"blocked")).is_true()
	assert_int(times[&"done"] - times[&"blocked"]).is_greater_equal(roundi(TurnManager._BLOCK_PAUSE * 1000.0) - 50)

## Two heroes against one monster: the hero who stepped onto its tile blocks with an assist, rolls two dice and picks
func _set_up_a_hero_who_picks() -> Character:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var monster_cell: Vector2i = start + Level.direction_to_vector(way)
	var hero: Character = await _spawn_hero(start)
	await _spawn_hero(monster_cell)
	await _spawn_monster(monster_cell)
	_turn_manager.request_move(hero.get_path(), way)
	await await_idle_frame()
	return hero

## Answers the open choice with [param value]
func _answer(value: int) -> void:
	_turn_manager.request_block_choice(_turn_manager.block_choice[TurnManager.CHOICE_ID] as int, value)

## Passes and waits until a block asks the local player, or the block happened
func _pass_until_asked() -> void:
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if not _turn_manager.block_choice.is_empty() or not _blocks.is_empty(): return
		await await_idle_frame()

func test_the_player_whose_side_picks_chooses_the_die_and_the_push() -> void:
	_turn_manager.choice_timeout = 30.0
	var hero: Character = await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	var choice: Dictionary = _turn_manager.block_choice
	assert_dict(choice).is_not_empty()
	assert_int(choice[TurnManager.CHOICE_PICKER] as int).is_equal(multiplayer.get_unique_id())
	var dice: Array = choice[TurnManager.CHOICE_DICE]
	assert_int(dice.size()).is_equal(2)
	# Nothing moves while the choice is open, and no wrong answer counts
	var cell: Vector2i = hero.grid_cell
	_turn_manager.request_move(hero.get_path(), _way_out(cell))
	_answer(5)
	# An answer naming another choice counts for nothing, even a valid one
	_turn_manager.request_block_choice((choice[TurnManager.CHOICE_ID] as int) + 1, 0)
	await await_idle_frame()
	assert_that(hero.grid_cell).is_equal(cell)
	assert_dict(_turn_manager.block_choice).is_equal(choice)
	_answer(1)
	var picked: int = dice[1]
	var way: int = -1
	for _frame: int in MAX_FRAMES:
		if not _blocks.is_empty(): break
		var asked: Dictionary = _turn_manager.block_choice
		if not asked.is_empty() and (asked[TurnManager.CHOICE_DICE] as Array).is_empty():
			var ways: Array = asked[TurnManager.CHOICE_WAYS]
			way = ways.back()
			_answer(way)
		await await_idle_frame()
	assert_int(_blocks.size()).is_greater_equal(1)
	assert_object(_blocks[0].attacker).is_same(hero)
	assert_int(_blocks[0].chosen).is_equal(picked)
	if way >= 0: assert_that(_blocks[0].pushed_to).is_equal(cell + Level.direction_to_vector(way as Level.Direction))

func test_the_host_chooses_for_a_player_who_does_not() -> void:
	_turn_manager.choice_timeout = 0.3
	await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	for _frame: int in MAX_FRAMES:
		if not _blocks.is_empty(): break
		await await_idle_frame()
	assert_int(_blocks.size()).is_greater_equal(1)
	var block: Block = _blocks[0]
	assert_int(block.chosen).is_equal(Block.pick_best(block.dice, block.attacker_picks, block.stumbles_down()))

func test_loading_drops_a_choice_and_its_block() -> void:
	_turn_manager.choice_timeout = 30.0
	await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	assert_dict(_turn_manager.block_choice).is_not_empty()
	_turn_manager.stop_monster_phase()
	assert_dict(_turn_manager.block_choice).is_empty()
	for _frame: int in 30: await await_idle_frame()
	assert_array(_blocks).is_empty()

## A hero with an ally on a monster's tile steps off it: the monster blocks the stronger hero, who picks the die. Meanwhile the
## turn does not end, even with everyone passed; once the step is done it does
func test_the_turn_ends_only_once_a_choice_and_its_step_are_done() -> void:
	_turn_manager.choice_timeout = 30.0
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	await _spawn_hero(start)
	await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await await_idle_frame()
	assert_dict(_turn_manager.block_choice).is_not_empty()
	# As if the last other player left while the choice was open
	_turn_manager.passed_player_ids = PackedInt32Array([multiplayer.get_unique_id()])
	_turn_manager.call("_end_turn_if_everyone_passed")
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	var turn: int = _turn_manager.turn_number
	_answer(0)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: break
		var asked: Dictionary = _turn_manager.block_choice
		if not asked.is_empty():
			var ways: Array = asked[TurnManager.CHOICE_WAYS]
			var way: int = ways.front() if not ways.is_empty() else 0
			_answer(way if (asked[TurnManager.CHOICE_DICE] as Array).is_empty() else 0)
		await await_idle_frame()
	assert_int(_blocks.size()).is_equal(1)
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)
