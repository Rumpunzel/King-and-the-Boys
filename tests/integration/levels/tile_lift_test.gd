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

func test_sparkles_hang_under_the_tile_while_it_is_lifted() -> void:
	var sparkles: GPUParticles3D = GPUParticles3D.new()
	sparkles.lifetime = 0.2
	var scene: PackedScene = PackedScene.new()
	scene.pack(sparkles)
	sparkles.free()
	var animation: TileLiftAnimation = TileLiftAnimation.new()
	animation.hover_particles = scene
	_level.tile_lift_animation = animation
	_tile.lifted_by = _hero.get_path()
	var hovering: Array[Node] = _tile.model.find_children("*", "GPUParticles3D", false, false)
	assert_int(hovering.size()).is_equal(1)
	assert_bool((hovering[0] as GPUParticles3D).emitting).is_true()
	await await_millis(600)
	_tile.lifted_by = NodePath()
	assert_bool((hovering[0] as GPUParticles3D).emitting).is_false()
	await await_millis(1500)
	assert_array(_tile.model.find_children("*", "GPUParticles3D", false, false)).is_empty()
	_level.tile_lift_animation = null

func test_what_a_turn_reveals_waits_a_moment_after_the_tile_is_set_down() -> void:
	_tile.lifted_by = _hero.get_path()
	await await_millis(600)
	var landed: Array[bool] = _landed()
	# Set down turned, as the ability does: a moment's wait, counted from now, not from the landing
	_tile.lifted_by = NodePath()
	_level.rotate_tile(_tile, 1, _hero)
	assert_bool(_level._has_figure_caught_up(_hero, [])).is_false()
	var animation: TileLiftAnimation = TileLiftAnimation.of(_level)
	assert_float(animation.reveal_delay).is_less(animation.spin_duration * 0.5 + animation.drop_duration)
	await await_millis(int(animation.reveal_delay * 1000.0) + 100)
	assert_bool(landed[0]).override_failure_message("Still dropping").is_false()
	assert_bool(_level._has_figure_caught_up(_hero, [])).is_true()

func test_lifted_again_while_dropping_it_rises_again() -> void:
	_tile.lifted_by = _hero.get_path()
	await await_millis(600)
	_tile.lifted_by = NodePath()
	await await_millis(300)
	# Not landed yet: the figure still rides it
	assert_bool(_hero.is_carried()).is_true()
	_tile.lifted_by = _hero.get_path()
	await await_millis(900)
	assert_float(_tile.model.position.y).is_greater(TileLiftAnimation.of(_level).height * 0.8)
	assert_bool(_hero.is_carried()).is_true()
	var landed: Array[bool] = _landed()
	_tile.lifted_by = NodePath()
	await await_millis(1500)
	assert_bool(landed[0]).is_true()
	assert_bool(_hero.is_carried()).is_false()
	assert_float(_tile.model.position.y).is_equal(0.0)

func test_a_figure_on_its_way_arrives_before_it_is_carried() -> void:
	var other_spot: Vector2 = Vector2.INF
	for spot: Vector2 in _tile.profile.get_tile_spots(): if spot != _hero.tile_spot: other_spot = spot
	_hero.place_on_grid(_hero.grid_cell, other_spot, _hero.facing)
	await await_idle_frame()
	var arrived: Array[bool] = [false]
	_hero.figure_arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	_tile.lifted_by = _hero.get_path()
	assert_bool(arrived[0]).override_failure_message("The step under way ended").is_true()
	assert_bool(_hero.is_carried()).is_true()
	var spot_position: Vector3 = _level.get_spot_position(_hero.grid_cell, other_spot)
	assert_vector(Vector3(_hero.global_position.x, 0.0, _hero.global_position.z)).is_equal_approx(Vector3(spot_position.x, 0.0, spot_position.z), Vector3.ONE * 0.01)

func test_a_cancelled_lift_holds_nothing_back() -> void:
	_tile.lifted_by = _hero.get_path()
	await await_millis(300)
	_tile.lifted_by = NodePath()
	assert_bool(_level._has_figure_caught_up(_hero, [])).is_true()

func test_setting_down_tells_of_it_once() -> void:
	var changes: Array[int] = [0]
	_tile.lift_changed.connect(func() -> void: changes[0] += 1)
	_tile.lifted_by = _hero.get_path()
	_tile.lift_turns = 2
	changes[0] = 0
	_tile.lifted_by = NodePath()
	assert_int(changes[0]).is_equal(1)
	assert_int(_tile.lift_turns).is_equal(0)

func test_figures_ride_a_turn_on_the_board_and_step_off_once_it_is_in_place() -> void:
	# Off the middle, where a jump would show
	for spot: Vector2 in _tile.profile.get_tile_spots():
		if spot.x != 0.0 and spot.y != 0.0: _hero.place_on_grid(_hero.grid_cell, spot, _hero.facing)
	# Arrived there
	await _hero.figure_arrived
	var standing: Vector3 = _hero.global_position
	# A slow spin, so the first frame shows where the ride starts
	var slow: TileLiftAnimation = TileLiftAnimation.new()
	slow.spin_duration = 0.8
	_level.tile_lift_animation = slow
	# As when a turn is undone: no lift, the model spins into place
	_level.rotate_tile(_tile, 1, _hero)
	assert_bool(_hero.is_carried()).is_true()
	# It rides on from where it stood, not from a quarter turn away
	for _frame: int in 3:
		await await_idle_frame()
		assert_float(_hero.global_position.distance_to(standing)).is_less(0.2)
	_level.tile_lift_animation = null
	assert_bool(_level._has_figure_caught_up(_hero, [])).is_false()
	await await_millis(1200)
	assert_bool(_hero.is_carried()).is_false()
	assert_bool(_level._has_figure_caught_up(_hero, [])).is_true()

func test_the_thing_on_the_tile_rides_by_its_model() -> void:
	var chest: Thing = auto_free(Thing.new())
	chest.freeze = true
	chest.model = Model.new()
	add_child(chest)
	chest.global_position = _tile.global_position
	var placed_things: Dictionary = _level.get("_placed_things")
	placed_things[_tile.get_grid_position()] = chest
	_tile.lifted_by = _hero.get_path()
	await await_millis(900)
	assert_float(chest.model.global_position.y).is_greater(0.3)
	assert_float(chest.global_position.y).is_equal_approx(_tile.global_position.y, 0.001)
	_tile.lifted_by = NodePath()
	await await_millis(1500)
	assert_vector(chest.model.position).is_equal(Vector3.ZERO)
	placed_things.erase(_tile.get_grid_position())

func test_a_second_turn_soon_after_holds_its_own_reveals() -> void:
	var delay: float = TileLiftAnimation.of(_level).reveal_delay
	_level.rotate_tile(_tile, 1, _hero)
	await await_millis(int(delay * 600.0))
	# Undone a moment later: its own wait, not what is left of the first
	_level.rotate_tile(_tile, -1, _hero)
	await await_millis(int(delay * 600.0))
	assert_bool(_level._reveals_held_on.has(_tile.get_grid_position())).is_true()
	await await_millis(int(delay * 600.0))
	assert_bool(_level._reveals_held_on.has(_tile.get_grid_position())).is_false()

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
