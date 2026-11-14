extends GdUnitTestSuite
## Sarcophagi and thrones stand in the middle of some rooms (see room_test.gd), as things like the chests, so they can be interacted with later

const CENTREPIECES: Array[String] = ["uid://4gxlas34qp2u", "uid://c42mc4ie0lctr"]  # data/things/centrepieces/sarcophagus.tres, data/things/centrepieces/dwarf_throne.tres

func test_centrepieces_are_things_with_a_textured_model() -> void:
	for path: String in CENTREPIECES:
		var thing: Thing = (load(path) as ThingProfile).create(0, Transform3D.IDENTITY, Thing.Status.REVEALED)
		add_child(thing)
		var meshes: Array[MeshInstance3D] = Model.gather_all_geometry_instances_on(thing.model)
		assert_array(meshes).is_not_empty()
		# The Dungeon Realms imports carry the pack's atlas as their surface material
		for mesh_instance: MeshInstance3D in meshes:
			for surface: int in mesh_instance.mesh.get_surface_count():
				assert_object(mesh_instance.mesh.surface_get_material(surface)).is_same(load("uid://dojugi1n63fxu"))  # data/structures/props/dungeon_realms_material.tres
		thing.queue_free()
