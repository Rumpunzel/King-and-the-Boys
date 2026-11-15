extends GdUnitTestSuite
## Sight across a room on model-free room tiles: a room tile's exit may lead into a cell the dungeon has not grown into yet (e.g.
## a room tile placed beside a corridor joins a room built before it), and sight stops there

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const ROOM_DEAD_END: String = "uid://rd0eyv3tiole"  # tests/fixtures/tiles/room/room_dead_end.tres

var _level: Level

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	add_child(_level)

func after_test() -> void:
	await await_idle_frame()

## A room dead end on [param cell], its exit turned [param clockwise_turns] quarter turns from up
func _place_room_dead_end(cell: Vector2i, clockwise_turns: int) -> void:
	_level.call("_spawn_at", DungeonTileSet.TileBlueprint.new(load(ROOM_DEAD_END) as StructureProfile, clockwise_turns), cell)

func test_sight_across_a_room_stops_at_an_exit_into_unbuilt_cells() -> void:
	# Two tiles of one room, each with an exit into an empty cell
	_place_room_dead_end(Vector2i(0, 0), 0)
	_place_room_dead_end(Vector2i(0, 1), 2)
	var seen: Dictionary[Vector2i, bool] = LevelSight.new(_level).get_cells_in_sight(Vector2i.ZERO, 3.0)
	assert_array(seen.keys()).contains_exactly_in_any_order([Vector2i(0, 0), Vector2i(0, 1)])
