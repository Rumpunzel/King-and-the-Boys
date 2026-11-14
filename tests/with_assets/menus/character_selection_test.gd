extends GdUnitTestSuite
## Picking a character at random in the lobby (R) always picks another one, so every pick shows off

const SELECTION: String = "uid://do0is58dpnojf"  # user_interface/menus/lobby_menu/character_selection.tscn

func test_a_random_pick_is_always_another_character() -> void:
	var selection: CharacterSelection = auto_free((load(SELECTION) as PackedScene).instantiate())
	add_child(selection)
	var picked: Array[CharacterProfile] = []
	selection.character_selected.connect(func(character: CharacterProfile) -> void: picked.append(character))
	for roll: int in 40:
		var before: CharacterProfile = selection.character
		selection.randomize_character()
		assert_object(selection.character).override_failure_message("Picked %s again" % before.name).is_not_same(before)
	assert_int(picked.size()).is_equal(40)
