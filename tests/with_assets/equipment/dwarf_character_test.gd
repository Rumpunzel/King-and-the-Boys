extends GdUnitTestSuite
## The dwarf: its own model with its own parts, dressed only by dwarf gear

var _dwarf: DwarfCharacter
var _equipment: CharacterEquipment

func before_test() -> void:
	_dwarf = auto_free(EquipmentFixtures.make_dwarf_model())
	add_child(_dwarf)
	_equipment = auto_free(CharacterEquipment.new())
	_equipment.apply_to(_dwarf)

func _catalog_look(type_name: String, combination_key: String) -> EquipmentLook:
	return EquipmentCatalog.find_for(EquipmentFixtures.load_type(type_name)).get_look(combination_key)

func test_every_part_has_meshes_in_number_order() -> void:
	for part: int in _dwarf.get_part_keys().size():
		var body_part: ModularBodyPart = _dwarf.get_part(part)
		assert_int(body_part.get_mesh_count()).override_failure_message("%s has no meshes" % _dwarf.get_part_keys()[part]).is_greater(0)
	assert_array(_dwarf.body.get_mesh_numbers()).contains_exactly(["01", "02", "03", "04", "05", "06", "07"])

func test_only_hair_and_beard_are_rolled_per_character() -> void:
	assert_array(_dwarf.get_body_parts()).contains_exactly([DwarfCharacter.Part.HAIR, DwarfCharacter.Part.BEARD, DwarfCharacter.Part.BEARD_ATTACHMENT])
	var body: Dictionary = (load("res://data/characters/dwarves/random_dwarf.tres") as ModelConfigurationRandom).roll(_dwarf)
	assert_array(body.keys()).contains_exactly(_dwarf.get_body_parts())

func test_a_human_body_configuration_skips_parts_dwarves_lack() -> void:
	var body: Dictionary = (load("res://data/characters/people/random_human.tres") as ModelConfigurationRandom).roll(_dwarf)
	# HAIR is shared and rolled; HEAD and EYEBROW do not exist on a dwarf
	assert_array(body.keys()).contains_exactly(_dwarf.get_body_parts())

func test_the_outfit_swaps_body_and_shoulders() -> void:
	assert_bool(_equipment.equip(_catalog_look("dwarf_outfit", "07 02"))).is_true()
	assert_str(EquipmentFixtures.mesh_path(_dwarf.body)).ends_with("dwarf_body_king_07.res")
	assert_str(EquipmentFixtures.mesh_path(_dwarf.shoulder_left)).ends_with("dwarf_shoulder_left_king_02.res")
	assert_str(EquipmentFixtures.mesh_path(_dwarf.shoulder_right)).ends_with("dwarf_shoulder_right_king_02.res")
	_equipment.unequip(EquipmentLook.Slot.TORSO)
	assert_str(EquipmentFixtures.mesh_path(_dwarf.body)).override_failure_message("The body is essential and falls back to the first").ends_with("_01.res")
	assert_str(EquipmentFixtures.mesh_path(_dwarf.shoulder_left)).is_empty()

func test_right_shoulder_pads_mirror_the_left() -> void:
	# The pads are modelled in their bones' original space; the right ones are the left ones mirrored
	var mirror: Transform3D = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
	assert_bool(_dwarf.shoulder_right.transform.is_equal_approx(mirror * _dwarf.shoulder_left.transform * mirror)).is_true()
	assert_bool(_dwarf.shoulder_left.transform.basis.is_equal_approx(Basis.IDENTITY)).override_failure_message("The left pad needs its bone offset").is_false()

func test_helmets_hide_the_hair() -> void:
	_dwarf.hair.update_index(0)
	assert_bool(_dwarf.hair.visible).is_true()
	_equipment.equip(_catalog_look("dwarf_headwear", "08"))
	assert_bool(_dwarf.hair.visible).is_false()
	_equipment.unequip(EquipmentLook.Slot.HEAD)
	assert_bool(_dwarf.hair.visible).is_true()

func test_gear_only_fits_its_own_body() -> void:
	var helmet: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT)
	assert_bool(_equipment.can_equip(helmet)).is_false()
	assert_bool(_equipment.equip(helmet)).is_false()
	var human: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	var human_equipment: CharacterEquipment = auto_free(CharacterEquipment.new())
	human_equipment.apply_to(human)
	assert_bool(human_equipment.equip(_catalog_look("dwarf_headwear", "08"))).is_false()
	assert_bool(human_equipment.equip(helmet)).is_true()

func test_dwarf_parts_name_their_carousels() -> void:
	var outfit: EquipmentLook = EquipmentSlotProperty.get_first_look(EquipmentFixtures.load_type("dwarf_outfit"))
	var carousels: Array[Array] = EquipmentSlotProperty.get_carousel_parts(outfit, {})
	assert_int(carousels.size()).override_failure_message("Body plus one carousel for both shoulders").is_equal(2)
	assert_str(EquipmentSlotProperty.describe_carousel(outfit, carousels[1])).is_equal("Shoulder 00")
	var stepped: EquipmentLook = EquipmentSlotProperty.step_parts(outfit, carousels[0], 1)
	assert_str(EquipmentSlotProperty.describe_carousel(stepped, carousels[0])).is_equal("Body 02")

func test_the_dwarf_profile_spawns_a_dressed_dwarf() -> void:
	var profile: CharacterProfile = load(EquipmentFixtures.DWARF)
	var data: Dictionary[StringName, Variant] = profile.create_character_data(0, Transform3D())
	var character: Character = auto_free(Character.from_character_data(data))
	assert_object(character.model).is_instanceof(DwarfCharacter)
	var model: DwarfCharacter = character.model
	assert_str(EquipmentFixtures.mesh_path(model.body)).ends_with("dwarf_body_soldier_male_03.res")
	assert_str(EquipmentFixtures.mesh_path(model.headwear)).ends_with("dwarf_headwear_helmet_soldier_08.res")
	assert_array((data[Character.BODY] as Dictionary).keys()).contains_exactly(model.get_body_parts())
