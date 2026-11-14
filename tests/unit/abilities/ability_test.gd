extends GdUnitTestSuite
## Ability rules that need no level: targeting, cost, passives, charges left

const CHARGED_ABILITY: Ability = preload("uid://co0ut6egps37w")  # tests/fixtures/charged_ability.tres

func _character_at(cell: Vector2i) -> Character:
	var character: Character = auto_free(Character.new())
	character.grid_cell = cell
	return character

func test_own_tile_targets_the_character_cell() -> void:
	var ability: Ability = Ability.new()
	var character: Character = _character_at(Vector2i(2, -1))
	assert_array(ability.get_targets(character, null)).contains_exactly([Vector2i(2, -1)])
	assert_bool(ability.can_use(character, Vector2i(2, -1), 0, null)).is_true()
	assert_bool(ability.can_use(character, Vector2i(2, 0), 0, null)).is_false()

func test_passives_are_never_used() -> void:
	var ability: Ability = Ability.new()
	ability.targeting = Ability.Targeting.NONE
	var character: Character = _character_at(Vector2i.ZERO)
	assert_bool(ability.is_passive()).is_true()
	assert_array(ability.get_targets(character, null)).is_empty()
	assert_bool(ability.can_use(character, Vector2i.ZERO, 0, null)).is_false()

func test_a_use_records_its_cost() -> void:
	var ability: Ability = Ability.new()
	ability.cost = 2
	var character: Character = _character_at(Vector2i.ZERO)
	var step: AbilityStep = ability.use(character, Vector2i.ZERO, 0, null)
	assert_int(step.cost).is_equal(2)
	assert_object(step.ability).is_same(ability)
	assert_object(step.character).is_same(character)

func test_charges_left_follow_the_uses() -> void:
	var character: Character = _character_at(Vector2i.ZERO)
	assert_int(CHARGED_ABILITY.get_charges_left(character)).is_equal(3)
	character.ability_uses = {ResourceId.of(CHARGED_ABILITY): 2}
	assert_int(CHARGED_ABILITY.get_charges_left(character)).is_equal(1)
	character.ability_uses = {ResourceId.of(CHARGED_ABILITY): 5}
	assert_int(CHARGED_ABILITY.get_charges_left(character)).is_equal(0)

func test_unlimited_abilities_have_no_charges() -> void:
	var character: Character = _character_at(Vector2i.ZERO)
	assert_int(Ability.new().get_charges_left(character)).is_negative()
