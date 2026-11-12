extends GdUnitTestSuite
## How a lifted tile shows on a generated level (no assets): it rises with the figures on it, wobbles, spins and lands

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")

var _level: Level
var _hero: Character
var _tile: Structure

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)
	_level.build_level()
	await await_idle_frame()
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var start_cell: Vector2i = _level.world_to_grid_position((spawn_points.front() as Node3D).global_position)
	_hero = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(start_cell))))
	_hero.level = _level
	add_child(_hero)
	await await_idle_frame()
	_tile = _level.get_placed_tile(start_cell)
	# The test tiles have no model to lift
	_tile.model = Model.new()

func _landed() -> Array[bool]:
	var landed: Array[bool] = [false]
	var lift: TileLift = _tile.get_node(^"TileLift")
	lift.landed.connect(func() -> void: landed[0] = true, CONNECT_ONE_SHOT)
	return landed

func test_a_lifted_tile_rises_with_its_figures_and_wobbles() -> void:
	_tile.lifted_by = _hero.get_path()
	assert_bool(_hero.is_carried()).is_true()
	await await_millis(900)
	assert_float(_tile.model.position.y).is_greater(0.3)
	var tilt: float = absf(_tile.model.rotation.x) + absf(_tile.model.rotation.z)
	assert_float(tilt).is_greater(0.0)
	assert_float(tilt).is_less(deg_to_rad(6.0))
	assert_float(_hero.global_position.y).is_greater(0.3)

func test_the_lifted_tile_spins_to_its_lift_turns() -> void:
	_tile.lifted_by = _hero.get_path()
	_tile.lift_turns = 3
	await await_millis(600)
	# Three quarter turns clockwise are one back: the shorter way
	assert_float(_tile.model.rotation.y).is_equal_approx(PI * 0.5, 0.05)

func test_setting_down_turned_lands_where_the_tile_now_faces() -> void:
	_tile.lifted_by = _hero.get_path()
	_tile.lift_turns = 1
	await await_millis(600)
	var landed: Array[bool] = _landed()
	_tile.lifted_by = NodePath()
	_level.rotate_tile(_tile, 1, _hero)
	await await_millis(1500)
	assert_bool(landed[0]).is_true()
	assert_vector(_tile.model.position).is_equal(Vector3.ZERO)
	assert_vector(_tile.model.rotation).is_equal(Vector3.ZERO)
	assert_bool(_hero.is_carried()).is_false()
	await await_idle_frame()
	assert_vector(_hero.global_position).is_equal_approx(_level.get_spot_position(_hero.grid_cell, _hero.tile_spot), Vector3.ONE * 0.01)
	assert_float(_hero.rotation.x).is_equal(0.0)

func test_setting_down_three_quarters_turned_does_not_spin_again() -> void:
	_tile.lifted_by = _hero.get_path()
	_tile.lift_turns = 3
	await await_millis(600)
	# As the ability confirms: the lift ends, then the tile turns
	_tile.lifted_by = NodePath()
	_level.rotate_tile(_tile, 3, _hero)
	var widest: float = 0.0
	for _frame: int in 30:
		await await_idle_frame()
		widest = maxf(widest, absf(angle_difference(0.0, _tile.model.rotation.y)))
	assert_float(widest).override_failure_message("The model spun by %.2f rad while it was set down" % widest).is_less(0.2)

func _puffs_on(tile: Structure) -> int:
	return tile.find_children("*", "GPUParticles3D", false, false).size()

func test_the_tile_puffs_as_it_rises_and_as_it_lands() -> void:
	var puff: GPUParticles3D = GPUParticles3D.new()
	puff.one_shot = true
	puff.lifetime = 0.2
	var scene: PackedScene = PackedScene.new()
	scene.pack(puff)
	puff.free()
	var animation: TileLiftAnimation = TileLiftAnimation.new()
	animation.rise_particles = scene
	animation.landing_particles = scene
	_level.tile_lift_animation = animation
	_tile.lifted_by = _hero.get_path()
	assert_int(_puffs_on(_tile)).is_equal(1)
	await await_millis(1000)
	# Gone once played
	assert_int(_puffs_on(_tile)).is_equal(0)
	_tile.lifted_by = NodePath()
	await await_millis(int((animation.spin_duration * 0.5 + animation.drop_duration * animation.landing_time) * 1000.0) + 100)
	assert_int(_puffs_on(_tile)).is_equal(1)
	_level.tile_lift_animation = null

func test_a_cancelled_lift_spins_back_and_lands() -> void:
	var turns: int = _tile.clockwise_turns
	_tile.lifted_by = _hero.get_path()
	_tile.lift_turns = 2
	await await_millis(600)
	var landed: Array[bool] = _landed()
	_tile.lifted_by = NodePath()
	await await_millis(1500)
	assert_bool(landed[0]).is_true()
	assert_int(_tile.clockwise_turns).is_equal(turns)
	assert_vector(_tile.model.rotation).is_equal(Vector3.ZERO)

func test_a_turn_without_lift_spins_the_model_into_place() -> void:
	var landed: Array[bool] = [false]
	_level.rotate_tile(_tile, 1, _hero)
	var lift: TileLift = _tile.get_node(^"TileLift")
	assert_bool(lift.is_busy()).is_true()
	lift.landed.connect(func() -> void: landed[0] = true, CONNECT_ONE_SHOT)
	await await_millis(800)
	assert_bool(landed[0]).is_true()
	assert_vector(_tile.model.rotation).is_equal(Vector3.ZERO)
