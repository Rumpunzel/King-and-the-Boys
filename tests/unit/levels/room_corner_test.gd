extends GdUnitTestSuite
## Where a room's centrepiece stands: on the grid corner nearest the room's middle, never where a pillar stands

func _cells(from: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x: cells.append(from + Vector2i(x, y))
	return cells

func test_a_2x2_room_uses_its_middle_corner() -> void:
	assert_that(Level.get_centrepiece_corner(_cells(Vector2i(0, 0), Vector2i(2, 2)))).is_equal(Vector2i(1, 1))

func test_pillar_corners_are_left_to_the_pillars() -> void:
	# The only inner corner of this room has even indices
	assert_that(Level.get_centrepiece_corner(_cells(Vector2i(-1, -1), Vector2i(2, 2)))).is_null()

func test_narrow_rooms_get_none() -> void:
	assert_that(Level.get_centrepiece_corner(_cells(Vector2i(0, 0), Vector2i(4, 1)))).is_null()
	assert_that(Level.get_centrepiece_corner([] as Array[Vector2i])).is_null()

func test_the_corner_nearest_the_middle_wins_and_ties_go_alike() -> void:
	# A 3x3 room around (0, 0): its middle corner (0, 0) holds a pillar, three corners tie
	var cells: Array[Vector2i] = _cells(Vector2i(-1, -1), Vector2i(3, 3))
	assert_that(Level.get_centrepiece_corner(cells)).is_equal(Vector2i(0, 1))
	cells.reverse()
	assert_that(Level.get_centrepiece_corner(cells)).is_equal(Vector2i(0, 1))
	# In a long room the middle is further along
	assert_that(Level.get_centrepiece_corner(_cells(Vector2i(0, 0), Vector2i(6, 2)))).is_equal(Vector2i(3, 1))
