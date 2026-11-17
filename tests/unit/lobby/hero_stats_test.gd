@icon("uid://d3wqipxx8dw13")
extends GdUnitTestSuite
## The lobby's HeroStats shows a hero's stats, HeroAbilities its abilities with each description as its tooltip

func test_the_stats_show_the_heroes_values() -> void:
	var stats_scene: PackedScene = load("uid://dp2uvtgmdbxh0") # user_interface/menus/lobby_menu/hero_stats.tscn
	var hero_stats: HeroStats = stats_scene.instantiate()
	add_child(hero_stats)
	# Distinct values, so each label shows its own stat
	var hero: CharacterProfile = _create_hero()
	hero.strength = 5
	hero.intelligence = 1
	hero.agility = 4
	hero.speed = 2
	hero_stats.character = hero

	var texts: Array[String] = []
	for control: Node in hero_stats.find_children("*", "Label", true, false): texts.append((control as Label).text)
	for value: int in [hero.strength, hero.intelligence, hero.agility, hero.speed]:
		assert_bool(texts.has(str(value))).is_true()
	hero_stats.character = null
	for control: Node in [hero_stats.get_node("Strength/Score"), hero_stats.get_node("Speed/Score")]:
		assert_str((control as Label).text).is_empty()
	hero_stats.queue_free()

func test_the_abilities_show_their_descriptions() -> void:
	var hero_abilities: HeroAbilities = HeroAbilities.new()
	add_child(hero_abilities)
	var hero: CharacterProfile = _create_hero()
	var abilities: Array[Ability] = []
	for index: int in range(2):
		var ability: Ability = Ability.new()
		ability.name = "Ability %d" % index
		ability.description = "Does thing number %d" % index
		abilities.append(ability)
	hero.abilities = abilities
	hero_abilities.character = hero

	var tooltips: Array[String] = []
	for child: Node in hero_abilities.get_children(): tooltips.append((child as Control).tooltip_text)
	assert_array(tooltips).contains_exactly([abilities[0].description, abilities[1].description])
	hero_abilities.character = null
	assert_int(hero_abilities.get_child_count()).is_equal(0)
	hero_abilities.queue_free()
	# The removed icons are freed at the end of the frame
	await get_tree().process_frame

func _create_hero() -> CharacterProfile:
	var fixture: CharacterProfile = load("uid://b5brg76ytc255") # tests/fixtures/hero.tres
	return fixture.duplicate()
