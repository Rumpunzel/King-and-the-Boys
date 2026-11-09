extends GdUnitTestSuite
## The starting equipment fields' helpers; the EditorProperty itself cannot be made headless

var _knight: CharacterProfile
var _original_starting_equipment: Dictionary

func before_test() -> void:
	_knight = load(EquipmentFixtures.KNIGHT)
	_original_starting_equipment = EquipmentFixtures.clear_starting_equipment(_knight)

func after_test() -> void:
	EquipmentFixtures.restore_starting_equipment(_knight, _original_starting_equipment)

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func _catalog(type_name: String) -> EquipmentCatalog:
	return EquipmentCatalog.find_for(EquipmentFixtures.load_type(type_name))

func test_slots_offer_only_their_types() -> void:
	var head_types: Array = EquipmentSlotProperty.get_slot_types(EquipmentLook.Slot.HEAD).map(func(equipment_type: EquipmentType) -> String: return equipment_type.name)
	assert_array(head_types).contains_exactly_in_any_order(["Helmet", "Hood", "Hat"])
	assert_array(EquipmentSlotProperty.get_slot_types(EquipmentLook.Slot.MAIN_HAND)).is_empty()

func test_choosing_a_type_starts_at_its_first_allowed_look() -> void:
	var catalog: EquipmentCatalog = _catalog("chest_armor")
	var first: EquipmentLook = EquipmentSlotProperty.get_first_look(catalog.type)
	assert_object(first).is_same(catalog.get_look(catalog.get_first_key()))
	assert_bool(first.allowed).is_true()

func test_stepping_an_attachment_keeps_the_base() -> void:
	var catalog: EquipmentCatalog = _catalog("helmet")
	var start: EquipmentLook = EquipmentSlotProperty.get_first_look(catalog.type)
	var stepped: EquipmentLook = EquipmentSlotProperty.step_look(start, 1, 1)
	assert_object(stepped).is_same(catalog.get_look(catalog.step(EquipmentCatalog.get_key_of(start), 1, 1)))
	assert_str(EquipmentSlotProperty.describe_link(stepped, 0)).is_equal(EquipmentSlotProperty.describe_link(start, 0))
	assert_object(EquipmentSlotProperty.step_look(stepped, 1, -1)).is_same(start)

func test_carousels_name_the_part_and_its_number() -> void:
	var catalog: EquipmentCatalog = _catalog("helmet")
	var look: EquipmentLook = catalog.get_look(catalog.get_first_key())
	var numbers: PackedStringArray = EquipmentCatalog.get_key_of(look).split(" ")
	assert_str(EquipmentSlotProperty.describe_link(look, 0)).is_equal("Head No Elements %s" % numbers[0])
	assert_str(EquipmentSlotProperty.describe_link(look, 1)).is_equal("Helmet Attachment %s" % numbers[1])
	var gloves: EquipmentLook = EquipmentSlotProperty.get_first_look(EquipmentFixtures.load_type("gloves"))
	assert_str(EquipmentSlotProperty.describe_link(gloves, 1)).starts_with("Elbow Attach ")

func test_hand_made_looks_step_into_the_catalog() -> void:
	var helmet: EquipmentLook = EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT), "helmet.tres")
	assert_str(EquipmentSlotProperty.get_key(helmet)).is_equal(helmet.type.get_combination_key_of(helmet))
	var stepped: EquipmentLook = EquipmentSlotProperty.step_look(helmet, 1, 1)
	assert_bool(_catalog("helmet").looks.has(stepped)).is_true()

func test_a_blocking_look_names_itself_as_the_blocker() -> void:
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.FACE)).is_null()
	var helmet: EquipmentLook = EquipmentSlotProperty.get_first_look(EquipmentFixtures.load_type("helmet"))
	_knight.set_starting_equipment_for(EquipmentLook.Slot.HEAD, helmet)
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.FACE)).is_same(helmet)
	assert_object(EquipmentSlotProperty.get_blocker(_knight, EquipmentLook.Slot.TORSO)).is_null()
