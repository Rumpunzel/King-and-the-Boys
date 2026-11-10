extends GdUnitTestSuite
## Rooms as a whole: dust fills every tile of a dusty room, and centrepieces stand on the corner in a room's middle

const LEVEL: String = "res://data/levels/level.tscn"
const ROOM: String = "res://data/structures/tiles/room/room_crossing.tres"
const DECORATIONS: String = "res://data/structures/tiles/dungeon_decorations.tres"
const DUST: String = "res://data/structures/props/room_dust.tres"
const CENTREPIECES: Array[String] = ["res://data/things/centrepieces/sarcophagus.tres", "res://data/things/centrepieces/dwarf_throne.tres"]

var _level: Level
var _dusty_room_chance: float

func before_test() -> void:
	_dusty_room_chance = (load(DECORATIONS) as TileDecorations).dusty_room_chance
	_level = auto_free((load(LEVEL) as PackedScene).instantiate())
	add_child(_level)

func after_test() -> void:
	(load(DECORATIONS) as TileDecorations).dusty_room_chance = _dusty_room_chance

## A 3x3 room around (0, 0), as loading spawns it: tile by tile, already [param status]
func _spawn_room(status: Structure.Status) -> Array[Vector2i]:
	var room: StructureProfile = load(ROOM)
	var cells: Array[Vector2i] = []
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var cell: Vector2i = Vector2i(x, y)
			_level._structure_spawner.spawn_at(room, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell)), 0, status)
			cells.append(cell)
	return cells

func _dust_count(cell: Vector2i) -> int:
	var tile: Structure = _level.get_placed_tile(cell)
	if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): return 0
	var scenes: Array = (load(DUST) as PropSet).props.keys().map(func(scene: PackedScene) -> String: return scene.resource_path)
	var props: Array[Node] = tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children()
	return props.filter(func(prop: Node) -> bool: return scenes.has(prop.get_child(0).scene_file_path)).size()

func test_room_cells_follow_the_connections_of_one_room() -> void:
	var cells: Array[Vector2i] = _spawn_room(Structure.Status.PLACED)
	var found: Array[Vector2i] = _level.get_room_cells(Vector2i(1, 1))
	assert_array(found).contains_exactly_in_any_order(cells)
	# The outer tiles still lead to cells that are not built
	assert_bool(_level.is_room_complete(found)).is_false()
	assert_array(_level.get_room_cells(Vector2i(5, 5))).is_empty()

func test_a_dusty_room_is_dusty_throughout() -> void:
	(load(DECORATIONS) as TileDecorations).dusty_room_chance = 1.0
	var cells: Array[Vector2i] = _spawn_room(Structure.Status.REVEALED)
	# Tiles arriving one by one wait for the rest of their room
	await await_idle_frame()
	for cell: Vector2i in cells: assert_int(_dust_count(cell)).override_failure_message("No dust at %s" % cell).is_equal(1)

func test_a_clear_room_has_no_dust() -> void:
	(load(DECORATIONS) as TileDecorations).dusty_room_chance = 0.0
	var cells: Array[Vector2i] = _spawn_room(Structure.Status.REVEALED)
	await await_idle_frame()
	for cell: Vector2i in cells: assert_int(_dust_count(cell)).is_equal(0)

func test_a_centrepiece_stands_on_the_middle_corner_once() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.PLACED)
	_level.call("_furnish_room", Vector2i.ZERO)
	# Rooms are built again on every step
	_level.call("_furnish_room", Vector2i(1, -1))
	await await_idle_frame()
	var corner_things: Dictionary[Vector2i, Thing] = _level.get("_corner_things")
	assert_array(corner_things.keys()).contains_exactly([Vector2i(0, 1)])
	var thing: Thing = corner_things[Vector2i(0, 1)]
	assert_array(CENTREPIECES).contains([thing.profile.resource_path])
	assert_vector(thing.global_position).is_equal_approx(Vector3(-0.5, 0.0, 0.5) * _level.grid_size, Vector3.ONE * 0.001)
	# The figure on the tile looks at it
	assert_object(_level.get_thing_near(Vector2i(-1, 0))).is_same(thing)
	assert_object(_level.get_placed_thing(Vector2i(-1, 0))).is_null()

func test_a_centrepiece_takes_the_spot_towards_it_on_its_four_tiles() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.PLACED)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	var extents: Vector2 = _level.get_placed_tile(Vector2i.ZERO).profile.tile_spot_extents
	# Corner (0, 1) lies at the lower left of (0, 0), the lower right of (-1, 0), and so on
	var taken: Dictionary[Vector2i, Vector2] = {
		Vector2i(0, 0): Vector2(-1.0, 1.0), Vector2i(-1, 0): Vector2(1.0, 1.0), Vector2i(0, 1): Vector2(-1.0, -1.0), Vector2i(-1, 1): Vector2(1.0, -1.0),
	}
	for cell: Vector2i in taken:
		var free_spots: Array[Vector2] = _level.get_free_spots(cell)
		assert_int(free_spots.size()).is_equal(4)
		assert_array(free_spots).not_contains([taken[cell] * extents])
		# The middle stays free for pieces
		assert_vector(free_spots.front()).is_equal(Vector2.ZERO)
	assert_int(_level.get_free_spots(Vector2i(1, -1)).size()).is_equal(5)

func test_a_centrepiece_shows_with_the_first_of_its_tiles() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.PLACED)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	var thing: Thing = (_level.get("_corner_things") as Dictionary)[Vector2i(0, 1)]
	assert_int(thing.status).is_equal(Thing.Status.PLACED)
	_level.get_placed_tile(Vector2i(-1, 1)).shown_status = Structure.Status.REVEALED
	assert_int(thing.status).is_equal(Thing.Status.REVEALED)

func test_rooms_are_listed_once_each() -> void:
	var cells: Array[Vector2i] = _spawn_room(Structure.Status.PLACED)
	var rooms: Array[Array] = _level.get_rooms()
	assert_int(rooms.size()).is_equal(1)
	assert_array(rooms[0]).contains_exactly_in_any_order(cells)
	assert_int(_level.get_placed_tiles().size()).is_equal(cells.size())

func test_the_debug_drawings_toggle() -> void:
	var debug: LevelDebug = _level.find_child("LevelDebug") as LevelDebug
	assert_object(debug).is_not_null()
	assert_bool(debug.shown).override_failure_message("Hidden at first").is_false()
	var toggle: InputEventAction = InputEventAction.new()
	toggle.action = LevelDebug.ACTION
	toggle.pressed = true
	debug.call("_unhandled_input", toggle)
	assert_bool(debug.shown).is_true()
	_spawn_room(Structure.Status.REVEALED)
	# Drawing a frame of it does not fail
	await await_idle_frame()
	debug.call("_unhandled_input", toggle)
	assert_bool(debug.shown).is_false()
