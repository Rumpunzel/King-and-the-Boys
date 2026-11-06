extends GdUnitTestSuite

const SAVED_CATALOG: String = EquipmentFixtures.SAVED_ITEMS + "/catalog.tres"

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func _catalog() -> EquipmentCatalog:
	var catalog: EquipmentCatalog = EquipmentCatalog.new()
	catalog.type = EquipmentFixtures.load_type("helmet")
	return catalog

func _helmet(catalog: EquipmentCatalog) -> EquipmentLook:
	var helmet: EquipmentLook = EquipmentFixtures.make_item(catalog.type, ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	helmet.name = ""
	return helmet

func test_adding_stores_a_look_under_its_key_with_its_flag() -> void:
	var catalog: EquipmentCatalog = _catalog()
	var helmet: EquipmentLook = _helmet(catalog)
	catalog.add(helmet, "00 02", false)
	assert_object(catalog.get_look("00 02")).is_same(helmet)
	assert_str(helmet.resource_scene_unique_id).is_equal("00_02")
	assert_str(helmet.name).is_equal("Helmet 00 02")
	assert_bool(helmet.allowed).is_false()
	assert_array(catalog.get_allowed_looks()).is_empty()
	helmet.allowed = true
	assert_array(catalog.get_allowed_looks()).contains_exactly([helmet])

func test_adding_a_key_again_replaces_the_look() -> void:
	var catalog: EquipmentCatalog = _catalog()
	catalog.add(_helmet(catalog), "05 10", true)
	var replacement: EquipmentLook = _helmet(catalog)
	catalog.add(replacement, "05 10", false)
	assert_int(catalog.looks.size()).is_equal(1)
	assert_object(catalog.get_look("05 10")).is_same(replacement)

func test_hand_made_looks_are_allowed_by_default() -> void:
	assert_bool(EquipmentLook.new().allowed).is_true()

func test_look_ids_only_use_characters_godot_keeps() -> void:
	assert_str(EquipmentCatalog.get_look_id("21-00 00")).is_equal("21x00_00")
	assert_str(EquipmentCatalog.get_look_id("05 10")).is_equal("05_10")

func test_missing_combinations_are_added_unchecked() -> void:
	var catalog: EquipmentCatalog = _catalog()
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	var combinations: EquipmentCombinations = EquipmentCombinations.new(catalog.type, model)
	combinations.varied_parts = [ModularCharacter.Part.HELMET_ATTACHMENT]
	catalog.add(_helmet(catalog), "00 02", true)
	var added: int = catalog.add_missing(combinations)
	assert_int(added).is_equal(combinations.list().size() - 1)
	assert_bool(catalog.get_look("00 02").allowed).is_true()
	assert_bool(catalog.get_look("00 03").allowed).is_false()
	assert_int(catalog.add_missing(combinations)).is_equal(0)

func test_saved_looks_are_found_again_by_resource_id() -> void:
	var catalog: EquipmentCatalog = _catalog()
	catalog.add(_helmet(catalog), "21-00 00", false)
	DirAccess.make_dir_recursive_absolute(EquipmentFixtures.SAVED_ITEMS)
	assert_int(ResourceSaver.save(catalog, SAVED_CATALOG)).is_equal(OK)
	var loaded: EquipmentCatalog = ResourceLoader.load(SAVED_CATALOG, "", ResourceLoader.CACHE_MODE_REPLACE)
	var look: EquipmentLook = loaded.get_look("21-00 00")
	assert_object(look).is_not_null()
	assert_bool(look.allowed).is_false()
	var look_id: String = ResourceId.of(look)
	assert_str(look_id).ends_with("::21x00_00")
	assert_object(ResourceId.find(look_id)).is_same(look)
	assert_bool(CharacterEquipment.is_requestable(look_id)).is_true()

func test_catalog_warns_about_looks_of_other_types() -> void:
	var catalog: EquipmentCatalog = _catalog()
	var cape: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE)
	catalog.looks = [cape]
	assert_int(catalog._get_configuration_warnings().size()).is_equal(1)

func test_committed_catalogs_resolve_every_look() -> void:
	var catalogs: Array[EquipmentCatalog] = EquipmentCatalog.find_all()
	assert_array(catalogs).is_not_empty()
	for catalog: EquipmentCatalog in catalogs:
		assert_array(catalog._get_configuration_warnings()).override_failure_message("%s warns" % catalog.resource_path).is_empty()
		assert_str(ResourceId.of(catalog)).override_failure_message("%s has no UID" % catalog.resource_path).starts_with("uid://")
		assert_object(EquipmentCatalog.find_for(catalog.type)).is_same(catalog)
		for look: EquipmentLook in catalog.looks:
			var key: String = catalog.type.get_combination_key_of(look)
			assert_str(look.resource_scene_unique_id).override_failure_message("%s is stored under the wrong ID" % look.name).is_equal(EquipmentCatalog.get_look_id(key))
			assert_object(ResourceId.find(ResourceId.of(look))).is_same(look)
