extends GdUnitTestSuite
## Bodies roll skin and hair colours from their configuration, peers send them with the body, and every part is painted in them

const KNIGHT_BODY: String = "res://data/characters/people/knight_body.tres"
const DWARF_BODY: String = "res://data/characters/dwarves/random_dwarf.tres"

var _model: ModularCharacter

func before_test() -> void:
	_model = auto_free(EquipmentFixtures.make_model())
	add_child(_model)

func _colors(skin: PackedColorArray, hair: PackedColorArray) -> ModelConfigurationRandom:
	var configuration: ModelConfigurationRandom = ModelConfigurationRandom.new()
	configuration.skin_colors = skin
	configuration.hair_colors = hair
	return configuration

func _painted(body_part: ModularBodyPart, parameter: StringName) -> Color:
	assert_object(body_part.material_override).is_instanceof(ShaderMaterial)
	return body_part.get_instance_shader_parameter(parameter)

func test_every_hero_has_colours_to_roll_from() -> void:
	for hero: String in ["knight", "rogue", "mystic", "soldier", "elf", "dwarf"]:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		var configuration: ModelConfigurationRandom = profile.model_configuration
		assert_bool(configuration.skin_colors.is_empty()).override_failure_message("%s has no skin colours" % hero).is_false()
		assert_bool(configuration.hair_colors.is_empty()).override_failure_message("%s has no hair colours" % hero).is_false()

func test_a_rolled_body_carries_its_colours_and_paints_every_part() -> void:
	var configuration: ModelConfigurationRandom = load(KNIGHT_BODY)
	var body: Dictionary = configuration.roll(_model)
	var skin: Color = body[ModularModel.BODY_SKIN_COLOR]
	var hair: Color = body[ModularModel.BODY_HAIR_COLOR]
	assert_bool(configuration.skin_colors.has(skin)).is_true()
	assert_bool(configuration.hair_colors.has(hair)).is_true()
	assert_bool(_model.is_complete_body(body)).is_true()
	assert_bool(configuration.allows(_model, body)).is_true()
	# The face and hair are body parts, the bare hands gear: both show the skin
	assert_object(_painted(_model.head, &"skin_color")).is_equal(skin)
	assert_object(_painted(_model.hand_left, &"skin_color")).is_equal(skin)
	assert_object(_painted(_model.eyebrow, &"hair_color")).is_equal(hair)

func test_peers_show_the_colours_of_the_body_they_are_sent() -> void:
	var body: Dictionary = (load(KNIGHT_BODY) as ModelConfigurationRandom).roll(_model)
	var other: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(other)
	other.apply_body(body)
	assert_object(other.skin_color).is_equal(body[ModularModel.BODY_SKIN_COLOR])
	assert_object(_painted(other.eyebrow, &"hair_color")).is_equal(body[ModularModel.BODY_HAIR_COLOR])
	# A body without colours (e.g. saved before them) keeps the atlas' own
	body.erase(ModularModel.BODY_SKIN_COLOR)
	body.erase(ModularModel.BODY_HAIR_COLOR)
	other.apply_body(body)
	assert_object(other.skin_color).is_equal(Color.TRANSPARENT)
	assert_object(other.head.material_override).is_null()

func test_the_server_takes_only_colours_of_the_configuration() -> void:
	var configuration: ModelConfigurationRandom = _colors([Color.BISQUE], [Color.SADDLE_BROWN])
	var body: Dictionary = configuration.roll(_model)
	assert_bool(configuration.allows(_model, body)).is_true()
	var odd: Dictionary = body.duplicate()
	odd[ModularModel.BODY_HAIR_COLOR] = Color.LIME
	assert_bool(configuration.allows(_model, odd)).is_false()
	var missing: Dictionary = body.duplicate()
	missing.erase(ModularModel.BODY_SKIN_COLOR)
	assert_bool(configuration.allows(_model, missing)).is_false()
	# Without colours of its own, a configuration takes none
	assert_bool(_colors([], []).allows(_model, body)).is_false()
	var wrong_type: Dictionary = body.duplicate()
	wrong_type[ModularModel.BODY_SKIN_COLOR] = "bisque"
	assert_bool(_model.is_complete_body(wrong_type)).is_false()
	assert_bool(configuration.allows(_model, wrong_type)).is_false()

func test_dwarves_are_painted_by_their_atlas_colours() -> void:
	var dwarf: DwarfCharacter = auto_free(EquipmentFixtures.make_dwarf_model())
	add_child(dwarf)
	var body: Dictionary = (load(DWARF_BODY) as ModelConfigurationRandom).roll(dwarf)
	assert_bool(dwarf.is_complete_body(body)).is_true()
	assert_object(_painted(dwarf.body, &"skin_color")).is_equal(body[ModularModel.BODY_SKIN_COLOR])
	assert_object(_painted(dwarf.beard, &"hair_color")).is_equal(body[ModularModel.BODY_HAIR_COLOR])
	# Their outfits share the hair's dark brown, so only hair parts take the hair colour
	assert_object(_painted(dwarf.body, &"hair_color")).is_equal(Color.TRANSPARENT)
