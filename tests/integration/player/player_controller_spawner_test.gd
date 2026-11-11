extends GdUnitTestSuite
## Player controllers spawn once per player, wait for the level, and the spawner can start again;
## taking control of a piece is the host's decision

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const SPAWNER_SCENE: String = "res://engine/player/player_controller_spawner.tscn"
const OTHER_PLAYER_ID: int = 2
const THIRD_PLAYER_ID: int = 3

var _level: Level
var _spawner: PlayerControllerSpawner
var _local_player: Player
var _local_character: CharacterProfile

func before() -> void:
	if Lobby.get_connected_players().is_empty(): Lobby.call("_create_local_player")

func before_test() -> void:
	_local_player = Lobby.get_player(Multiplayer.HOST_ID)
	_local_character = _local_player.character
	_local_player.character = ModelFreeWorld.load_hero_profile()
	_level = null
	_spawner = auto_free((load(SPAWNER_SCENE) as PackedScene).instantiate())
	add_child(_spawner)

func after_test() -> void:
	_spawner.stop_synching_players()
	var players: Dictionary = Lobby.get("_players")
	players.erase(OTHER_PLAYER_ID)
	players.erase(THIRD_PLAYER_ID)
	_local_player.character = _local_character
	await await_idle_frame()

func _add_level(build: bool = true) -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_spawner.set("_level", _level)
	_spawner.player_controller_created.connect(_level._on_player_controller_created)
	add_child(_level)
	if build: _level.build_level()
	await await_idle_frame()

## Gives [param controller] the interaction area its scene lacks while taking control is tabled
func _give_interaction_area(controller: PlayerController) -> void:
	var area: InteractionArea = (load("res://engine/player/interaction_area.tscn") as PackedScene).instantiate()
	controller.character.add_child(area)
	var state_machine: PlayerStateMachine = controller.get("_state_machine")
	state_machine.interaction_area = area

## A character no player owns, within [param controller]'s reach. The tabled interaction area has no shape and
## does not look at character hit boxes yet, so the piece is put in its list instead of overlapping in physics.
func _add_piece_near(controller: Character) -> Character:
	var piece: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, controller.global_position)))
	piece.level = _level
	add_child(piece)
	await await_idle_frame()
	var state_machine: PlayerStateMachine = (controller.get_parent() as PlayerController).get("_state_machine")
	var hit_boxes_in_area: Array[HitBox] = state_machine.interaction_area.get("_hit_boxes_in_area")
	hit_boxes_in_area.append(_hit_box_of(piece))
	return piece

func _add_other_player() -> Player:
	var other: Player = auto_free(Player.create(OTHER_PLAYER_ID, "Other"))
	other.character = ModelFreeWorld.load_hero_profile()
	var players: Dictionary = Lobby.get("_players")
	players[OTHER_PLAYER_ID] = other
	return other

func _controllers() -> Array[PlayerController]:
	var controllers: Array[PlayerController] = []
	for child: Node in _spawner.get_children():
		if child is PlayerController and not child.is_queued_for_deletion(): controllers.append(child as PlayerController)
	return controllers

func _controller_of(player_id: int) -> PlayerController:
	for controller: PlayerController in _controllers():
		if controller.player.player_id == player_id: return controller
	return null

func _hit_box_of(character: Character) -> HitBox:
	for child: Node in character.get_children():
		if child is HitBox: return child as HitBox
	return null

func test_spawns_one_controller_per_player_and_may_start_again() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(1)
	# E.g. after loading a game: nobody gets a second controller
	_spawner.start_synching_players()
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(1)

func test_waits_for_the_level_to_be_built() -> void:
	await _add_level(false)
	_spawner.start_synching_players()
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(0)
	_level.build_level()
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(1)

func test_players_joining_later_get_a_controller() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	Lobby.player_created.emit(_add_other_player())
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(2)

func test_stop_removes_controllers_and_lets_go_of_the_lobby() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	_spawner.stop_synching_players()
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(0)
	Lobby.player_created.emit(_add_other_player())
	await await_idle_frame()
	assert_int(_controllers().size()).is_equal(0)

func test_no_one_takes_control_of_a_players_own_character() -> void:
	await _add_level()
	_add_other_player()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	var other_character: Character = _controller_of(OTHER_PLAYER_ID).character
	assert_bool(_hit_box_of(other_character).may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_false()
	assert_bool(_hit_box_of(local_character).may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_false()

func test_only_the_owner_asks_with_a_character() -> void:
	await _add_level()
	_add_other_player()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	_give_interaction_area(_controller_of(Multiplayer.HOST_ID))
	var piece: Character = await _add_piece_near(local_character)
	var hit_box: HitBox = _hit_box_of(piece)
	assert_bool(hit_box.may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_true()
	# The other player may not ask with the host's character
	assert_bool(hit_box.may_be_controlled_by(local_character, OTHER_PLAYER_ID)).is_false()

func test_granted_control_reaches_both_sides_and_ends_with_the_controller() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	_give_interaction_area(_controller_of(Multiplayer.HOST_ID))
	var piece: Character = await _add_piece_near(local_character)
	var hit_box: HitBox = _hit_box_of(piece)
	hit_box.request_control(local_character.get_path())
	assert_object(hit_box.controller).is_same(local_character)
	assert_object(local_character.controlling).is_same(hit_box)
	assert_object(piece.controlled_by).is_same(local_character)
	# A piece is controlled by one at a time, and a controller controls one at a time
	var other_piece: Character = await _add_piece_near(local_character)
	assert_bool(_hit_box_of(other_piece).may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_false()
	# The controller leaving gives the piece back
	_spawner.stop_synching_players()
	await await_idle_frame()
	assert_object(hit_box.controller).is_null()
	assert_object(piece.controlled_by).is_null()

func test_the_controller_releases() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	_give_interaction_area(_controller_of(Multiplayer.HOST_ID))
	var piece: Character = await _add_piece_near(local_character)
	var hit_box: HitBox = _hit_box_of(piece)
	hit_box.request_control(local_character.get_path())
	hit_box.request_release()
	assert_object(hit_box.controller).is_null()
	assert_object(local_character.controlling).is_null()

func test_refused_requests_change_nothing() -> void:
	await _add_level()
	_add_other_player()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	var other_character: Character = _controller_of(OTHER_PLAYER_ID).character
	var hit_box: HitBox = _hit_box_of(other_character)
	hit_box.request_control(local_character.get_path())
	assert_object(hit_box.controller).is_null()
	assert_object(other_character.controlled_by).is_null()
	assert_bool(other_character.is_controlled_by(Multiplayer.HOST_ID)).is_false()

func test_players_spawn_on_their_own_spots() -> void:
	await _add_level()
	_add_other_player()
	var third: Player = auto_free(Player.create(THIRD_PLAYER_ID, "Third"))
	third.character = ModelFreeWorld.load_hero_profile()
	var players: Dictionary = Lobby.get("_players")
	players[THIRD_PLAYER_ID] = third
	_spawner.start_synching_players()
	await await_idle_frame()
	var spots: Array[Vector2] = []
	for controller: PlayerController in _controllers():
		var character: Character = controller.character
		# Created where it stands: the figure has nowhere to move to
		assert_vector(character.global_position).is_equal_approx(_level.get_spot_position(character.grid_cell, character.tile_spot), Vector3.ONE * 0.001)
		assert_bool(character.is_figure_moving()).is_false()
		assert_bool(spots.has(character.tile_spot)).is_false()
		spots.append(character.tile_spot)
	assert_int(spots.size()).is_equal(3)
