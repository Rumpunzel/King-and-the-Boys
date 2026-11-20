extends GdUnitTestSuite
## Shared setup for the monster awareness suites (no tests of its own): a generated model-free level with a turn manager, heroes lit
## or not, monsters placed straight from the start facing either way

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const LANTERN: ToggleLightAbility = preload("uid://s4o504byc2n0")  # tests/fixtures/lantern.tres
const TORCH_TILE_LIGHT: String = "uid://cvimunviu8yb1"  # tests/fixtures/torch_tile_light.tres
## Frames a monster phase may take before a test gives up on it
const MAX_FRAMES: int = 3000

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
	_turn_manager.choice_timeout = 0.0
	add_child(_turn_manager)
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _start_cell() -> Vector2i:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position(spawn_point.global_position)

## A hero of [param profile] (the fixture hero, unlit, unless given)
func _spawn_hero(cell: Vector2i, profile: CharacterProfile = null) -> Character:
	if not profile: profile = ModelFreeWorld.load_hero_profile()
	var hero: Character = auto_free(profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell))))
	_level.add_character(hero)
	hero.entered_grid_cell.connect(_level._on_player_moved.bind(hero))
	add_child(hero)
	await await_idle_frame()
	return hero

## The fixture hero with a lantern, lit from the start (vision +3)
func _lit_profile() -> CharacterProfile:
	var profile: CharacterProfile = ModelFreeWorld.load_hero_profile().duplicate()
	profile.abilities = [LANTERN]
	return profile

func _spawn_monster(cell: Vector2i) -> Character:
	_level.spawn_monster(ModelFreeWorld.load_monster_profile(), cell)
	await await_idle_frame()
	var spawner: AgentSpawner = _level.get("_agent_spawner")
	var agents: Array[Node] = spawner.get_children()
	return (agents[-1] as Agent).character

## The direction of a straight passage of [param steps] steps from the start
func _straight_way(steps: int) -> Level.Direction:
	var start: Vector2i = _start_cell()
	for direction: Level.Direction in Level.Direction.values():
		var cell: Vector2i = start
		for _step: int in steps:
			if not _level.is_passage(cell, direction): break
			cell += Level.direction_to_vector(direction)
		if cell == start + Level.direction_to_vector(direction) * steps: return direction
	assert(false, "No straight passage of %d steps from the start" % steps)
	return Level.Direction.DOWN

## A monster [param steps] steps straight from the start, facing the start or away from it, along the first straight passage of
## [param way_steps] steps (at least [param steps])
func _spawn_monster_ahead(steps: int, facing_start: bool, way_steps: int = 0) -> Character:
	var way: Level.Direction = _straight_way(maxi(steps, way_steps))
	var cell: Vector2i = _start_cell() + Level.direction_to_vector(way) * steps
	var monster: Character = await _spawn_monster(cell)
	assert_that(monster.grid_cell).is_equal(cell)
	monster.place_on_grid(cell, monster.tile_spot, Level.get_opposite(way) if facing_start else way)
	return monster

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

func _agent(monster: Character) -> Agent:
	return monster.get_parent() as Agent

func _move(hero: Character, direction: Level.Direction) -> void:
	_turn_manager.request_move(hero.get_path(), direction)
	await await_idle_frame()

## Walks [param hero] [param steps] steps out along [param way] and back, so the tiles on the way are explored and later steps
## there change nothing on the board (and stay undoable); the hero keeps its moves and nothing is left to undo
func _explore(hero: Character, way: Level.Direction, steps: int) -> void:
	for _step: int in steps:
		hero.movement_points = hero.profile.speed
		await _move(hero, way)
	for _step: int in steps:
		hero.movement_points = hero.profile.speed
		await _move(hero, Level.get_opposite(way))
	_turn_manager.close_undo(hero)
	hero.movement_points = hero.profile.speed

## Passes for the local player and waits until the monsters are done and the next turn started
func _pass_turn() -> void:
	var turn: int = _turn_manager.turn_number
	_turn_manager.request_pass(true)
	for _frame: int in MAX_FRAMES:
		if _turn_manager.turn_number > turn: return
		await await_idle_frame()
	fail("The monster phase did not end")
