extends GdUnitTestSuite

var _model: ModularCharacter

func before_test() -> void:
	_model = auto_free(EquipmentFixtures.make_model())

func test_get_part_covers_every_part() -> void:
	for part: ModularCharacter.Part in ModularCharacter.Part.values():
		assert_object(_model.get_part(part)).override_failure_message("No body part for %s" % ModularCharacter.Part.keys()[part]).is_not_null()

func test_decorative_parts_may_be_empty_essential_parts_not() -> void:
	assert_bool(_model.helmet_attachment.allows_none()).is_true()
	assert_bool(_model.torso.allows_none()).is_false()
	assert_int(_model.helmet_attachment.get_mesh_index()).is_equal(-1)

func test_mesh_index_reads_back_stepped_and_exact_meshes() -> void:
	var helmet: ModularBodyPart = _model.helmet_attachment
	helmet.update_index(2)
	assert_int(helmet.get_mesh_index()).is_equal(2)
	helmet.apply_mesh(load(EquipmentFixtures.HELMET_ATTACHMENT) as ArrayMesh)
	assert_str(EquipmentFixtures.mesh_path(helmet)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
	assert_int(helmet.get_mesh_index()).is_greater_equal(0)
	helmet.update_index(-1)
	assert_bool(helmet.visible).is_false()

func test_meshes_are_found_by_file_number() -> void:
	assert_str(ModularBodyPart.get_mesh_number(EquipmentFixtures.TORSO_MALE)).is_equal("03")
	var torso: ModularBodyPart = _model.torso
	torso.update_index(torso.find_mesh_index("03"))
	assert_str(EquipmentFixtures.mesh_path(torso)).is_equal(EquipmentFixtures.TORSO_MALE)
	assert_int(torso.find_mesh_index("999")).is_equal(-1)

func test_apply_mesh_hides_and_shows_related_parts() -> void:
	_model.head_coverings_no_hair.apply_mesh(load(EquipmentFixtures.HOOD) as ArrayMesh)
	assert_bool(_model.hair.visible).is_false()
	_model.head_coverings_no_hair.apply_mesh(null)
	assert_bool(_model.hair.visible).is_true()

func test_capture_takes_only_the_types_visible_parts() -> void:
	_model.head_coverings_no_hair.update_index(1)
	_model.helmet_attachment.update_index(2)
	var captured: EquipmentLook = EquipmentLook.from_model(_model, EquipmentFixtures.load_type("hat"))
	assert_array(captured.appearance.get_parts()).contains_exactly([ModularCharacter.Part.HELMET_ATTACHMENT])

func test_capture_finds_the_other_gender_mesh() -> void:
	_model.torso.update_index(_model.torso.find_mesh_index("03"))
	var captured: EquipmentLook = EquipmentLook.from_model(_model, EquipmentFixtures.load_type("chest_armor"))
	var torso_mesh: EquipmentPartMesh
	for part_mesh: EquipmentPartMesh in captured.appearance.parts:
		if part_mesh.part == ModularCharacter.Part.TORSO: torso_mesh = part_mesh
	assert_str(torso_mesh.male_mesh.resource_path).is_equal(EquipmentFixtures.TORSO_MALE)
	assert_str(torso_mesh.female_mesh.resource_path).is_equal(EquipmentFixtures.TORSO_FEMALE)

func test_item_mesh_follows_body_part_gender() -> void:
	var chest: EquipmentLook = EquipmentFixtures.make_item(EquipmentFixtures.load_type("chest_armor"), ModularCharacter.Part.TORSO, EquipmentFixtures.TORSO_MALE, EquipmentFixtures.TORSO_FEMALE)
	chest.appearance.configure(_model)
	assert_str(EquipmentFixtures.mesh_path(_model.torso)).is_equal(EquipmentFixtures.TORSO_MALE)
	_model.torso.gender = ModularBodyPartGendered.Gender.FEMALE
	chest.appearance.configure(_model)
	assert_str(EquipmentFixtures.mesh_path(_model.torso)).is_equal(EquipmentFixtures.TORSO_FEMALE)

func test_every_head_covering_but_masks_hides_the_hair() -> void:
	for covering: ModularBodyPart in [_model.head_coverings_base_hair, _model.head_coverings_no_hair, _model.head_no_elements]:
		_model.hair.update_index(0)
		covering.update_index(0)
		assert_bool(_model.hair.visible).override_failure_message("%s does not hide the hair" % covering.name).is_false()
		covering.update_index(-1)
		assert_bool(_model.hair.visible).override_failure_message("%s keeps the hair hidden" % covering.name).is_true()
