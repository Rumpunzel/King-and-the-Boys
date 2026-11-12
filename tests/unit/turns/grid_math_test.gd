extends GdUnitTestSuite
## Facing and tile spot math; no level or assets needed

func test_facing_survives_a_round_trip_through_rotation() -> void:
	for direction: Level.Direction in Level.Direction.values():
		assert_int(Character.rotation_to_facing(Character.facing_to_rotation(direction))).is_equal(direction)

func test_facing_down_is_no_rotation() -> void:
	assert_float(Character.facing_to_rotation(Level.Direction.DOWN)).is_equal_approx(0.0, 0.0001)

func test_profile_tile_spots_are_directions_times_extents() -> void:
	var profile: StructureProfile = StructureProfile.new()
	assert_array(profile.get_tile_spots()).is_equal([Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	profile.tile_spot_extents = Vector2(0.25, 0.75)
	assert_vector(profile.get_tile_spots()[3]).is_equal(Vector2(0.25, 0.75))

func test_turning_follows_the_clock() -> void:
	assert_int(Level.turn_direction(Level.Direction.UP, 1)).is_equal(Level.Direction.RIGHT)
	assert_int(Level.turn_direction(Level.Direction.LEFT, 1)).is_equal(Level.Direction.UP)
	assert_int(Level.turn_direction(Level.Direction.RIGHT, -1)).is_equal(Level.Direction.UP)
	assert_int(Level.get_opposite(Level.Direction.DOWN)).is_equal(Level.Direction.UP)

func test_spots_turn_with_their_tile() -> void:
	var up: Vector2 = Vector2(Level.direction_to_vector(Level.Direction.UP))
	var right: Vector2 = Vector2(Level.direction_to_vector(Level.Direction.RIGHT))
	assert_vector(Level.turn_spot(up, 1)).is_equal(right)
	assert_vector(Level.turn_spot(Vector2(0.5, -0.5), 2)).is_equal(Vector2(-0.5, 0.5))
	assert_vector(Level.turn_spot(Vector2(0.5, -0.5), 4)).is_equal(Vector2(0.5, -0.5))
	assert_vector(Level.turn_spot(Vector2(0.5, -0.5), -1)).is_equal(Level.turn_spot(Vector2(0.5, -0.5), 3))
