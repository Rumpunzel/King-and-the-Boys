extends GdUnitTestSuite
## Models play their own animations along with a ModelAnimation (a jump while they hop), then go back to their idle

const MOVE: String = "res://data/model_animations/miniature_move_animation.tres"
const SPAWN: String = "res://data/model_animations/high_bounce_animation.tres"

func _player_of(model: Model) -> AnimationPlayer:
	var player: AnimationPlayer = model.get_animation_player()
	assert_object(player).is_not_null()
	return player

func test_a_hop_jumps_lands_and_goes_back_to_idle() -> void:
	for model: Model in [EquipmentFixtures.make_model(), EquipmentFixtures.make_dwarf_model()] as Array[Model]:
		auto_free(model)
		add_child(model)
		var move: ModelAnimation = load(MOVE)
		var player: AnimationPlayer = _player_of(model)
		model.play_model_animation(move)
		await await_idle_frame()
		assert_str(player.current_animation).is_equal(move.body_animation)
		await await_millis(int(move.duration * move.body_landing_time * 1000.0) + 100)
		assert_str(player.current_animation).is_equal(move.body_landing)
		await await_millis(int(player.get_animation(move.body_landing).length / move.body_speed * 1000.0) + 100)
		assert_str(player.current_animation).is_equal(player.autoplay)

func test_a_redirected_hop_stays_in_the_air_and_lands_anew() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	var move: ModelAnimation = load(MOVE)
	var player: AnimationPlayer = _player_of(model)
	model.play_model_animation(move)
	await await_millis(int(move.duration * move.body_landing_time * 500.0))
	model.continue_model_animation(move)
	await await_idle_frame()
	assert_str(player.current_animation).override_failure_message("No new take-off in the air").is_equal(move.body_animation)
	await await_millis(int(move.duration * move.body_landing_time * 1000.0) + 100)
	assert_str(player.current_animation).is_equal(move.body_landing)

func test_spawning_lands_in_a_crouch() -> void:
	var spawn: ModelAnimation = load(SPAWN)
	assert_str(spawn.body_landing).is_equal(&"AnimationLibrary_Godot/Jump_Land")
	for model: Model in [EquipmentFixtures.make_model(), EquipmentFixtures.make_dwarf_model()] as Array[Model]:
		auto_free(model)
		add_child(model)
		for animation: StringName in [spawn.body_animation, spawn.body_landing]: assert_bool(_player_of(model).has_animation(animation)).is_true()

func test_models_without_their_own_animations_only_move() -> void:
	var model: Model = auto_free(Model.new())
	add_child(model)
	assert_object(model.get_animation_player()).is_null()
	assert_object(model.play_model_animation(load(MOVE) as ModelAnimation)).is_not_null()
