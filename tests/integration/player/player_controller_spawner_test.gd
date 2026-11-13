extends GdUnitTestSuite
## Player controllers spawn once per player, wait for the level, and the spawner can start again;
## taking control of a piece is the host's decision

const ModelFreeWorld = preload("res://tests/fixtures/model_free_world.gd")
const SPAWNER_SCENE: String = "res://engine/player/player_controller_spawner.tscn"
const OTHER_PLAYER_ID: int = 2
const THIRD_PLAYER_ID: int = 3
## Players with ids from 10 on fill the start tile beyond its five spots
const CROWD_FIRST_ID: int = 10
const CROWD_SIZE: int = 6

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
	for crowd_id: int in range(CROWD_FIRST_ID, CROWD_FIRST_ID + CROWD_SIZE): players.erase(crowd_id)
	_local_player.character = _local_character
	await await_idle_frame()

func _add_level(build: bool = true) -> void:
	_level = auto_free(ModelFreeWorld.create_level())
	_spawner.set("_level", _level)
	_spawner.player_controller_created.connect(_level._on_player_controller_created)
	add_child(_level)
	if build: _level.build_level()
	await await_idle_frame()

## A character no player owns, on [param controller]'s tile (or next door through a passage, if the tile is full): in
## its reach
func _add_piece_near(controller: Character) -> Character:
	var piece: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, controller.global_position)))
	piece.level = _level
	add_child(piece)
	await await_idle_frame()
	return piece

## A character no player owns, on [param cell]
func _add_piece_at(cell: Vector2i) -> Character:
	var piece: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(cell))))
	piece.level = _level
	add_child(piece)
	await await_idle_frame()
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
	var piece: Character = await _add_piece_near(local_character)
	var hit_box: HitBox = _hit_box_of(piece)
	assert_bool(hit_box.may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_true()
	# The other player may not ask with the host's character
	assert_bool(hit_box.may_be_controlled_by(local_character, OTHER_PLAYER_ID)).is_false()

func test_pieces_are_in_reach_on_the_tile_and_along_passages_only() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
	var start: Vector2i = local_character.grid_cell
	var in_reach: Array[Vector2i] = _level.get_cells_in_reach(start)
	assert_int(in_reach.size()).override_failure_message("The start has a passage").is_greater(1)
	var next_door: Character = await _add_piece_at(in_reach[in_reach.size() - 1])
	assert_bool(_hit_box_of(next_door).may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_true()
	# Reach goes by the grid: a walkable tile beyond it is out of reach
	var beyond: Array[Vector2i] = []
	for cell: Vector2i in (_level.get("_placed_tiles") as Dictionary):
		if not in_reach.has(cell) and not _level.get_placed_tile(cell).get_connections().is_empty(): beyond.append(cell)
	assert_array(beyond).is_not_empty()
	var far: Character = await _add_piece_at(beyond[0])
	assert_bool(_hit_box_of(far).may_be_controlled_by(local_character, Multiplayer.HOST_ID)).is_false()

func test_granted_control_reaches_both_sides_and_ends_with_the_controller() -> void:
	await _add_level()
	_spawner.start_synching_players()
	await await_idle_frame()
	var local_character: Character = _controller_of(Multiplayer.HOST_ID).character
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

func test_a_full_start_tile_sends_players_to_the_nearest_tile_with_room() -> void:
	await _add_level()
	var players: Dictionary = Lobby.get("_players")
	for crowd_id: int in range(CROWD_FIRST_ID, CROWD_FIRST_ID + CROWD_SIZE):
		var crowd_player: Player = auto_free(Player.create(crowd_id, "Crowd %d" % crowd_id))
		crowd_player.character = ModelFreeWorld.load_hero_profile()
		players[crowd_id] = crowd_player
	_spawner.start_synching_players()
	await await_idle_frame()
	var start_cell: Vector2i = _level.world_to_grid_position((get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position)
	var places: Array[String] = []
	var off_start: int = 0
	for controller: PlayerController in _controllers():
		var character: Character = controller.character
		var place: String = "%s %s" % [character.grid_cell, character.tile_spot]
		assert_bool(places.has(place)).override_failure_message("Two players on %s" % place).is_false()
		places.append(place)
		assert_vector(character.global_position).is_equal_approx(_level.get_spot_position(character.grid_cell, character.tile_spot), Vector3.ONE * 0.001)
		if character.grid_cell == start_cell: continue
		off_start += 1
		# Next door, through a passage
		assert_int(absi(character.grid_cell.x - start_cell.x) + absi(character.grid_cell.y - start_cell.y)).is_equal(1)
		assert_bool(_level.get_placed_tile(start_cell).has_connection_to(character.grid_cell)).is_true()
	assert_int(places.size()).is_equal(CROWD_SIZE + 1)
	# Five spots on the start tile: the other two go next door
	assert_int(off_start).is_equal(CROWD_SIZE + 1 - 5)

func test_any_character_spawned_onto_a_full_tile_goes_next_door() -> void:
	await _add_level()
	var players: Dictionary = Lobby.get("_players")
	# The host and four more fill the start tile's five spots
	for crowd_id: int in range(CROWD_FIRST_ID, CROWD_FIRST_ID + 4):
		var crowd_player: Player = auto_free(Player.create(crowd_id, "Crowd %d" % crowd_id))
		crowd_player.character = ModelFreeWorld.load_hero_profile()
		players[crowd_id] = crowd_player
	_spawner.start_synching_players()
	await await_idle_frame()
	var start_cell: Vector2i = _controller_of(Multiplayer.HOST_ID).character.grid_cell
	# E.g. an agent, created on the start tile's centre like characters used to be
	var piece: Character = auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D(Basis.IDENTITY, _level.grid_to_world_position(start_cell))))
	piece.level = _level
	add_child(piece)
	await await_idle_frame()
	assert_that(piece.grid_cell).is_not_equal(start_cell)
	assert_bool(_level.get_placed_tile(start_cell).has_connection_to(piece.grid_cell)).is_true()
