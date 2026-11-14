extends GdUnitTestSuite
## Reach on the grid: a piece reaches its own cell and the next ones along passages, and things on a grid corner stand on
## all four cells around it

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	# Seeded: it needs both open and walled neighbours, which not every dungeon has after its first build
	_level.generation_random.seed = 42
	add_child(_level)
	_level.build_level()
	await await_idle_frame()

func _walkable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in (_level.get("_placed_tiles") as Dictionary):
		if not _level.get_placed_tile(cell).get_connections().is_empty(): cells.append(cell)
	return cells

## @returns [cell, neighbour] of two placed, walkable tiles side by side, with or without a passage between them; empty if
## the level has none
func _neighbours(with_passage: bool) -> Array[Vector2i]:
	for cell: Vector2i in _walkable_cells():
		for direction: Level.Direction in Level.Direction.values():
			var neighbour: Vector2i = cell + Level.direction_to_vector(direction)
			if not _walkable_cells().has(neighbour): continue
			if _level.is_passage(cell, direction) == with_passage: return [cell, neighbour]
	return []

func test_a_piece_reaches_its_cell_and_the_next_ones_along_passages() -> void:
	var open: Array[Vector2i] = _neighbours(true)
	assert_array(open).is_not_empty()
	assert_array(_level.get_cells_in_reach(open[0])).contains([open[0], open[1]])
	var walled: Array[Vector2i] = _neighbours(false)
	assert_array(walled).override_failure_message("The level has no walled neighbours to check").is_not_empty()
	assert_array(_level.get_cells_in_reach(walled[0])).not_contains([walled[1]])
	# Never further than one step
	for cell: Vector2i in _level.get_cells_in_reach(open[0]):
		assert_int(absi(cell.x - open[0].x) + absi(cell.y - open[0].y)).is_less_equal(1)

func test_a_thing_on_a_grid_corner_stands_on_its_four_cells() -> void:
	var corner: Vector2i = Vector2i(1, 1)
	var corner_things: Dictionary = _level.get("_corner_things")
	var centrepiece: Thing = auto_free(Thing.new())
	corner_things[corner] = centrepiece
	var cells: Array[Vector2i] = _level.get_cells_of(centrepiece)
	corner_things.erase(corner)
	assert_array(cells).contains_exactly_in_any_order([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])

func test_any_other_thing_stands_on_the_cell_under_it() -> void:
	var thing: Thing = auto_free(Thing.new())
	thing.model = Model.new()
	add_child(thing)
	thing.global_position = _level.grid_to_world_position(Vector2i(2, -1))
	assert_array(_level.get_cells_of(thing)).contains_exactly([Vector2i(2, -1)])
