@icon("uid://d3wqipxx8dw13")
extends GdUnitTestSuite
## The lobby's HeroStats shows a hero's name, stats and abilities, each ability's description as its tooltip

func test_the_stats_show_the_heroes_values() -> void:
	var stats_scene: PackedScene = load("uid://dp2uvtgmdbxh0") # user_interface/menus/lobby_menu/hero_stats.tscn
	var hero_stats: HeroStats = stats_scene.instantiate()
	add_child(hero_stats)
	var fixture: CharacterProfile = load("uid://b5brg76ytc255") # tests/fixtures/hero.tres
	# Distinct values, so each label shows its own stat
	var hero: CharacterProfile = fixture.duplicate()
	hero.strength = 5
	hero.intelligence = 1
	hero.agility = 4
	hero.speed = 2
	var abilities: Array[Ability] = []
	for index: int in range(2):
		var ability: Ability = Ability.new()
		ability.name = "Ability %d" % index
		ability.description = "Does thing number %d" % index
		abilities.append(ability)
	hero.abilities = abilities
	hero_stats.character = hero

	var texts: PackedStringArray = []
	var tooltips: PackedStringArray = []
	for control: Node in hero_stats.find_children("*", "Control", true, false):
		if control is Label: texts.append((control as Label).text)
		var tooltip: String = (control as Control).tooltip_text
		if not tooltip.is_empty(): tooltips.append(tooltip)
	var shown: String = " ".join(texts)
	assert_str(shown).contains(hero.name)
	for value: int in [hero.strength, hero.intelligence, hero.agility, hero.speed]:
		assert_bool(texts.has(str(value))).is_true()
	assert_array(Array(tooltips)).contains_exactly([abilities[0].description, abilities[1].description])
	hero_stats.queue_free()
