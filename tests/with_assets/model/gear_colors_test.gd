extends GdUnitTestSuite
## Gear is repainted in its character's colours: the packs' blue and gold highlights, on whichever atlas the gear uses

const HEROES: Array[String] = ["knight", "rogue", "mystic", "soldier", "elf", "dwarf"]
const HERO_MATERIAL: String = "uid://bfwv8gb2fse5i"  # data/characters/gear/hero_gear_material.tres
const DWARF_MATERIAL: String = "uid://bi0qcogabe33g"  # data/characters/gear/dwarf_gear_material.tres

func test_gear_takes_the_material_of_its_atlas_and_the_colours() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	model.set_gear_colors(Color.RED, Color.GREEN)
	# A hero weapon and a dwarven one, in the same hand one after the other
	model.main_hand.update_index(model.main_hand.find_mesh_index("37"))
	assert_object(model.main_hand.material_override).is_same(load(HERO_MATERIAL))
	assert_that(model.main_hand.get_instance_shader_parameter(&"primary_color")).is_equal(Color.RED)
	assert_that(model.main_hand.get_instance_shader_parameter(&"secondary_color")).is_equal(Color.GREEN)
	model.main_hand.update_index(model.main_hand.find_mesh_index("20"))
	assert_object(model.main_hand.material_override).is_same(load(DWARF_MATERIAL))

func test_body_parts_and_uncoloured_gear_keep_their_material() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	model.set_gear_colors(Color.RED, Color.GREEN)
	assert_object(model.hair.material_override).override_failure_message("Hair is no gear").is_null()
	model.set_gear_colors(Color.TRANSPARENT, Color.TRANSPARENT)
	assert_object(model.torso.material_override).is_null()

func test_every_hero_has_a_colour_of_their_own_and_dresses_in_it() -> void:
	var colors: Dictionary[Color, String] = {}
	for hero: String in HEROES:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		assert_bool(colors.has(profile.color)).override_failure_message("%s shares %s's colour" % [hero, colors.get(profile.color)]).is_false()
		colors[profile.color] = hero
		assert_float(profile.gear_primary_color.a).is_greater(0.0)
		var model: ModularModel = auto_free(profile.create_model(0) as ModularModel)
		add_child(model)
		assert_that(model.gear_primary_color).is_equal(profile.gear_primary_color)
		assert_that(model.gear_secondary_color).is_equal(profile.gear_secondary_color)

func test_previews_raise_the_dwarf_by_its_profile() -> void:
	var dwarf: CharacterProfile = load(EquipmentFixtures.DWARF)
	# The smaller dwarf stands higher, so it is framed like the humans
	assert_float(dwarf.preview_offset.y).is_greater((load(EquipmentFixtures.KNIGHT) as CharacterProfile).preview_offset.y)

func test_a_material_put_on_the_whole_model_stays_on_its_gear() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	model.set_gear_colors(Color.RED, Color.GREEN)
	var ghost: StandardMaterial3D = StandardMaterial3D.new()
	model.apply_material_override(ghost)
	model.main_hand.update_index(0)
	assert_object(model.main_hand.material_override).override_failure_message("Equipping keeps the ghost").is_same(ghost)
	model.remove_material_override(ghost)
	assert_object(model.main_hand.material_override).override_failure_message("Painted again once it goes").is_not_same(ghost)
	assert_object(model.main_hand.material_override).is_not_null()
