extends GdUnitTestSuite
## Connection restrictions with the model-free tiles: a picky dead end lets its passage lead only into a straight
## tile. The level keeps that wherever it can, and records the cells where it cannot.

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const PICKY: String = "res://tests/fixtures/tiles/restricted/picky_dead_end.tres"
const STRAIGHT: String = "res://tests/fixtures/tiles/straight.tres"

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)

func after_test() -> void:
	await await_idle_frame()

## A picky dead end on [param cell], its passage turned towards [param towards]
func _place_picky(cell: Vector2i, towards: Level.Direction) -> void:
	_level.call("_spawn_at", DungeonTileSet.TileBlueprint.new(load(PICKY) as StructureProfile, towards), cell)

func _remove(cell: Vector2i) -> void:
	var tile: Structure = _level.get_placed_tile(cell)
	tile.get_parent().remove_child(tile)
	tile.queue_free()

func test_a_cell_keeps_its_neighbours_restriction_wherever_it_can() -> void:
	# The passage from below leads into (0, 0): only a straight tile may stand there
	_place_picky(Vector2i(0, 1), Level.Direction.UP)
	for generation_seed: int in 30:
		_level.generation_random.seed = generation_seed
		_level.spawn_at(Vector2i.ZERO)
		var tile: Structure = _level.get_placed_tile(Vector2i.ZERO)
		assert_str(tile.profile.resource_path).override_failure_message("Seed %d placed %s" % [generation_seed, tile.profile.name]).is_equal(STRAIGHT)
		assert_bool(_level.restriction_fallbacks.has(Vector2i.ZERO)).is_false()
		_remove(Vector2i.ZERO)

func test_where_no_tile_can_the_cell_is_recorded_and_forgotten_with_its_tile() -> void:
	# Passages from below and from the right meet at (0, 0): no straight tile takes both
	_place_picky(Vector2i(0, 1), Level.Direction.UP)
	_place_picky(Vector2i(1, 0), Level.Direction.LEFT)
	_level.spawn_at(Vector2i.ZERO)
	assert_bool(_level.restriction_fallbacks.has(Vector2i.ZERO)).is_true()
	_remove(Vector2i.ZERO)
	assert_bool(_level.restriction_fallbacks.has(Vector2i.ZERO)).is_false()
