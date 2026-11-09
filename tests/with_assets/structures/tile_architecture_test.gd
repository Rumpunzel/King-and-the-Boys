extends GdUnitTestSuite
## Arches and pillars on the real dungeon: each opening and corner is shared, so it must be dressed exactly once

const LEVEL: String = "res://data/levels/level.tscn"
const DOORWAY_ARCHES: String = "res://data/structures/props/dungeon_doorway_arches.tres"
const ROOM_PILLARS: String = "res://data/structures/props/dungeon_room_pillars.tres"

var _level: Level

func before_test() -> void:
	seed(4321)
	_level = auto_free((load(LEVEL) as PackedScene).instantiate())
	add_child(_level)
	_level.build_level()
	# Reveal the start's surroundings in rings, like exploring would
	for ring: int in 4:
		for tile: Structure in _tiles_within(ring): tile.status = Structure.Status.REVEALED

func _tiles_within(radius: int) -> Array[Structure]:
	var tiles: Array[Structure] = []
	for x: int in range(-radius, radius + 1):
		for y: int in range(-radius, radius + 1):
			var tile: Structure = _level.get_placed_tile(Vector2i(x, y))
			if tile and tile.profile.decorations: tiles.append(tile)
	return tiles

## Every decoration prop from [param prop_set_path], by its position on the level's floor
func _props_of(prop_set_path: String) -> Array[Vector2]:
	var scenes: Array = (load(prop_set_path) as PropSet).props.keys().map(func(scene: PackedScene) -> String: return scene.resource_path)
	var found: Array[Vector2] = []
	for tile: Structure in _tiles_within(4):
		if not tile.model or not tile.model.has_node(NodePath(TileDecorations.NODE_NAME)): continue
		for prop: Node in tile.model.get_node(NodePath(TileDecorations.NODE_NAME)).get_children():
			var mesh: Node3D = prop.get_child(0)
			if scenes.has(mesh.scene_file_path): found.append(Vector2((prop as Node3D).global_position.x, (prop as Node3D).global_position.z))
	return found

func _count_near(spots: Array[Vector2], spot: Vector2) -> int:
	return spots.filter(func(other: Vector2) -> bool: return other.distance_to(spot) < 0.3).size()

func test_each_doorway_gets_one_arch() -> void:
	var arches: Array[Vector2] = _props_of(DOORWAY_ARCHES)
	var doorways: int = 0
	for tile: Structure in _tiles_within(3):
		if tile.shown_status != Structure.Status.REVEALED: continue
		for direction: Level.Direction in tile.get_connections():
			var neighbour: Structure = _level.get_placed_tile(tile.get_grid_position() + Level.DIRECTION_VECTORS[direction])
			if not neighbour or neighbour.shown_status != Structure.Status.REVEALED: continue
			if (tile.profile.room_type != null) == (neighbour.profile.room_type != null): continue
			doorways += 1
			var opening: Vector3 = (tile.global_position + neighbour.global_position) * 0.5
			assert_int(_count_near(arches, Vector2(opening.x, opening.z))).override_failure_message("Doorway at %s" % opening).is_equal(1)
	assert_int(doorways).override_failure_message("The start should lie in a room with doorways").is_greater(0)

func test_pillars_stand_once_on_even_corners_inside_rooms() -> void:
	var pillars: Array[Vector2] = _props_of(ROOM_PILLARS)
	for pillar: Vector2 in pillars:
		assert_int(_count_near(pillars, pillar)).is_equal(1)
		var corner_index: Vector2 = pillar / _level.grid_size + Vector2.ONE * 0.5
		assert_vector(corner_index.round()).is_equal_approx(corner_index, Vector2.ONE * 0.01)
		assert_int(posmod(roundi(corner_index.x), 2) + posmod(roundi(corner_index.y), 2)).is_equal(0)
		for corner: Vector2i in TileDecorations.CORNERS:
			var cell: Structure = _level.get_placed_tile(Vector2i(corner_index.round()) - corner)
			assert_object(cell).is_not_null()
			assert_object(cell.profile.room_type).override_failure_message("Pillar at %s is not inside a room" % pillar).is_not_null()

func test_no_pillar_stands_beside_a_doorway_arch() -> void:
	var pillars: Array[Vector2] = _props_of(ROOM_PILLARS)
	for arch: Vector2 in _props_of(DOORWAY_ARCHES):
		for pillar: Vector2 in pillars: assert_float(pillar.distance_to(arch)).is_greater(0.9)
