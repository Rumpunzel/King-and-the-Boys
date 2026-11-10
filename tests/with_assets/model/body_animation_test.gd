extends GdUnitTestSuite
## Models play their own animations along with a ModelAnimation (a jump while they hop), then go back to their idle

const MOVE: String = "res://data/model_animations/miniature_move_animation.tres"
const SPAWN: String = "res://data/model_animations/high_bounce_animation.tres"
const HEROES: Array[String] = ["knight", "rogue", "mystic", "soldier", "elf", "dwarf"]

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

func test_a_model_rests_in_its_passed_idle_and_back() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	var player: AnimationPlayer = _player_of(model)
	var through: StringName = &"AnimationLibrary_Godot/Crouch_Enter"
	var idle: StringName = &"AnimationLibrary_Godot/Crouch_Idle"
	model.set_idle_animation(idle, through)
	await await_idle_frame()
	assert_str(player.current_animation).is_equal(through)
	assert_str(model.get_idle_animation()).is_equal(idle)
	await await_millis(int(player.get_animation(through).length * 1000.0) + 100)
	assert_str(player.current_animation).is_equal(idle)
	# A hop lands back in the passed idle
	model.play_model_animation(load(MOVE) as ModelAnimation)
	await await_millis(3000)
	assert_str(player.current_animation).is_equal(idle)
	model.set_idle_animation(&"")
	await await_idle_frame()
	assert_str(player.current_animation).is_equal(player.autoplay)

func test_every_hero_moves_spawns_and_passes_in_their_own_way() -> void:
	var spawns: Dictionary[String, bool] = {}
	for hero: String in HEROES:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		var model: Model = auto_free(profile.create_model(0))
		add_child(model)
		var player: AnimationPlayer = _player_of(model)
		for animation: ModelAnimation in [profile.spawn_animation, profile.move_animation]:
			for body: StringName in [animation.body_animation, animation.body_landing, animation.body_follow_up]:
				if not body.is_empty(): assert_bool(player.has_animation(body)).override_failure_message("%s lacks %s" % [hero, body]).is_true()
		spawns[profile.spawn_animation.resource_path] = true
		for body: StringName in [profile.pass_animation, profile.passed_animation, profile.unpass_animation]:
			if not body.is_empty(): assert_bool(player.has_animation(body)).override_failure_message("%s lacks %s" % [hero, body]).is_true()
		assert_str(profile.passed_animation).is_not_empty()
		assert_int(player.get_animation(profile.passed_animation).loop_mode).override_failure_message("%s's passed animation must loop" % hero).is_not_equal(Animation.LOOP_NONE)
	assert_int(spawns.size()).override_failure_message("Each hero spawns their own way").is_equal(HEROES.size())

func test_a_wind_up_leans_back_on_the_spot_before_lifting_off() -> void:
	var model: ModularCharacter = auto_free(EquipmentFixtures.make_model())
	add_child(model)
	var rogue_move: ModelAnimation = load("res://data/model_animations/heroes/rogue_move.tres")
	var wind_up: float = rogue_move.get("_wind_up")
	assert_float(wind_up).is_greater(0.0)
	# Loading the meshes may stall the first frames, which would skip past the short wind-up
	for frame: int in 5: await await_idle_frame()
	model.play_model_animation(rogue_move)
	# The deepest lean and the highest lift during the wind-up
	var lean: float = 0.0
	var lift: float = 0.0
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(rogue_move.duration * wind_up * 700.0):
		await await_idle_frame()
		lean = minf(lean, model.rotation.x)
		lift = maxf(lift, model.position.y)
	assert_float(lift).override_failure_message("Still on the spot").is_less(0.03)
	assert_float(lean).override_failure_message("Leaning back").is_less(-0.05)
	await await_millis(int(rogue_move.duration * 500.0))
	assert_float(model.position.y).is_greater(0.2)
