extends GdUnitTestSuite
## Models play animation files along with a ModelAnimation (a jump while they hop), and rest in their idles: in turn, at random,
## or in what they were told to rest in, such as sitting while their player has passed

const MOVE: String = "res://data/model_animations/miniature_move_animation.tres"
const SPAWN: String = "res://data/model_animations/high_bounce_animation.tres"
const KNIGHT_MOVE: String = "res://data/model_animations/heroes/knight_move.tres"
const ROGUE_MOVE: String = "res://data/model_animations/heroes/rogue_move.tres"
const ANIMATIONS: String = "res://data/characters/animations/quaternius/%s.res"
const HEROES: Array[String] = ["knight", "rogue", "mystic", "soldier", "elf", "dwarf"]

func _animation(animation_name: String) -> Animation:
	return load(ANIMATIONS % animation_name)

func _models() -> Array[Model]:
	var models: Array[Model] = [EquipmentFixtures.make_model(), EquipmentFixtures.make_dwarf_model()]
	for model: Model in models:
		auto_free(model)
		add_child(model)
	return models

func _set_of(animation_names: Array[String], order: BodyAnimations.Order) -> BodyAnimations:
	var body_animations: BodyAnimations = BodyAnimations.new()
	var animations: Array[Animation] = []
	for animation_name: String in animation_names: animations.append(_animation(animation_name))
	body_animations.animations = animations
	body_animations.order = order
	return body_animations

func test_a_hop_jumps_lands_and_goes_back_to_resting() -> void:
	var move: ModelAnimation = load(KNIGHT_MOVE)
	for model: Model in _models():
		var player: AnimationPlayer = model.get_animation_player()
		model.play_model_animation(move)
		await await_idle_frame()
		assert_bool(model.is_playing(move.body_animation)).is_true()
		await await_millis(int(move.duration * move.body_landing_time * 1000.0) + 100)
		assert_bool(model.is_playing(move.body_landing)).is_true()
		await await_millis(int(move.body_landing.length / move.body_speed * 1000.0) + 100)
		assert_str(player.current_animation).is_equal(player.autoplay)

func test_a_redirected_hop_stays_in_the_air_and_lands_anew() -> void:
	var model: Model = _models()[0]
	var move: ModelAnimation = load(KNIGHT_MOVE)
	model.play_model_animation(move)
	await await_millis(int(move.duration * move.body_landing_time * 500.0))
	model.continue_model_animation(move)
	await await_idle_frame()
	assert_bool(model.is_playing(move.body_animation)).override_failure_message("No new take-off in the air").is_true()
	await await_millis(int(move.duration * move.body_landing_time * 1000.0) + 100)
	assert_bool(model.is_playing(move.body_landing)).is_true()

func test_animation_files_play_on_every_body() -> void:
	var jump: Animation = _animation("Jump")
	for model: Model in _models():
		model.play_body_animation(jump)
		await await_idle_frame()
		assert_bool(model.is_playing(jump)).is_true()
	# Copies of one animation keep apart, as their files differ
	assert_str(Model.get_animation_key(jump)).is_not_equal(Model.get_animation_key(_animation("Jump_Land")))

func test_the_shared_tweens_name_no_animation_files() -> void:
	# CharacterProfile preloads them, and scripts must not pull in asset files (CI has none)
	for path: String in [MOVE, SPAWN]: assert_bool((load(path) as ModelAnimation).has_body_animations()).is_false()

func test_models_without_their_own_animations_only_move() -> void:
	var model: Model = auto_free(Model.new())
	add_child(model)
	assert_object(model.get_animation_player()).is_null()
	assert_object(model.play_model_animation(load(KNIGHT_MOVE) as ModelAnimation)).is_not_null()

func test_idles_play_in_turn() -> void:
	var model: Model = _models()[0]
	var idles: BodyAnimations = _set_of(["Idle_LookAround", "Idle_Tired"], BodyAnimations.Order.SEQUENCE)
	model.idle_animations = idles
	await await_idle_frame()
	assert_bool(model.is_playing(idles.animations[0])).is_true()
	await await_millis(int(idles.animations[0].length * 1000.0))
	assert_bool(model.is_playing(idles.animations[1])).is_true()

func test_random_idles_pick_once_or_every_cycle() -> void:
	var idles: BodyAnimations = _set_of(["Idle", "Idle_LookAround", "Idle_Tired"], BodyAnimations.Order.RANDOM_ONCE)
	assert_int(idles.get_next(1, 3)).override_failure_message("Picked once, it keeps looping").is_equal(-1)
	idles.order = BodyAnimations.Order.RANDOM_EACH_CYCLE
	var picked: Dictionary[int, bool] = {}
	for roll: int in 60:
		var next: int = idles.get_next(1, 3)
		assert_int(next).override_failure_message("A new cycle plays another one").is_not_equal(1)
		picked[next] = true
	assert_array(picked.keys()).contains_exactly_in_any_order([0, 2])
	idles.order = BodyAnimations.Order.SEQUENCE
	assert_int(idles.get_next(2, 3)).is_equal(0)

func test_a_model_rests_in_what_it_is_told_and_back() -> void:
	var model: Model = _models()[0]
	var player: AnimationPlayer = model.get_animation_player()
	var through: Animation = _animation("Crouch_Enter")
	var resting: BodyAnimations = _set_of(["Crouch_Idle"], BodyAnimations.Order.SEQUENCE)
	model.rest_in(resting, through)
	await await_idle_frame()
	assert_bool(model.is_playing(through)).is_true()
	await await_millis(int(through.length * 1000.0) + 100)
	assert_bool(model.is_playing(resting.animations[0])).is_true()
	# A hop lands back in it
	model.play_model_animation(load(KNIGHT_MOVE) as ModelAnimation)
	await await_millis(3000)
	assert_bool(model.is_playing(resting.animations[0])).is_true()
	model.rest_in(null)
	await await_idle_frame()
	assert_str(player.current_animation).is_equal(player.autoplay)

func test_every_hero_moves_spawns_and_passes_in_their_own_way() -> void:
	var spawns: Dictionary[String, bool] = {}
	for hero: String in HEROES:
		var profile: CharacterProfile = load("res://data/characters/people/%s.tres" % hero)
		assert_bool(profile.move_animation.has_body_animations()).override_failure_message("%s hops without a body animation" % hero).is_true()
		assert_bool(profile.spawn_animation.has_body_animations()).override_failure_message("%s spawns without a body animation" % hero).is_true()
		spawns[profile.spawn_animation.resource_path] = true
		assert_object(profile.passed_animations).override_failure_message("%s shows no pass" % hero).is_not_null()
		assert_array(profile.passed_animations.get_animations()).is_not_empty()
	assert_int(spawns.size()).override_failure_message("Each hero spawns their own way").is_equal(HEROES.size())

func test_a_wind_up_leans_back_on_the_spot_before_lifting_off() -> void:
	var model: Model = _models()[0]
	var rogue_move: ModelAnimation = load(ROGUE_MOVE)
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

func test_figures_travel_as_their_move_says() -> void:
	var hop: ModelAnimation = load(MOVE)
	# The hop pulls back a little before it goes forward; redirected, it travels on smoothly
	assert_int(hop.travel_transition).is_equal(Tween.TRANS_BACK)
	assert_int(hop.travel_ease).is_equal(Tween.EASE_IN)
	assert_int(hop.redirect_transition).is_equal(Tween.TRANS_SINE)
	var rogue_move: ModelAnimation = load(ROGUE_MOVE)
	assert_int(rogue_move.travel_transition).override_failure_message("A roll does not pull back").is_not_equal(Tween.TRANS_BACK)
	assert_float(rogue_move.travel_delay).override_failure_message("The rogue stays put while winding up").is_equal_approx(rogue_move.get("_wind_up") as float, 0.001)
