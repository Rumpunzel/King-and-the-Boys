extends GdUnitTestSuite
## The dungeon tiles' props: the same on every peer, along closed sides only and clear of the tile spots

const DECORATIONS: String = "res://data/structures/tiles/dungeon_decorations.tres"
const TILE_SIZE: float = 2.0

func _props(connections: Array[Level.Direction], grid_position: Vector2i) -> Array[Node3D]:
	var decorations: Node3D = auto_free((load(DECORATIONS) as TileDecorations).create_clutter(connections, grid_position, TILE_SIZE))
	var props: Array[Node3D] = []
	for child: Node in decorations.get_children(): props.append(child as Node3D)
	return props

func _describe(props: Array[Node3D]) -> PackedStringArray:
	var described: PackedStringArray = []
	for prop: Node3D in props: described.append("%s %s %.2f" % [prop.get_child(0).scene_file_path, prop.position, (prop.get_child(0) as Node3D).rotation.y])
	return described

func test_a_tile_gets_the_same_props_on_every_peer() -> void:
	var closed: Array[Level.Direction] = []
	assert_array(_describe(_props(closed, Vector2i(3, -2)))).is_equal(_describe(_props(closed, Vector2i(3, -2))))
	assert_array(_describe(_props(closed, Vector2i(3, -2)))).is_not_equal(_describe(_props(closed, Vector2i(-5, 7))))

func test_open_tiles_stay_empty() -> void:
	var open: Array[Level.Direction] = [Level.Direction.UP, Level.Direction.RIGHT, Level.Direction.DOWN, Level.Direction.LEFT]
	for x: int in 10: assert_array(_props(open, Vector2i(x, 0))).is_empty()

func test_props_keep_to_closed_sides_and_clear_of_tile_spots() -> void:
	var hallway: Array[Level.Direction] = [Level.Direction.UP, Level.Direction.DOWN]
	var spots: Array[Vector2] = (load("res://data/structures/tiles/hallway.tres") as StructureProfile).get_tile_spots()
	var placed: int = 0
	for x: int in 20:
		for prop: Node3D in _props(hallway, Vector2i(x, 1)):
			placed += 1
			# Up and down are open, so props stand on the left or right side
			assert_float(absf(prop.position.x)).is_greater(0.6)
			assert_bool(prop.find_children("*", "CollisionObject3D", true, false).is_empty()).is_true()
			for spot: Vector2 in spots: assert_float(Vector2(prop.position.x, prop.position.z).distance_to(spot)).is_greater(0.25)
	assert_int(placed).is_greater(0)

func test_props_drop_in_one_after_another() -> void:
	var decorations_resource: TileDecorations = load(DECORATIONS)
	var closed: Array[Level.Direction] = []
	var decorations: Node3D = auto_free(decorations_resource.create_clutter(closed, Vector2i(2, 2), TILE_SIZE))
	add_child(decorations)
	var props: Array[Node] = decorations.get_children()
	assert_int(props.size()).is_greater(1)
	for prop: Node in props: assert_object(prop).is_instanceof(Model)
	decorations_resource.drop(decorations)
	# Hidden until their turn comes
	for prop: Node in props: assert_bool((prop as Node3D).visible).is_false()
	await await_millis(int(decorations_resource.drop_interval * 1000.0 * props.size()) + 200)
	for prop: Node in props: assert_bool((prop as Node3D).visible).is_true()

func test_a_light_stands_in_the_middle_of_a_closed_side() -> void:
	var decorations_resource: TileDecorations = load(DECORATIONS)
	var light_chance: float = decorations_resource.light_chance
	decorations_resource.light_chance = 1.0
	var hallway: Array[Level.Direction] = [Level.Direction.UP, Level.Direction.DOWN]
	var light_scenes: Array[String] = _scenes_of(decorations_resource.lights)
	for x: int in 10:
		var lights: Array[Node3D] = _props(hallway, Vector2i(x, 3)).filter(func(prop: Node3D) -> bool: return light_scenes.has(prop.get_child(0).scene_file_path))
		assert_int(lights.size()).is_equal(1)
		# Up and down are open, so the light stands left or right, in the middle
		assert_float(absf(lights[0].position.x)).is_equal_approx(decorations_resource.edge_distance * TILE_SIZE * 0.5, 0.01)
		assert_float(lights[0].position.z).is_equal_approx(0.0, 0.01)
	decorations_resource.light_chance = light_chance

## The paths of every prop scene in [param prop_set] and its collections
static func _scenes_of(prop_set: PropSet) -> Array[String]:
	var scenes: Array[String] = []
	for scene: PackedScene in prop_set.props: scenes.append(scene.resource_path)
	for collection: PropSet in prop_set.collections: scenes.append_array(_scenes_of(collection))
	return scenes
