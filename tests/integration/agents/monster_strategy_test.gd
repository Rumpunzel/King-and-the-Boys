extends "res://tests/fixtures/monster_test_suite.gd"
## How monsters step (see MonsterStrategy, InvestigateStrategy): roaming at their roaming speed, hunting and investigating at full
## speed, a profile's own strategy deciding; and they keep facing the way they stepped

## Always steps one way, whatever it knows
class OneWay:
	extends MonsterStrategy

	var way: Level.Direction

	func choose_step(_agent: Agent) -> int:
		return way

## The fixture monster profile is cached (spawners replicate it by its path): a test's strategy goes again
func after_test() -> void:
	ModelFreeWorld.load_monster_profile().strategy = null
	await super()

## A monster of the fixture profile, which now uses [param strategy] (see after_test); set once it spawned, as spawning loads the
## profile again
func _spawn_monster_with(cell: Vector2i, strategy: MonsterStrategy) -> Character:
	var monster: Character = await _spawn_monster(cell)
	monster.profile.strategy = strategy
	return monster

func test_a_roaming_monster_takes_its_roaming_speed_in_steps() -> void:
	var start: Vector2i = _start_cell()
	await _spawn_hero(start)
	var monster: Character = await _spawn_monster(_cells_at(start, 6)[0])
	assert_int(monster.profile.roam_speed).is_equal(1)
	assert_int(monster.profile.speed).is_greater(1)
	var steps: int = monster.step_count
	await _pass_turn()
	assert_int(_agent(monster).awareness).is_equal(Agent.Awareness.ROAMING)
	assert_int(monster.step_count - steps).is_equal(1)

func test_a_hunting_monster_takes_its_full_speed() -> void:
	var hero: Character = await _spawn_hero(_start_cell(), _lit_profile())
	var monster: Character = await _spawn_monster_ahead(2, true)
	var hero_cell: Vector2i = hero.grid_cell
	await _pass_turn()
	# Two steps, its speed: onto the hero's tile
	assert_that(monster.grid_cell).is_equal(hero_cell)

func test_a_monster_noticing_mid_turn_uses_the_rest_of_its_speed() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(3)
	# A lantern on a hero who sees little without it: lit, it sees two cells
	var profile: CharacterProfile = _lit_profile()
	profile.vision = -1.0
	var hero: Character = await _spawn_hero(start, profile)
	assert_float(hero.get_vision()).is_equal(2.0)
	var strategy: OneWay = OneWay.new()
	strategy.way = Level.get_opposite(way)
	var monster: Character = await _spawn_monster_with(start + Level.direction_to_vector(way) * 3, strategy)
	var steps: int = monster.step_count
	await _pass_turn()
	# One roaming step brought it into notice; it went on hunting with the rest of its speed
	assert_int(monster.step_count - steps).is_equal(monster.profile.speed)

func test_an_investigating_monster_goes_to_the_last_seen_cell() -> void:
	var start: Vector2i = _start_cell()
	await _spawn_hero(start)
	var monster: Character = await _spawn_monster(_cells_at(start, 6)[0])
	var target: Vector2i = _cells_at(monster.grid_cell, monster.profile.speed)[0]
	var agent: Agent = _agent(monster)
	agent.awareness_target = target
	agent.awareness = Agent.Awareness.INVESTIGATING
	await _pass_turn()
	assert_that(monster.grid_cell).is_equal(target)
	# Nobody there: it roams again
	assert_int(agent.awareness).is_equal(Agent.Awareness.ROAMING)

func test_an_unreachable_investigation_turns_to_roaming() -> void:
	var start: Vector2i = _start_cell()
	await _spawn_hero(start)
	var monster: Character = await _spawn_monster(_cells_at(start, 6)[0])
	var agent: Agent = _agent(monster)
	agent.awareness_target = Vector2i(999, 999)
	agent.awareness = Agent.Awareness.INVESTIGATING
	var turn: int = _turn_manager.turn_number
	await _pass_turn()
	assert_int(_turn_manager.turn_number).is_equal(turn + 1)
	assert_int(agent.awareness).is_equal(Agent.Awareness.ROAMING)

func test_a_monster_does_not_look_at_a_thing_on_its_tile() -> void:
	var start: Vector2i = _start_cell()
	var hero: Character = await _spawn_hero(start)
	var monster: Character = await _spawn_monster(start)
	var thing: Thing = ThingProfile.new().create(0, Transform3D(Basis.IDENTITY, monster.global_position + Vector3(0.7, 0.0, 0.3)), Thing.Status.NONE)
	# A bare model: the fixture world has none, and a thing shows or hides its model
	thing.model = Model.new()
	add_child(thing)
	auto_free(thing)
	var placed_things: Dictionary = _level.get("_placed_things")
	placed_things[start] = thing
	for character: Character in [hero, monster]: character.set("_turn_tween", null)
	monster.call("_look_at_thing_on_tile")
	hero.call("_look_at_thing_on_tile")
	# The hero's eye is caught; the monster keeps facing the way its notice reads
	assert_object(monster.get("_turn_tween")).is_null()
	assert_object(hero.get("_turn_tween")).is_not_null()
	placed_things.erase(start)

func test_a_profile_strategy_decides_the_step() -> void:
	var start: Vector2i = _start_cell()
	var way: Level.Direction = _straight_way(2)
	var strategy: OneWay = OneWay.new()
	strategy.way = Level.get_opposite(way)
	# No hero about: it roams one step, the way its strategy says
	var monster: Character = await _spawn_monster_with(start + Level.direction_to_vector(way) * 2, strategy)
	await _pass_turn()
	assert_that(monster.grid_cell).is_equal(start + Level.direction_to_vector(way))
