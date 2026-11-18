extends GdUnitTestSuite
## Blocks on a generated level: engaging, the heroes' blocks as the monster phase starts, blocks on leaving, what each face
## does, assists, and getting up again

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
## Frames a monster phase may take before a test gives up on it
const MAX_FRAMES: int = 3000

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
	_level.add_character(hero)
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

func _spawn_monster(cell: Vector2i) -> Character:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var spawner: AgentSpawner = _level.get("_agent_spawner")
	var agents: Array[Node] = spawner.get_children()
	return (agents[-1] as Agent).character

## @returns a direction with a passage out of [param cell] onto a tile with room
func _way_out(cell: Vector2i) -> Level.Direction:
	for direction: Level.Direction in Level.Direction.values():
		if _level.is_passage(cell, direction) and _level.has_room(cell + Level.direction_to_vector(direction), CharacterProfile.Groups.HEROES): return direction
	assert(false, "No way out of %s" % cell)
	return Level.Direction.UP

func _pass_turn() -> void:
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: return
		await await_idle_frame()
	fail("The monster phase did not end")

## @returns the stage of the block under way, [code]-1[/code] for none
func _stage() -> int:
	var stage: int = _turn_manager.block_state.get(BlockSequence.STAGE, -1)
	return stage

## Waits until the block under way reaches [param stage]
func _await_stage(stage: int) -> void:
	for _frame: int in MAX_FRAMES:
		if _stage() == stage: return
		await await_idle_frame()
	fail("The block did not reach stage %d" % stage)

## Waits until no block is under way
func _await_block_end() -> void:
	await _await_stage(-1)

## Records the stage of every block state as it changes, [code]-1[/code] as it clears
func _record_stages() -> Array[int]:
	var stages: Array[int] = []
	_turn_manager.block_state_changed.connect(func() -> void: stages.append(_stage()))
	return stages

## Waits [param seconds] of real time
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

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
	await _await_block_end()
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
	Block.new(hero, monster).apply(Block.Face.ATTACKER_DOWN, _level)
	assert_int(hero.posture).is_equal(Character.Posture.DOWN)
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)
	hero.posture = Character.Posture.STANDING
	Block.new(hero, monster).apply(Block.Face.BOTH_DOWN, _level)
	assert_array([hero.posture, monster.posture]).is_equal([Character.Posture.DOWN, Character.Posture.DOWN])
	hero.posture = Character.Posture.STANDING
	monster.posture = Character.Posture.STANDING
	var push: Block = Block.new(hero, monster)
	push.apply(Block.Face.PUSH, _level)
	assert_bool(push.was_pushed()).is_true()
	assert_that(monster.grid_cell).is_equal(push.pushed_to)
	assert_bool(_level.get_cells_in_reach(start).has(monster.grid_cell)).is_true()
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)
	# The attacker does not follow
	assert_that(hero.grid_cell).is_equal(start)
	var down: Block = Block.new(monster, hero)
	down.apply(Block.Face.DEFENDER_DOWN, _level)
	assert_int(hero.posture).is_equal(Character.Posture.DOWN)
	assert_bool(down.was_pushed()).is_true()

func test_a_stumbling_defender_falls_only_if_clumsier() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	# Equally agile: it keeps its feet
	Block.new(hero, monster).apply(Block.Face.DEFENDER_STUMBLES, _level)
	assert_int(monster.posture).is_equal(Character.Posture.STANDING)

func test_a_push_with_nowhere_to_go_knocks_the_defender_down_where_it_is() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	# Fill the tile beyond the monsters' edge, if a passage leads there
	var edge: int = _level.get_side_edge(start, CharacterProfile.Groups.MONSTERS)
	if _level.is_passage(start, edge as Level.Direction):
		var cell: Vector2i = start + Level.direction_to_vector(edge as Level.Direction)
		while _level.has_room(cell, CharacterProfile.Groups.MONSTERS): await _spawn_monster(cell)
	var push: Block = Block.new(hero, monster)
	push.apply(Block.Face.PUSH, _level)
	assert_bool(push.was_pushed()).is_false()
	assert_that(monster.grid_cell).is_equal(start)
	assert_int(monster.posture).is_equal(Character.Posture.DOWN)
	# Rolled like that, the block knows the defender is pinned
	var again: Block = Block.new(hero, monster)
	again.roll(_level, RandomNumberGenerator.new())
	assert_bool(again.pinned).is_true()
	# The strike tells every peer, so the dice can say a push is a fall
	monster.posture = Character.Posture.STANDING
	var shown: Array[bool] = []
	_turn_manager.block_shown.connect(func(_attacker: Character, _defender: Character, _dice: Array[int], _chosen: int, pinned: bool) -> void: shown.append(pinned))
	await _turn_manager.call("_block", hero, monster)
	assert_array(shown).is_equal([true])

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
	await _await_block_end()
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
	assert_int(times[&"done"] - times[&"blocked"]).is_greater_equal(roundi(BlockSequence._STRIKE_PAUSE * 1000.0) - 50)

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
	var choice_id: int = _turn_manager.block_state[BlockSequence.CHOICE_ID]
	_turn_manager.request_block_choice(choice_id, value)

## Passes and waits until a block asks the local player, or the block happened
func _pass_until_asked() -> void:
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if _stage() == BlockSequence.Stage.CHOOSING or not _blocks.is_empty(): return
		await await_idle_frame()

func test_the_player_whose_side_picks_chooses_the_die() -> void:
	_turn_manager.choice_timeout = 30.0
	var hero: Character = await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	var choice: Dictionary = _turn_manager.block_state
	assert_int(_stage()).is_equal(BlockSequence.Stage.CHOOSING)
	assert_int(choice[BlockSequence.PICKER]).is_equal(multiplayer.get_unique_id())
	var dice: Array = choice[BlockSequence.DICE]
	assert_int(dice.size()).is_equal(2)
	# Nothing moves while the choice is open, and no wrong answer counts
	var cell: Vector2i = hero.grid_cell
	_turn_manager.request_move(hero.get_path(), _way_out(cell))
	_answer(5)
	# An answer naming another choice counts for nothing, even a valid one
	var choice_id: int = choice[BlockSequence.CHOICE_ID]
	_turn_manager.request_block_choice(choice_id + 1, 0)
	await await_idle_frame()
	assert_that(hero.grid_cell).is_equal(cell)
	assert_dict(_turn_manager.block_state).is_equal(choice)
	_answer(1)
	var picked: int = dice[1]
	for _frame: int in MAX_FRAMES:
		if not _blocks.is_empty(): break
		await await_idle_frame()
	assert_int(_blocks.size()).is_greater_equal(1)
	assert_object(_blocks[0].attacker).is_same(hero)
	assert_int(_blocks[0].chosen).is_equal(picked)

func test_the_host_chooses_for_a_player_who_does_not() -> void:
	_turn_manager.choice_timeout = 0.3
	await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	for _frame: int in MAX_FRAMES:
		if not _blocks.is_empty(): break
		await await_idle_frame()
	assert_int(_blocks.size()).is_greater_equal(1)
	var block: Block = _blocks[0]
	assert_int(block.chosen).is_equal(Block.pick_best(block.dice, block.attacker_picks, block.stumbles_down(), block.pinned))

func test_loading_drops_a_choice_and_its_block() -> void:
	_turn_manager.choice_timeout = 30.0
	await _set_up_a_hero_who_picks()
	await _pass_until_asked()
	assert_int(_stage()).is_equal(BlockSequence.Stage.CHOOSING)
	_turn_manager.stop_monster_phase()
	assert_dict(_turn_manager.block_state).is_empty()
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
	await _await_stage(BlockSequence.Stage.CHOOSING)
	# As if the last other player left while the choice was open
	_turn_manager.passed_player_ids = PackedInt32Array([multiplayer.get_unique_id()])
	_turn_manager.call("_end_turn_if_everyone_passed")
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	var turn: int = _turn_manager.turn_number
	_answer(0)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: break
		if _stage() == BlockSequence.Stage.CHOOSING: _answer(0)
		await await_idle_frame()
	# The step's block came first; the monster phase may have brought more
	assert_int(_blocks.size()).is_greater_equal(1)
	assert_object(_blocks[0].defender).is_same(hero)
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)

func test_a_block_goes_through_its_stages() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	await _spawn_monster(start)
	var stages: Array[int] = _record_stages()
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await _await_block_end()
	assert_array(stages).is_equal([BlockSequence.Stage.ROLLED, BlockSequence.Stage.STRUCK, -1])

func test_a_block_with_a_choice_goes_through_choosing() -> void:
	_turn_manager.choice_timeout = 30.0
	await _set_up_a_hero_who_picks()
	var stages: Array[int] = _record_stages()
	await _pass_until_asked()
	_answer(0)
	# The monsters' blocks may follow at once: wait for this one's end in the record
	for _frame: int in MAX_FRAMES:
		if stages.size() >= 4: break
		await await_idle_frame()
	assert_array(stages.slice(0, 4)).is_equal([BlockSequence.Stage.ROLLED, BlockSequence.Stage.CHOOSING, BlockSequence.Stage.STRUCK, -1])

func test_a_block_in_sight_pauses_after_the_roll() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	await _spawn_monster(start)
	var times: Dictionary[int, int] = {}
	_turn_manager.block_state_changed.connect(func() -> void:
		if not times.has(_stage()): times[_stage()] = Time.get_ticks_msec()
	)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	await _await_block_end()
	var rolled: int = times[BlockSequence.Stage.ROLLED]
	var struck: int = times[BlockSequence.Stage.STRUCK]
	assert_int(struck - rolled).is_greater_equal(roundi(BlockSequence._ROLL_PAUSE * 1000.0) - 50)

func test_a_hidden_block_does_not_pause() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_level.get_placed_tile(start).status = Structure.Status.DISCOVERED
	var stages: Array[int] = _record_stages()
	_turn_manager.call("_block", monster, hero)
	# Not awaited: with nothing to see, it is over at once
	assert_array(stages).is_equal([BlockSequence.Stage.ROLLED, BlockSequence.Stage.STRUCK, -1])
	assert_int(_blocks.size()).is_equal(1)

func test_loading_during_the_roll_drops_the_block() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	assert_int(_stage()).is_equal(BlockSequence.Stage.ROLLED)
	_turn_manager.stop_monster_phase()
	assert_dict(_turn_manager.block_state).is_empty()
	await _wait(BlockSequence._ROLL_PAUSE + BlockSequence._STRIKE_PAUSE)
	assert_array(_blocks).is_empty()
	assert_that(hero.grid_cell).is_equal(start)
	assert_array([hero.posture, monster.posture]).is_equal([Character.Posture.STANDING, Character.Posture.STANDING])

func test_a_figure_leaving_during_the_roll_drops_the_block() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	assert_int(_stage()).is_equal(BlockSequence.Stage.ROLLED)
	monster.get_parent().queue_free()
	await _wait(BlockSequence._ROLL_PAUSE + BlockSequence._STRIKE_PAUSE)
	assert_array(_blocks).is_empty()
	assert_dict(_turn_manager.block_state).is_empty()
	assert_that(hero.grid_cell).is_equal(start)

func test_answers_count_only_while_choosing() -> void:
	_turn_manager.choice_timeout = 30.0
	await _set_up_a_hero_who_picks()
	_turn_manager.request_pass(true)
	await _await_stage(BlockSequence.Stage.ROLLED)
	# The id the coming choice will get, answered too early
	var next_id: int = BlockSequence._choices_asked + 1
	_turn_manager.request_block_choice(next_id, 0)
	await _await_stage(BlockSequence.Stage.CHOOSING)
	var choice_id: int = _turn_manager.block_state[BlockSequence.CHOICE_ID]
	assert_int(choice_id).is_equal(next_id)
	await await_idle_frame()
	assert_int(_stage()).is_equal(BlockSequence.Stage.CHOOSING)
	assert_array(_blocks).is_empty()
	_answer(0)
	for _frame: int in MAX_FRAMES:
		if not _blocks.is_empty(): break
		await await_idle_frame()
	assert_int(_blocks.size()).is_equal(1)

func test_requests_wait_during_any_stage() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var next_door: Vector2i = start + Level.direction_to_vector(way)
	var hero: Character = await _spawn_hero(start)
	var other: Character = await _spawn_hero(next_door)
	await _spawn_monster(start)
	_turn_manager.request_move(hero.get_path(), way)
	assert_int(_stage()).is_equal(BlockSequence.Stage.ROLLED)
	_turn_manager.request_move(other.get_path(), Level.get_opposite(way))
	assert_that(other.grid_cell).is_equal(next_door)
	await _await_block_end()

func test_a_pass_during_a_block_counts_but_the_turn_waits_for_it() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	await _spawn_monster(start)
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_move(hero.get_path(), _way_out(start))
	assert_int(_stage()).is_equal(BlockSequence.Stage.ROLLED)
	_turn_manager.request_pass(true)
	assert_bool(_turn_manager.has_passed(multiplayer.get_unique_id())).is_true()
	assert_int(_turn_manager.phase).is_equal(TurnManager.Phase.HEROES)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: break
		await await_idle_frame()
	# The step's block was struck before the turn ended
	assert_int(_blocks.size()).is_greater_equal(1)
	assert_object(_blocks[0].defender).is_same(hero)
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)

func test_loading_during_the_strike_drops_the_block() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	var results: Array[Block] = []
	var run_block: Callable = func() -> void:
		var block: Block = await _turn_manager._block(monster, hero)
		results.append(block)
	run_block.call()
	await _await_stage(BlockSequence.Stage.STRUCK)
	_turn_manager.stop_monster_phase()
	for _frame: int in MAX_FRAMES:
		if not results.is_empty(): break
		await await_idle_frame()
	assert_int(results.size()).is_equal(1)
	# The game moved on: the step it belonged to does not go on
	assert_object(results[0]).is_null()
	assert_dict(_turn_manager.block_state).is_empty()
