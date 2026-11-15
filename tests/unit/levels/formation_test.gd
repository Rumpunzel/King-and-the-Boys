extends GdUnitTestSuite
## Where a side's figures stand on a tile: gathered in the middle alone, lined up towards their edge facing enemies

func test_a_side_faces_the_other_across_the_tile() -> void:
	assert_vector(Formation.get_axis(Level.Direction.DOWN, Level.Direction.UP)).is_equal(Vector2.DOWN)
	assert_vector(Formation.get_axis(Level.Direction.DOWN, -1)).is_equal(Vector2.DOWN)
	# On neighbouring edges: across the corner between them
	assert_vector(Formation.get_axis(Level.Direction.DOWN, Level.Direction.RIGHT)).is_equal_approx(Vector2(-1.0, 1.0).normalized(), Vector2.ONE * 0.001)

func test_facing_enemies_the_lead_stands_in_front_and_the_others_behind() -> void:
	var blocked: Array[Vector2] = []
	var spots: Array[Vector2] = Formation.get_spots(3, Vector2.DOWN, true, blocked)
	assert_int(spots.size()).is_equal(3)
	assert_float(spots[0].x).is_equal_approx(0.0, 0.001)
	assert_float(spots[0].y).is_greater(0.0)
	for spot: Vector2 in spots.slice(1): assert_float(spot.y).is_greater(spots[0].y)
	assert_float(spots[1].distance_to(spots[2])).is_greater(0.5)
	# The other side's lead stands nose to nose with it
	var other: Array[Vector2] = Formation.get_spots(1, Vector2.UP, true, blocked)
	assert_float(spots[0].distance_to(other[0])).is_less(0.7)

func test_alone_a_side_gathers_in_the_middle() -> void:
	var blocked: Array[Vector2] = []
	assert_array(Formation.get_spots(1, Vector2.DOWN, false, blocked)).is_equal([Vector2.ZERO])
	var spots: Array[Vector2] = Formation.get_spots(3, Vector2.DOWN, false, blocked)
	for spot: Vector2 in spots: assert_float(spot.length()).is_less(0.6)
	for index: int in spots.size():
		for other: int in range(index + 1, spots.size()): assert_float(spots[index].distance_to(spots[other])).is_greater(0.5)

func test_figures_keep_clear_of_what_stands_on_the_tile_and_on_it() -> void:
	var chest: Array[Vector2] = [Vector2.ZERO]
	var spot: Vector2 = Formation.get_spots(1, Vector2.DOWN, false, chest)[0]
	assert_float(spot.length()).is_greater_equal(0.49)
	var corner: Array[Vector2] = [Vector2(0.5, 0.5)]
	# Even where the edge of the tile is near: the back spot towards that corner keeps clear too
	for clear: Vector2 in Formation.get_spots(3, Vector2.DOWN, true, corner):
		assert_bool(Formation.is_clear(clear, corner)).is_true()
		assert_float(maxf(absf(clear.x), absf(clear.y))).is_less_equal(0.75)

func test_the_edge_towards_a_spot() -> void:
	assert_int(Formation.get_edge_towards(Vector2(0.0, 0.5))).is_equal(Level.Direction.DOWN)
	assert_int(Formation.get_edge_towards(Vector2(-0.5, 0.1))).is_equal(Level.Direction.LEFT)
	assert_int(Formation.get_edge_towards(Vector2.ZERO)).is_equal(-1)
