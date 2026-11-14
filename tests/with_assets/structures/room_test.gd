extends GdUnitTestSuite
## Rooms as a whole: dust fills every tile of a dusty room, and centrepieces stand on the corner in a room's middle

const LEVEL: String = "res://data/levels/level.tscn"
const ROOM: String = "res://data/structures/tiles/room/room_crossing.tres"
const CORRIDOR: String = "res://data/structures/tiles/crossing.tres"
const DECORATIONS: String = "res://data/structures/tiles/dungeon_decorations.tres"
const ROOM_DEADEND: String = "res://data/structures/tiles/room/room_deadend.tres"
const ROOM_CORNER: String = "res://data/structures/tiles/room/room_corner.tres"
const CORRIDOR_CORNER: String = "res://data/structures/tiles/corner.tres"
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

## Corridor tiles around the 3x3 room, so every connection of the room leads to a placed tile: the room is complete
func _surround_room() -> void:
	var corridor: StructureProfile = load(CORRIDOR)
	for y: int in range(-2, 3):
		for x: int in range(-2, 3):
			if maxi(absi(x), absi(y)) != 2: continue
			_level._structure_spawner.spawn_at(corridor, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(Vector2i(x, y))), 0, Structure.Status.PLACED)

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
	_surround_room()
	var cells: Array[Vector2i] = _spawn_room(Structure.Status.REVEALED)
	await await_idle_frame()
	for cell: Vector2i in cells: assert_int(_dust_count(cell)).override_failure_message("No dust at %s" % cell).is_equal(1)

func test_dust_waits_for_a_room_arriving_over_several_frames() -> void:
	(load(DECORATIONS) as TileDecorations).dusty_room_chance = 1.0
	_surround_room()
	var room: StructureProfile = load(ROOM)
	var cells: Array[Vector2i] = []
	for y: int in range(-1, 2):
		for x: int in range(-1, 2): cells.append(Vector2i(x, y))
	# All but the room's first cell, whose position seeds the roll, as a joining peer may get them
	for cell: Vector2i in cells.slice(1): _level._structure_spawner.spawn_at(room, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell)), 0, Structure.Status.REVEALED)
	for frame: int in 10: await await_idle_frame()
	for cell: Vector2i in cells.slice(1): assert_int(_dust_count(cell)).override_failure_message("Rolled before the room was complete").is_equal(0)
	_level._structure_spawner.spawn_at(room, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cells[0])), 0, Structure.Status.REVEALED)
	for frame: int in 3: await await_idle_frame()
	for cell: Vector2i in cells: assert_int(_dust_count(cell)).override_failure_message("No dust at %s" % cell).is_equal(1)

func test_a_clear_room_has_no_dust() -> void:
	(load(DECORATIONS) as TileDecorations).dusty_room_chance = 0.0
	_surround_room()
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
	# Tiles placed while it shows show their labels
	assert_bool((_level.get_placed_tile(Vector2i.ZERO).get_node(^"Label3D") as Label3D).visible).is_true()
	debug.call("_unhandled_input", toggle)
	assert_bool(debug.shown).is_false()
	for tile: Structure in _level.get_placed_tiles(): assert_bool((tile.get_node(^"Label3D") as Label3D).visible).override_failure_message("Labels hide with the rest").is_false()

func test_a_removed_centrepiece_leaves_its_corner() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.PLACED)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	var corner_things: Dictionary[Vector2i, Thing] = _level.get("_corner_things")
	var thing: Thing = corner_things[Vector2i(0, 1)]
	# As loading a save removes the things
	thing.get_parent().remove_child(thing)
	thing.free()
	assert_bool(corner_things.has(Vector2i(0, 1))).is_false()
	assert_object(_level.get_thing_near(Vector2i(0, 0))).is_null()
	assert_int(_level.get_free_spots(Vector2i(0, 0)).size()).is_equal(5)

func test_each_peer_reveals_a_centrepiece_with_its_own_tiles() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.REVEALED)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	var thing: Thing = (_level.get("_corner_things") as Dictionary)[Vector2i(0, 1)]
	# Spawned unrevealed, it shows as its tiles show here
	assert_int(thing.status).is_equal(Thing.Status.REVEALED)

func test_no_centrepiece_lands_on_a_figure() -> void:
	_level.set("_room_centrepiece_chance", 1.0)
	_spawn_room(Structure.Status.PLACED)
	var knight: CharacterProfile = load(EquipmentFixtures.KNIGHT)
	# On the spot of (-1, 0) towards the corner (0, 1) the centrepiece would take; one on the tile's centre would not keep it out
	var tile: Structure = _level.get_placed_tile(Vector2i(-1, 0))
	var corner_spot: Vector2 = Level.get_spot_towards(tile.profile.get_tile_spots(), Vector2(1, 1))
	var figure: Character = auto_free(knight.create(0, Transform3D(Basis.IDENTITY, _level.get_spot_position(Vector2i(-1, 0), corner_spot))))
	figure.level = _level
	figure.add_to_group(Character.GROUP)
	add_child(figure)
	assert_vector(figure.grid_cell).is_equal(Vector2i(-1, 0))
	assert_vector(figure.tile_spot).is_equal_approx(corner_spot, Vector2.ONE * 0.001)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	assert_bool((_level.get("_corner_things") as Dictionary).is_empty()).is_true()
	figure.remove_from_group(Character.GROUP)
	_level.call("_furnish_room", Vector2i.ZERO)
	await await_idle_frame()
	assert_bool((_level.get("_corner_things") as Dictionary).has(Vector2i(0, 1))).override_failure_message("Furnished once the figure left").is_true()

func test_corner_spots_are_found_whatever_the_spot_directions() -> void:
	var spots: Array[Vector2] = [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(0.4, 0.4), Vector2(-0.4, 0.4)]
	assert_vector(Level.get_spot_towards(spots, Vector2(1, 1))).is_equal(Vector2(0.4, 0.4))
	assert_vector(Level.get_spot_towards([Vector2.ZERO] as Array[Vector2], Vector2(1, 1))).is_equal(Vector2.INF)

func _spawn(profile_path: String, cell: Vector2i, turns: int = 0) -> Structure:
	_level._structure_spawner.spawn_at(load(profile_path) as StructureProfile, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell)), turns, Structure.Status.PLACED)
	return _level.get_placed_tile(cell)

func test_room_tiles_side_by_side_always_connect() -> void:
	# Both open only upwards, so their shapes close the side between them
	var left: Structure = _spawn(ROOM_DEADEND, Vector2i.ZERO)
	_spawn(ROOM_DEADEND, Vector2i.RIGHT)
	assert_array(left.get_openings()).contains_exactly([Level.Direction.UP])
	assert_bool(_level.is_passage(Vector2i.ZERO, Level.Direction.RIGHT)).is_true()
	assert_bool(_level.is_passage(Vector2i.RIGHT, Level.Direction.LEFT)).is_true()
	# A corridor beside a room only connects where both open
	_spawn(CORRIDOR_CORNER, Vector2i.DOWN)
	assert_bool(_level.is_passage(Vector2i.ZERO, Level.Direction.DOWN)).is_false()
	assert_array(_level.get_room_cells(Vector2i.ZERO)).contains_exactly_in_any_order([Vector2i.ZERO, Vector2i.RIGHT])

func test_turning_a_room_tile_turns_its_exits_only() -> void:
	var corner: Structure = _spawn(ROOM_CORNER, Vector2i.ZERO)
	_spawn(ROOM_DEADEND, Vector2i.RIGHT)
	assert_array(corner.get_openings()).contains_exactly_in_any_order([Level.Direction.UP, Level.Direction.RIGHT])
	_level.rotate_tile(corner, 1, null)
	assert_array(corner.get_openings()).contains_exactly_in_any_order([Level.Direction.RIGHT, Level.Direction.DOWN])
	# Turning builds the dungeon around it, which may add room tiles beside it: those connect too
	assert_array(corner.get_connections()).contains([Level.Direction.RIGHT, Level.Direction.DOWN])
	_level.rotate_tile(corner, 1, null)
	# Its exits face down and left now; the side to its room stays open
	assert_array(corner.get_openings()).contains_exactly_in_any_order([Level.Direction.DOWN, Level.Direction.LEFT])
	assert_array(corner.get_connections()).contains([Level.Direction.RIGHT, Level.Direction.DOWN, Level.Direction.LEFT])
	assert_bool(_level.is_passage(Vector2i.ZERO, Level.Direction.RIGHT)).is_true()

func test_a_room_tile_fits_beside_its_room_whatever_its_shape() -> void:
	# Closed towards (1, 0)
	var placed: Array[Structure] = [_spawn(ROOM_DEADEND, Vector2i.ZERO)]
	# Turned twice, a corner opens down and left: towards the placed tile, which does not open back
	var room_corner: DungeonTileSet.TileBlueprint = DungeonTileSet.TileBlueprint.new(load(ROOM_CORNER) as StructureProfile, 2)
	var corridor_corner: DungeonTileSet.TileBlueprint = DungeonTileSet.TileBlueprint.new(load(CORRIDOR_CORNER) as StructureProfile, 2)
	var neighbours: Array[DungeonTileSet.Neighbour] = DungeonTileSet.get_neighbours(Vector2i.RIGHT, placed)
	assert_bool(room_corner.fits(neighbours)).is_true()
	assert_bool(corridor_corner.fits(neighbours)).is_false()

func test_a_turned_room_tile_leaves_its_pillars_on_their_corners() -> void:
	_surround_room()
	_spawn_room(Structure.Status.REVEALED)
	# The props drop in after the reveal
	await await_millis(3000)
	var holder: Structure = null
	var pillar: Node3D = null
	for tile: Structure in _level.get_placed_tiles():
		if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			if prop.has_meta(TileDecorations.CORNER):
				holder = tile
				pillar = prop as Node3D
	assert_object(pillar).override_failure_message("The room should have a pillar").is_not_null()
	var standing: Vector2 = Vector2(pillar.global_position.x, pillar.global_position.z)
	# The turn builds the dungeon on along its new passages, which the outer wall bounds, as in a game
	_level.call("_build_outer_wall")
	_level.rotate_tile(holder, 1, null)
	await await_millis(2000)
	assert_float(Vector2(pillar.global_position.x, pillar.global_position.z).distance_to(standing)).is_less(0.01)
