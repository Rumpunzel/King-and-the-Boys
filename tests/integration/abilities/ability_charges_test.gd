extends GdUnitTestSuite
## Ability charges on a hero in a generated level (no assets): listed by the profile, counted, refunded, saved

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const CHARGED_ABILITY: Ability = preload("res://tests/fixtures/charged_ability.tres")

var _level: Level
var _hero_profile: CharacterProfile
var _original_abilities: Array[Ability]

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_hero_profile = ModelFreeWorld.load_hero_profile()
	# The profile is cached: restored after each test
	_original_abilities = _hero_profile.abilities
	_hero_profile.abilities = [CHARGED_ABILITY]
	add_child(_level)
	_level.build_level()
	await await_idle_frame()

func after_test() -> void:
	_hero_profile.abilities = _original_abilities

func _spawn_hero() -> Character:
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	var spawn_position: Vector3 = (spawn_points.front() as Node3D).global_position
	var hero: Character = auto_free(_hero_profile.create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(_level.world_to_grid_position(spawn_position)))))
	hero.level = _level
	add_child(hero)
	await await_idle_frame()
	return hero

func test_the_profile_lists_its_abilities() -> void:
	var hero: Character = await _spawn_hero()
	assert_bool(hero.has_ability(CHARGED_ABILITY)).is_true()
	assert_bool(hero.has_ability(Ability.new())).is_false()

func test_charges_are_spent_and_refunded() -> void:
	var hero: Character = await _spawn_hero()
	hero.spend_charge(CHARGED_ABILITY)
	hero.spend_charge(CHARGED_ABILITY)
	assert_int(hero.get_charges_left(CHARGED_ABILITY)).is_equal(1)
	hero.refund_charge(CHARGED_ABILITY)
	assert_int(hero.get_charges_left(CHARGED_ABILITY)).is_equal(2)
	hero.refund_charge(CHARGED_ABILITY)
	hero.refund_charge(CHARGED_ABILITY)
	assert_int(hero.get_charges_left(CHARGED_ABILITY)).is_equal(3)
	assert_dict(hero.ability_uses).is_empty()

func test_charges_never_go_below_zero() -> void:
	var hero: Character = await _spawn_hero()
	for _use: int in 5: hero.spend_charge(CHARGED_ABILITY)
	assert_int(hero.get_charges_left(CHARGED_ABILITY)).is_equal(0)

## The synchronizer notices only a new dictionary, not one changed in place
func test_each_change_replaces_the_uses() -> void:
	var hero: Character = await _spawn_hero()
	var before_use: Dictionary = hero.ability_uses
	var changes: Array[int] = [0]
	hero.ability_uses_changed.connect(func() -> void: changes[0] += 1)
	hero.spend_charge(CHARGED_ABILITY)
	assert_object(hero.ability_uses).is_not_same(before_use)
	assert_dict(before_use).is_empty()
	assert_int(changes[0]).is_equal(1)

func test_uses_are_saved() -> void:
	var hero: Character = await _spawn_hero()
	hero.spend_charge(CHARGED_ABILITY)
	var serializer: SynchronizerSerializer = hero.get_node(^"CharacterSynchronizer/SynchronizerSerializer")
	var saved: Dictionary[StringName, Variant] = {}
	var collected: Dictionary[NodePath, Variant] = serializer.collect_properties()
	for property_path: NodePath in collected: saved[property_path.get_concatenated_subnames()] = collected[property_path]
	assert_dict(saved).contains_keys([&"ability_uses"])
	var saved_uses: Dictionary = saved[&"ability_uses"]
	assert_dict(saved_uses).is_equal({ResourceId.of(CHARGED_ABILITY): 1})
	# Survives the save format
	var round_trip: Dictionary = Serializer.decode_data(Serializer.encode_data(saved_uses))
	assert_dict(round_trip).is_equal(saved_uses)
