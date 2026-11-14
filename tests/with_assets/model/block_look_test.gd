extends GdUnitTestSuite
## How blocks look on real figures: a fallen hero lies in its down animations and gets up into its idles, and what a block does
## to a figure (its fall, its push) waits until the strike landed

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const KNIGHT: String = "uid://cqkx0op1msr7s"  # data/characters/people/knight.tres

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	await await_idle_frame()

func after_test() -> void:
	await await_idle_frame()

func _start_cell() -> Vector2i:
	var spawn_point: Node3D = get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	return _level.world_to_grid_position(spawn_point.global_position)

func _spawn_knight() -> Character:
	var knight: CharacterProfile = load(KNIGHT)
	var figure: Character = auto_free(knight.create(0, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(_start_cell()))))
	figure.level = _level
	add_child(figure)
	await await_idle_frame()
	return figure

func test_a_fallen_hero_lies_down_and_gets_up_into_its_idles() -> void:
	var knight: Character = await _spawn_knight()
	knight.posture = Character.Posture.DOWN
	assert_object(knight.model.get_rest_animations()).is_same(knight.profile.down_animations)
	knight.posture = Character.Posture.STANDING
	assert_object(knight.model.get_rest_animations()).is_same(knight.model.idle_animations)

func test_a_fall_and_a_push_wait_until_the_strike_lands() -> void:
	var attacker: Character = await _spawn_knight()
	var defender: Character = await _spawn_knight()
	var start: Vector2i = defender.grid_cell
	var way: int = -1
	for direction: Level.Direction in Level.Direction.values():
		if _level.is_passage(start, direction): way = direction
	assert_int(way).is_not_equal(-1)
	attacker.show_block(defender)
	var position_before: Vector3 = defender.global_position
	var target: Vector2i = start + Level.direction_to_vector(way as Level.Direction)
	var spot: Vector2 = _level.get_free_spots(target, defender).front()
	defender.place_on_grid(target, spot, way as Level.Direction)
	defender.posture = Character.Posture.DOWN
	await await_idle_frame()
	# Still standing where it was while the strike swings
	assert_object(defender.model.get_rest_animations()).is_not_same(defender.profile.down_animations)
	assert_vector(defender.global_position).is_equal_approx(position_before, Vector3.ONE * 0.001)
	assert_bool(defender.is_figure_moving()).is_true()
	await await_millis(roundi(attacker.profile.block_animation.length * 1000.0))
	assert_object(defender.model.get_rest_animations()).is_same(defender.profile.down_animations)
	assert_vector(defender.global_position).is_not_equal(position_before)
