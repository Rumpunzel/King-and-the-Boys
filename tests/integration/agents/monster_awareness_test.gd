extends "res://tests/fixtures/monster_test_suite.gd"
## Monster awareness (see MonsterSenses.update): noticing hunts, losing the hero investigates where it was last noticed, nobody
## there roams again; whatever gets someone noticed can not be undone; heroes are on alert while noticed

const HELD_ABILITY: Ability = preload("uid://bgf7w50r6f4he")  # tests/fixtures/held_test_ability.tres

func _update(actor: Character = null) -> void:
	_turn_manager.get_senses().update(actor)

func test_noticing_a_hero_hunts_them() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.ROAMING)
	_update()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)
	assert_that(_agent(monster).awareness_target).is_equal(hero.grid_cell)
	assert_bool(hero.alerted).is_true()

func test_a_hero_slipping_out_of_notice_is_investigated_where_last_seen() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	var seen_at: Vector2i = hero.grid_cell
	# The lantern goes out: unlit, out of the monster's view
	_turn_manager.request_ability(hero.get_path(), ResourceId.of(LANTERN), hero.grid_cell, 0)
	_update()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.INVESTIGATING)
	assert_that(_agent(monster).awareness_target).is_equal(seen_at)
	assert_bool(hero.alerted).is_false()

func test_an_investigation_ends_where_no_one_is_noticed() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	var agent: Agent = _agent(monster)
	agent.awareness_target = monster.grid_cell
	agent.awareness = Agent.Awareness.INVESTIGATING
	_update()
	assert_int(agent.awareness).is_equal(Agent.Awareness.ROAMING)

func test_an_investigation_goes_on_until_it_got_there() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	var agent: Agent = _agent(monster)
	agent.awareness_target = _start_cell()
	agent.awareness = Agent.Awareness.INVESTIGATING
	_update()
	assert_int(agent.awareness).is_equal(Agent.Awareness.INVESTIGATING)

func test_a_monster_hunts_the_nearest_of_two_noticed_heroes() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var near_cell: Vector2i = start + Level.direction_to_vector(way)
	await _spawn_hero(start, _lit_profile())
	var near: Character = await _spawn_hero(near_cell, _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	assert_that(_agent(monster).awareness_target).is_equal(near.grid_cell)

func test_heroes_as_near_are_hunted_by_block_priority() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var far_cell: Vector2i = start + Level.direction_to_vector(way) * 2
	var later_profile: CharacterProfile = _lit_profile()
	later_profile.block_priority = 1
	var sooner_profile: CharacterProfile = _lit_profile()
	sooner_profile.block_priority = 0
	# One step either side of the monster; the one with the lower priority comes second in turn order
	await _spawn_hero(start, later_profile)
	var sooner: Character = await _spawn_hero(far_cell, sooner_profile)
	var monster: Character = await _spawn_monster_ahead(1, false, 2)
	_update()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)
	assert_that(_agent(monster).awareness_target).is_equal(sooner.grid_cell)

func test_a_step_that_gets_a_hero_noticed_can_not_be_undone() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster_ahead(2, false)
	var way: Level.Direction = _straight_way(2)
	await _explore(hero, way, 1)
	# Facing away: the unlit hero steps up unnoticed, and may take it back
	await _move(hero, way)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.ROAMING)
	assert_int(hero.undo_steps).is_equal(1)
	_turn_manager.request_undo(hero.get_path())
	assert_that(hero.grid_cell).is_equal(start)
	# Looking at the start: the same step is noticed and stays
	monster.place_on_grid(monster.grid_cell, monster.tile_spot, Level.get_opposite(way))
	await _move(hero, way)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)
	assert_int(hero.undo_steps).is_zero()
	_turn_manager.request_undo(hero.get_path())
	assert_that(hero.grid_cell).is_equal(start + Level.direction_to_vector(way))

func test_whoever_got_a_hero_noticed_can_not_undo_it() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var actor: Character = await _spawn_hero(start)
	await _explore(actor, way, 1)
	await _move(actor, way)
	assert_int(actor.undo_steps).is_equal(1)
	# Elsewhere, a monster comes to stand on a lit hero's tile: the actor's next action got them noticed
	var noticed: Character = await _spawn_hero(_cells_at(start, 5)[0], _lit_profile())
	var monster: Character = await _spawn_monster(noticed.grid_cell)
	assert_that(monster.grid_cell).is_equal(noticed.grid_cell)
	_update(actor)
	assert_bool(noticed.alerted).is_true()
	assert_int(actor.undo_steps).is_zero()

func test_an_undo_that_got_no_one_noticed_keeps_the_notice() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var noticed: Character = await _spawn_hero(_cells_at(start, 5)[0], _lit_profile())
	var monster: Character = await _spawn_monster(noticed.grid_cell)
	_update()
	var walker: Character = await _spawn_hero(start)
	await _explore(walker, way, 1)
	await _move(walker, way)
	_turn_manager.request_undo(walker.get_path())
	assert_that(walker.grid_cell).is_equal(start)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)
	assert_bool(noticed.alerted).is_true()

func test_a_previewed_ability_notices_nothing_until_used() -> void:
	var profile: CharacterProfile = _lit_profile()
	profile.abilities = [LANTERN, HELD_ABILITY]
	var hero: Character = await _spawn_hero(_start_cell(), profile)
	var monster: Character = await _spawn_monster_ahead(2, false)
	var id: String = ResourceId.of(HELD_ABILITY)
	_turn_manager.request_ability_begin(hero.get_path(), id, hero.grid_cell)
	_turn_manager.request_ability_adjust(hero.get_path(), 1)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.ROAMING)
	_turn_manager.request_ability(hero.get_path(), id, hero.grid_cell, 1)
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)

func test_loading_forgets_who_was_noticed() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	assert_bool(hero.alerted).is_true()
	_turn_manager.stop_monster_phase()
	assert_bool(hero.alerted).is_false()
	# Forgotten, so noticed anew
	_update()
	assert_bool(hero.alerted).is_true()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)

func test_awareness_is_saved_with_the_monster() -> void:
	await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	var agent: Agent = _agent(monster)
	var target: Vector2i = agent.awareness_target
	var serializer: SynchronizerSerializer = agent.get_node("AgentSynchronizer/SynchronizerSerializer")
	var decoded: Variant = Serializer.decode_data(Serializer.encode_data(serializer.collect_properties()))
	var saved: Dictionary[NodePath, Variant] = decoded
	agent.awareness = Agent.Awareness.ROAMING
	agent.awareness_target = Vector2i.ZERO
	serializer.restore_state(saved)
	assert_int(agent.awareness).is_equal(Agent.Awareness.HUNTING)
	assert_that(agent.awareness_target).is_equal(target)

func test_a_monster_turned_off_or_freed_drops_its_notice() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	_level.monsters_enabled = false
	_update()
	assert_bool(hero.alerted).is_false()
	_level.monsters_enabled = true
	_update()
	assert_bool(hero.alerted).is_true()
	_agent(monster).queue_free()
	await await_idle_frame()
	_update()
	assert_bool(hero.alerted).is_false()

func test_a_passed_hero_shows_the_pass_over_the_alert() -> void:
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.alert_animations = BodyAnimations.new()
	profile.passed_animations = BodyAnimations.new()
	var hero: Character = await _spawn_hero(_start_cell(), profile)
	hero.alerted = true
	assert_object(hero.call("_get_rest")).is_same(profile.alert_animations)
	hero.show_passed(true)
	assert_object(hero.call("_get_rest")).is_same(profile.passed_animations)

func test_a_noticed_hero_leaving_breaks_no_one_elses_alert() -> void:
	var start: Vector2i = _start_cell()
	var leaving: Character = await _spawn_hero(start, _lit_profile())
	var staying: Character = await _spawn_hero(start, _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, false)
	_update()
	assert_bool(staying.alerted).is_true()
	# As a player leaving takes their hero along; the monster meanwhile goes where no one sees it
	remove_child(leaving)
	leaving.free()
	_agent(monster).awareness = Agent.Awareness.ROAMING
	monster.place_on_grid(_cells_at(start, 6)[0], monster.tile_spot, monster.facing)
	_update()
	assert_bool(staying.alerted).is_false()

func test_noticing_waits_while_a_held_ability_is_shown() -> void:
	var profile: CharacterProfile = _lit_profile()
	profile.abilities = [LANTERN, HELD_ABILITY]
	var hero: Character = await _spawn_hero(_start_cell(), profile)
	var monster: Character = await _spawn_monster_ahead(2, false)
	_turn_manager.request_ability_begin(hero.get_path(), ResourceId.of(HELD_ABILITY), hero.grid_cell)
	# Another player's action meanwhile: what the held ability shows (a lifted tile) is not the board yet
	_update()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.ROAMING)
	_turn_manager.request_ability_cancel(hero.get_path())
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.HUNTING)

func test_the_first_action_after_loading_closes_no_undo() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var noticed: Character = await _spawn_hero(_cells_at(start, 5)[0], _lit_profile())
	await _spawn_monster(noticed.grid_cell)
	var walker: Character = await _spawn_hero(start)
	await _explore(walker, way, 1)
	_update()
	_turn_manager.stop_monster_phase()
	# The knight was noticed before the load too: the walker's harmless step got no one noticed
	await _move(walker, way)
	assert_int(walker.undo_steps).is_equal(1)
	assert_bool(noticed.alerted).is_true()
