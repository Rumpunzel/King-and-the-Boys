extends GdUnitTestSuite
## Formations on a generated level: the edge each side holds on a shared tile, pushes over it, room for three a side, and who
## blocks whom at the start and the end of the monster phase

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd

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
	add_child(hero)
	await await_idle_frame()
	return hero

func _spawn_monster(cell: Vector2i) -> Character:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var agents: Array[Node] = (_level.get("_agent_spawner") as AgentSpawner).get_children()
	return (agents.back() as Agent).character

func _way_out(cell: Vector2i) -> Level.Direction:
	for direction: Level.Direction in Level.Direction.values():
		if _level.is_passage(cell, direction): return direction
	assert(false, "No way out of %s" % cell)
	return Level.Direction.UP

## A hero steps from the start onto a monster's tile next door
## @returns the hero and the monster
func _engage() -> Array[Character]:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start + Level.direction_to_vector(way))
	_turn_manager.request_move(hero.get_path(), way)
	await await_idle_frame()
	return [hero, monster]

func _block_on_shared_tiles(group: CharacterProfile.Groups) -> void:
	await _turn_manager.call("_block_on_shared_tiles", group)

func test_sides_line_up_on_their_edges_facing_each_other() -> void:
	var figures: Array[Character] = await _engage()
	var hero: Character = figures[0]
	var monster: Character = figures[1]
	var cell: Vector2i = monster.grid_cell
	var hero_edge: int = _level.get_side_edge(cell, CharacterProfile.Groups.HEROES)
	var monster_edge: int = _level.get_side_edge(cell, CharacterProfile.Groups.MONSTERS)
	# The hero holds the edge it came over, unless the monster, there first, held it already
	var came_over: Level.Direction = Level.get_direction(cell, _start_cell())
	if monster_edge != came_over: assert_int(hero_edge).is_equal(came_over)
	assert_int(hero_edge).is_not_equal(monster_edge)
	assert_int(Formation.get_edge_towards(hero.tile_spot)).is_equal(hero_edge)
	assert_int(Formation.get_edge_towards(monster.tile_spot)).is_equal(monster_edge)
	assert_int(hero.facing).is_equal(Level.get_opposite(hero_edge as Level.Direction))
	assert_int(monster.facing).is_equal(Level.get_opposite(monster_edge as Level.Direction))

func test_a_pushed_figure_goes_back_over_its_sides_edge_or_falls() -> void:
	var figures: Array[Character] = await _engage()
	var hero: Character = figures[0]
	var monster: Character = figures[1]
	var cell: Vector2i = hero.grid_cell
	var edge: Level.Direction = _level.get_side_edge(cell, CharacterProfile.Groups.HEROES) as Level.Direction
	var push: Block = Block.new(monster, hero)
	push.apply(Block.Face.PUSH, _level)
	if _level.is_passage(cell, edge):
		assert_that(hero.grid_cell).is_equal(cell + Level.direction_to_vector(edge))
		assert_int(hero.posture).is_equal(Character.Posture.STANDING)
	else:
		assert_that(hero.grid_cell).is_equal(cell)
		assert_int(hero.posture).is_equal(Character.Posture.DOWN)

func test_a_side_has_room_for_three() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	var next_door: Vector2i = start + Level.direction_to_vector(way)
	for _hero: int in Formation.MAX_PER_SIDE: await _spawn_hero(start)
	var spots: Dictionary[Vector2, bool] = {}
	for hero: Character in _level.get_figures_on(start): spots[hero.tile_spot] = true
	assert_int(spots.size()).is_equal(Formation.MAX_PER_SIDE)
	var fourth: Character = await _spawn_hero(next_door)
	fourth.movement_points = 2
	_turn_manager.request_move(fourth.get_path(), Level.get_opposite(way))
	await await_idle_frame()
	assert_that(fourth.grid_cell).is_equal(next_door)
	# The monsters' side still has room there
	assert_bool(_level.has_room(start, CharacterProfile.Groups.MONSTERS)).is_true()

func test_a_monster_stepping_onto_a_heros_tile_stops_without_a_block() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _way_out(start)
	await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start + Level.direction_to_vector(way))
	var stepped: bool = await _turn_manager.try_step(monster, Level.get_opposite(way))
	assert_bool(stepped).is_true()
	assert_that(monster.grid_cell).is_equal(start)
	assert_int(monster.movement_points).is_zero()
	assert_array(_blocks).is_empty()

func test_the_heroes_lead_blocks_every_monster_once() -> void:
	var start: Vector2i = _start_cell()
	var first: Character = await _spawn_hero(start)
	var second: Character = await _spawn_hero(start)
	var monsters: Array[Character] = [await _spawn_monster(start), await _spawn_monster(start)]
	# Whether the first hero still led after each block
	var leads: Array[bool] = []
	_turn_manager.blocked.connect(func(_block: Block) -> void: leads.append(first.posture == Character.Posture.STANDING and first.grid_cell == start))
	await _block_on_shared_tiles(CharacterProfile.Groups.HEROES)
	assert_int(_blocks.size()).is_between(1, 2)
	assert_object(_blocks[0].attacker).is_same(first)
	assert_object(_blocks[0].defender).is_same(monsters[0])
	if _blocks.size() == 1:
		# The second monster fell or was pushed away, or no hero stood any more
		var second_monster_left: bool = monsters[1].posture != Character.Posture.STANDING or monsters[1].grid_cell != start
		assert_bool(second_monster_left or Block.get_standing_on(start, _level).all(func(figure: Character) -> bool: return figure.profile.group == CharacterProfile.Groups.MONSTERS)).is_true()
		return
	assert_object(_blocks[1].defender).is_same(monsters[1])
	# The lead knocked down or pushed away hands over to the next
	assert_object(_blocks[1].attacker).is_same(first if leads[0] else second)

func test_a_fallen_lead_hands_over_to_the_next_hero() -> void:
	var start: Vector2i = _start_cell()
	var first: Character = await _spawn_hero(start)
	var second: Character = await _spawn_hero(start)
	await _spawn_monster(start)
	first.posture = Character.Posture.DOWN
	await _block_on_shared_tiles(CharacterProfile.Groups.HEROES)
	assert_int(_blocks.size()).is_equal(1)
	assert_object(_blocks[0].attacker).is_same(second)

func test_the_monsters_lead_blocks_alone_while_it_keeps_its_feet() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monsters: Array[Character] = [await _spawn_monster(start), await _spawn_monster(start)]
	# After the first block: whether the lead kept its feet, and whether the hero still stood there
	var after_first: Array[bool] = []
	_turn_manager.blocked.connect(func(_block: Block) -> void:
		if not after_first.is_empty(): return
		after_first.append(monsters[0].posture == Character.Posture.STANDING)
		after_first.append(hero.posture == Character.Posture.STANDING and hero.grid_cell == start))
	await _block_on_shared_tiles(CharacterProfile.Groups.MONSTERS)
	assert_int(_blocks.size()).is_between(1, 2)
	assert_object(_blocks[0].attacker).is_same(monsters[0])
	assert_object(_blocks[0].defender).is_same(hero)
	assert_int(_blocks.size()).is_equal(2 if not after_first[0] and after_first[1] else 1)
	if _blocks.size() == 2: assert_object(_blocks[1].attacker).is_same(monsters[1])

func test_a_fallen_figure_moves_off_what_now_stands_on_its_place() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	hero.posture = Character.Posture.DOWN
	hero.place_on_grid(start, Vector2(0.5, 0.5), hero.facing)
	var corner_things: Dictionary = _level.get("_corner_things")
	corner_things[start + Vector2i.ONE] = auto_free(Thing.new())
	(_level.get("_formations") as LevelFormations).arrange(start)
	corner_things.erase(start + Vector2i.ONE)
	var blocked: Array[Vector2] = [Vector2(0.5, 0.5)]
	assert_bool(Formation.is_clear(hero.tile_spot, blocked)).is_true()

func test_the_others_close_up_only_once_the_strike_landed() -> void:
	var figures: Array[Character] = await _engage()
	var lead: Character = figures[0]
	var monster: Character = figures[1]
	var cell: Vector2i = lead.grid_cell
	var second: Character = await _spawn_hero(cell)
	# The heroes hold the edge back to the start, so the lead can be pushed there
	var formations: LevelFormations = _level.get("_formations")
	var back: Level.Direction = Level.get_direction(cell, _start_cell())
	var edges: Dictionary = formations.get_side_edges(cell)
	edges[CharacterProfile.Groups.HEROES] = back
	edges[CharacterProfile.Groups.MONSTERS] = Level.get_opposite(back)
	formations.arrange(cell)
	var waiting_at: Vector2 = second.tile_spot
	# As Character.show_block() holds it with a model to strike
	lead.set("_hold_until_msec", Time.get_ticks_msec() + 400)
	Block.new(monster, lead).apply(Block.Face.PUSH, _level)
	assert_that(lead.grid_cell).is_not_equal(cell)
	# The second hero stays behind while the strike swings
	assert_vector(second.tile_spot).is_equal(waiting_at)
	await await_millis(roundi(lead.get_hold() * 1000.0) + 100)
	assert_vector(second.tile_spot).is_not_equal(waiting_at)
