extends GdUnitTestSuite
## Sarcophagi and thrones stand in the middle of some room tiles, as things like the chests, so they can be interacted with later

const CENTREPIECES: Array[String] = ["res://data/things/centrepieces/sarcophagus.tres", "res://data/things/centrepieces/dwarf_throne.tres"]
const ROOM_TILES: Array[String] = ["res://data/structures/tiles/room/room_center.tres", "res://data/structures/tiles/room/room_crossing.tres"]

func test_centrepieces_are_things_with_a_textured_model() -> void:
	for path: String in CENTREPIECES:
		var thing: Thing = (load(path) as ThingProfile).create(0, Transform3D.IDENTITY, Thing.Status.REVEALED)
		add_child(thing)
		var meshes: Array[MeshInstance3D] = Model.gather_all_geometry_instances_on(thing.model)
		assert_array(meshes).is_not_empty()
		# The Dungeon Realms imports carry the pack's atlas as their surface material
		for mesh_instance: MeshInstance3D in meshes:
			for surface: int in mesh_instance.mesh.get_surface_count():
				assert_object(mesh_instance.mesh.surface_get_material(surface)).is_same(load("res://data/structures/props/dungeon_realms_material.tres"))
		thing.queue_free()

func test_room_tiles_roll_centrepieces_now_and_then() -> void:
	var names: Array = CENTREPIECES.map(func(path: String) -> String: return (load(path) as ThingProfile).name)
	for tile_path: String in ROOM_TILES:
		var tile: StructureProfile = load(tile_path)
		var rolled: Dictionary[String, int] = {}
		for roll: int in 2000:
			var spawn: Profile = tile.get_spawn()
			if spawn: rolled[spawn.name] = rolled.get(spawn.name, 0) + 1
		for centrepiece_name: String in names: assert_int(rolled.get(centrepiece_name, 0)).is_greater(0)
		assert_int(rolled.values().reduce(func(sum: int, count: int) -> int: return sum + count, 0)).is_less(1000)
