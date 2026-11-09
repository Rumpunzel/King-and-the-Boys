extends GdUnitTestSuite

var _knight: CharacterProfile
var _original_starting_equipment: Dictionary
var _original_random_equipment: Array[SpawnTable]

func before_test() -> void:
	_knight = load(EquipmentFixtures.KNIGHT)
	_original_starting_equipment = EquipmentFixtures.clear_starting_equipment(_knight)
	_original_random_equipment = _knight.random_equipment
	_knight.random_equipment = []

func after_test() -> void:
	EquipmentFixtures.restore_starting_equipment(_knight, _original_starting_equipment)
	_knight.random_equipment = _original_random_equipment

func after() -> void:
	EquipmentFixtures.remove_saved_items()

func _peer_from(character_data: Dictionary[StringName, Variant]) -> Character:
	var scene: PackedScene = load(EquipmentFixtures.CHARACTER)
	var peer: Character = auto_free(scene.instantiate())
	peer.apply_character_data(character_data)
	return peer

func _body_mesh_paths(character: Character) -> PackedStringArray:
	var model: ModularCharacter = character.model
	var paths: PackedStringArray = []
	for part: ModularCharacter.Part in ModelConfigurationRandom.BODY_PARTS: paths.append(EquipmentFixtures.mesh_path(model.get_part(part)))
	return paths

func test_character_data_has_all_keys() -> void:
	var data: Dictionary[StringName, Variant] = _knight.create_character_data(-1, Transform3D())
	Character.validate_character_data(data)
	assert_int(data[Character.VARIATION] as int).is_greater_equal(0)
	assert_int((data[Character.BODY] as Dictionary).size()).is_equal(ModelConfigurationRandom.BODY_PARTS.size())
	assert_array(data[Character.EQUIPMENT] as PackedStringArray).is_empty()

func test_body_is_sent_as_mesh_uids() -> void:
	var body: Dictionary = _knight.create_character_data(0, Transform3D())[Character.BODY]
	for part: ModularCharacter.Part in body:
		var mesh_id: String = body[part]
		if mesh_id.is_empty(): continue
		assert_str(mesh_id).starts_with("uid://")

func test_peers_show_the_body_the_server_rolled() -> void:
	var data: Dictionary[StringName, Variant] = _knight.create_character_data(0, Transform3D())
	var host: Character = auto_free(Character.from_character_data(data))
	var peer: Character = _peer_from(data)
	var body: Dictionary = data[Character.BODY]
	var rolled: PackedStringArray = []
	for part: ModularCharacter.Part in ModelConfigurationRandom.BODY_PARTS:
		var mesh: Resource = ResourceId.find(body[part] as String)
		rolled.append(mesh.resource_path if mesh else "")
	assert_array(_body_mesh_paths(host)).is_equal(rolled)
	assert_array(_body_mesh_paths(peer)).is_equal(rolled)

func test_body_survives_a_model_rebuild() -> void:
	var host: Character = auto_free(Character.from_character_data(_knight.create_character_data(0, Transform3D())))
	var before: PackedStringArray = _body_mesh_paths(host)
	host.profile = _knight
	assert_array(_body_mesh_paths(host)).is_equal(before)

func test_server_rolls_differ_between_spawns() -> void:
	var first: Dictionary = _knight.create_character_data(0, Transform3D())[Character.BODY]
	var differs: bool = false
	for attempt: int in 20:
		var other: Dictionary = _knight.create_character_data(0, Transform3D())[Character.BODY]
		if other != first: differs = true
	assert_bool(differs).is_true()

func test_starting_and_rolled_equipment_reach_peers() -> void:
	var mask: EquipmentLook = EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("mask"), ModularCharacter.Part.HEAD_COVERINGS_NO_FACIAL_HAIR, EquipmentFixtures.MASK), "mask.tres")
	var helmet: EquipmentLook = EquipmentFixtures.save_item(EquipmentFixtures.make_item(EquipmentFixtures.load_type("helmet"), ModularCharacter.Part.HELMET_ATTACHMENT, EquipmentFixtures.HELMET_ATTACHMENT), "helmet.tres")
	var table: ProfileSpawnTable = ProfileSpawnTable.new()
	var distribution: Dictionary[Profile, float] = {helmet: 1.0}
	table._profile_distribution = distribution
	_knight.face = ResourceId.of(mask)
	_knight.random_equipment = [table, null]
	var data: Dictionary[StringName, Variant] = _knight.create_character_data(0, Transform3D())
	assert_array(data[Character.EQUIPMENT] as PackedStringArray).contains_exactly([ResourceId.of(mask), ResourceId.of(helmet)])
	var host: Character = auto_free(Character.from_character_data(data))
	assert_object(host.equipment.get_equipped(EquipmentLook.Slot.HEAD)).is_same(helmet)
	assert_object(host.equipment.get_equipped(EquipmentLook.Slot.FACE)).is_null()
	var round_trip: Dictionary[StringName, Variant] = host.to_character_data()
	assert_array(round_trip[Character.EQUIPMENT] as PackedStringArray).contains_exactly([ResourceId.of(helmet)])
	var peer: Character = _peer_from(round_trip)
	var peer_model: ModularCharacter = peer.model
	assert_str(EquipmentFixtures.mesh_path(peer_model.helmet_attachment)).is_equal(EquipmentFixtures.HELMET_ATTACHMENT)
