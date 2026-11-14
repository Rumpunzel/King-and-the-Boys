extends GdUnitTestSuite
## Crowding with the model-free tiles: a passage into an empty cell beside a placed tile's closed side weighs less
## ([member DungeonTileSet.crowding_weight]), so the dungeon leaves gaps between its corridors; the outer wall crowds no one

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const DEAD_END: String = "uid://d3genhasqmljm"  # tests/fixtures/tiles/dead_end.tres
const SEEDS: int = 30

var _level: Level
var _tile_set: DungeonTileSet

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_tile_set = _level.get(&"_tile_set")
	# Never into a crowded cell where another tile fits
	_tile_set.crowding_weight = 0.0
	add_child(_level)

func after_test() -> void:
	# The tile set is cached and shared with the other suites
	_tile_set.crowding_weight = 1.0
	await await_idle_frame()

## @returns for each seed whether the tile it places on [param cell] leads towards [param direction]
func _leads_towards(cell: Vector2i, direction: Level.Direction) -> Array[bool]:
	var leads: Array[bool] = []
	for generation_seed: int in SEEDS:
		_level.generation_random.seed = generation_seed
		_level.spawn_at(cell)
		var tile: Structure = _level.get_placed_tile(cell)
		leads.append(tile.has_connection(direction))
		tile.get_parent().remove_child(tile)
		tile.queue_free()
	return leads

func test_no_passage_leads_beside_a_closed_side() -> void:
	# A dead end on (1, 1) opening down turns its closed back to (1, 0), right of (0, 0)
	_level.call("_spawn_at", DungeonTileSet.TileBlueprint.new(load(DEAD_END) as StructureProfile, Level.Direction.DOWN), Vector2i(1, 1))
	assert_array(_leads_towards(Vector2i.ZERO, Level.Direction.RIGHT)).not_contains([true])

func test_the_outer_wall_crowds_no_one() -> void:
	_level.call("_build_outer_wall")
	var beside_wall: Vector2i = Vector2i(_level.grid_extents.x - 2, 0)
	assert_array(_leads_towards(beside_wall, Level.Direction.RIGHT)).contains([true])
