@icon("uid://d3wqipxx8dw13")
extends GdUnitTestSuite
## A HeroRoster lists the heroes a player may pick, and knows whether a profile is one of them


func test_the_roster_knows_its_heroes() -> void:
	var roster: HeroRoster = load("uid://ddcr4k3p6t8nw") # tests/fixtures/heroes.tres
	var hero: CharacterProfile = load("uid://b5brg76ytc255") # tests/fixtures/hero.tres
	var second_hero: CharacterProfile = load("uid://c6k2m8x4q1vbe") # tests/fixtures/second_hero.tres

	assert_bool(roster.has(hero)).is_true()
	assert_bool(roster.has(second_hero)).is_true()
	assert_bool(roster.has(null)).is_false()
	assert_bool(roster.has(CharacterProfile.new())).is_false()
