extends GdUnitTestSuite
## Peers may only request equipment ids inside the item directory (general ResourceId tests: tests/unit/client/)

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func test_only_ids_inside_the_item_directory_are_requestable() -> void:
	var saved: EquipmentLook = EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("cape"), ModularCharacter.Part.BACK_ATTACHMENT, EquipmentFixtures.CAPE), "cape.tres")
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(saved))).is_true()
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(EquipmentFixtures.load_type("cape")))).is_true()
	assert_bool(CharacterEquipment.is_requestable(ResourceId.of(load(EquipmentFixtures.KNIGHT) as Resource))).is_false()
	assert_bool(CharacterEquipment.is_requestable(EquipmentFixtures.SAVED_ITEMS + "/../../characters/people/knight.tres")).is_false()
	assert_bool(CharacterEquipment.is_requestable("uid://doesnotexist")).is_false()
