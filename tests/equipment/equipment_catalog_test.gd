extends GdUnitTestSuite

const SAVED_CATALOG: String = EquipmentFixtures.SAVED_ITEMS + "/catalog.tres"

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func _catalog() -> EquipmentCatalog:
	var catalog: EquipmentCatalog = EquipmentCatalog.new()
	catalog.type = EquipmentFixtures.load_type("helmet")
	return catalog

func _helmet(catalog: EquipmentCatalog) -> EquipmentProfile:
	var helmet: EquipmentProfile = EquipmentFixtures.make_item(catalog.type, ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	helmet.name = ""
	return helmet

func test_combinations_start_unreviewed() -> void:
	assert_int(_catalog().get_status("05 10")).is_equal(EquipmentCatalog.Status.UNREVIEWED)

func test_allowing_stores_the_item_under_its_key() -> void:
	var catalog: EquipmentCatalog = _catalog()
	var helmet: EquipmentProfile = _helmet(catalog)
	catalog.allow(helmet, "none 02")
	assert_int(catalog.get_status("none 02")).is_equal(EquipmentCatalog.Status.ALLOWED)
	assert_object(catalog.get_entry("none 02")).is_same(helmet)
	assert_str(helmet.resource_scene_unique_id).is_equal("none_02")
	assert_str(helmet.name).is_equal("Helmet none 02")

func test_deny_and_undecide_document_and_reset_decisions() -> void:
	var catalog: EquipmentCatalog = _catalog()
	catalog.allow(_helmet(catalog), "05 10")
	catalog.deny("05 10")
	assert_int(catalog.get_status("05 10")).is_equal(EquipmentCatalog.Status.DENIED)
	assert_object(catalog.get_entry("05 10")).is_null()
	catalog.deny("05 10")
	assert_array(catalog.denied).contains_exactly(["05 10"])
	catalog.allow(_helmet(catalog), "05 10")
	assert_array(catalog.denied).is_empty()
	catalog.undecide("05 10")
	assert_int(catalog.get_status("05 10")).is_equal(EquipmentCatalog.Status.UNREVIEWED)

func test_entry_ids_only_use_characters_godot_keeps() -> void:
	assert_str(EquipmentCatalog.get_entry_id("21-00 none")).is_equal("21x00_none")
	assert_str(EquipmentCatalog.get_entry_id("05 10")).is_equal("05_10")

func test_saved_entries_are_found_again_by_resource_id() -> void:
	var catalog: EquipmentCatalog = _catalog()
	catalog.allow(_helmet(catalog), "21-00 none")
	DirAccess.make_dir_recursive_absolute(EquipmentFixtures.SAVED_ITEMS)
	assert_int(ResourceSaver.save(catalog, SAVED_CATALOG)).is_equal(OK)
	var loaded: EquipmentCatalog = ResourceLoader.load(SAVED_CATALOG, "", ResourceLoader.CACHE_MODE_REPLACE)
	var entry: EquipmentProfile = loaded.get_entry("21-00 none")
	assert_object(entry).is_not_null()
	var entry_id: String = ResourceId.of(entry)
	assert_str(entry_id).ends_with("::21x00_none")
	assert_object(ResourceId.find(entry_id)).is_same(entry)
	assert_bool(CharacterEquipment.is_requestable(entry_id)).is_true()

func test_catalog_warns_about_entries_of_other_types() -> void:
	var catalog: EquipmentCatalog = _catalog()
	var cape: EquipmentProfile = EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE)
	catalog.entries = [cape]
	assert_int(catalog._get_configuration_warnings().size()).is_equal(1)

func test_committed_catalogs_resolve_every_entry() -> void:
	var catalogs: Array[EquipmentCatalog] = EquipmentCatalog.find_all()
	assert_array(catalogs).is_not_empty()
	for catalog: EquipmentCatalog in catalogs:
		assert_array(catalog._get_configuration_warnings()).override_failure_message("%s warns" % catalog.resource_path).is_empty()
		assert_str(ResourceId.of(catalog)).override_failure_message("%s has no UID" % catalog.resource_path).starts_with("uid://")
		assert_object(EquipmentCatalog.find_for(catalog.type)).is_same(catalog)
		for entry: EquipmentProfile in catalog.entries:
			var key: String = catalog.type.get_combination_key_of(entry)
			assert_str(entry.resource_scene_unique_id).override_failure_message("%s is stored under the wrong ID" % entry.name).is_equal(EquipmentCatalog.get_entry_id(key))
			assert_object(ResourceId.find(ResourceId.of(entry))).is_same(entry)
