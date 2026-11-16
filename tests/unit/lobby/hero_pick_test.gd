extends GdUnitTestSuite
## The Lobby decides hero picks and ready: a joining player gets a free hero, a hero is held by one player at a time,
## ready players keep theirs, and a game starts only once every peer's player is ready

const JOINING_ID: int = 5
const SECOND_ID: int = 6
const PEER_WITHOUT_PLAYER: int = 7

## The two model-free fixture heroes (res://tests/fixtures/heroes.tres)
const HEROES: String = "uid://ddcr4k3p6t8nw"

func before_test() -> void:
	var roster: HeroRoster = load(HEROES)
	Lobby.hero_roster = roster
	Lobby.picks_open = true

func after_test() -> void:
	for player_id: int in [JOINING_ID, SECOND_ID]:
		var joined: Player = Lobby.get_player(player_id)
		if joined: Lobby.call("_remove_player", joined)
	Lobby.hero_roster = null
	Lobby.picks_open = true
	await await_idle_frame()

func _join(player_id: int) -> Player:
	var player_info: Dictionary[StringName, Variant] = {Player.ID: player_id, Player.NAME: "Joining %d" % player_id}
	Lobby.call("_on_player_joined", player_info)
	await await_idle_frame()
	return Lobby.get_player(player_id)

func _get_other_hero(than: CharacterProfile) -> CharacterProfile:
	for hero: CharacterProfile in Lobby.hero_roster.heroes:
		if hero != than: return hero
	return null

func test_a_joining_player_gets_a_free_hero() -> void:
	var a: Player = await _join(JOINING_ID)
	var b: Player = await _join(SECOND_ID)
	assert_bool(Lobby.hero_roster.has(a.character)).is_true()
	assert_bool(Lobby.hero_roster.has(b.character)).is_true()
	assert_object(a.character).is_not_same(b.character)

func test_a_free_hero_is_granted() -> void:
	var a: Player = await _join(JOINING_ID)
	var b: Player = await _join(SECOND_ID)
	var freed: CharacterProfile = b.character
	Lobby.call("_on_peer_disconnected", SECOND_ID)
	assert_bool(Lobby.try_pick(a, freed)).is_true()
	assert_object(a.character).is_same(freed)

func test_a_taken_hero_is_refused() -> void:
	var a: Player = await _join(JOINING_ID)
	var b: Player = await _join(SECOND_ID)
	var own: CharacterProfile = b.character
	assert_bool(Lobby.try_pick(b, a.character)).is_false()
	assert_object(b.character).is_same(own)

func test_the_own_hero_is_accepted() -> void:
	var a: Player = await _join(JOINING_ID)
	assert_bool(Lobby.try_pick(a, a.character)).is_true()

func test_a_hero_outside_the_roster_is_refused() -> void:
	var a: Player = await _join(JOINING_ID)
	var own: CharacterProfile = a.character
	assert_bool(Lobby.try_pick(a, CharacterProfile.new())).is_false()
	assert_object(a.character).is_same(own)

func test_a_ready_player_cannot_change_hero() -> void:
	var a: Player = await _join(JOINING_ID)
	var own: CharacterProfile = a.character
	var free: CharacterProfile = _get_other_hero(own)
	a.ready_to_start = true
	assert_bool(Lobby.try_pick(a, free)).is_false()
	assert_object(a.character).is_same(own)

func test_ready_is_refused_offline() -> void:
	var a: Player = await _join(JOINING_ID)
	assert_bool(Lobby.try_set_ready(a, true)).is_false()
	assert_bool(a.ready_to_start).is_false()

func test_picks_are_refused_once_closed() -> void:
	var a: Player = await _join(JOINING_ID)
	var own: CharacterProfile = a.character
	Lobby.close_picks()
	assert_bool(Lobby.try_pick(a, _get_other_hero(own))).is_false()
	assert_object(a.character).is_same(own)
	var late: Player = await _join(SECOND_ID)
	assert_object(late.character).is_null()

func test_a_leaving_player_frees_their_hero() -> void:
	var a: Player = await _join(JOINING_ID)
	var b: Player = await _join(SECOND_ID)
	var old_hero: CharacterProfile = b.character
	Lobby.call("_on_peer_disconnected", SECOND_ID)
	assert_object(Lobby.get_holder(old_hero)).is_null()
	assert_array(Lobby.get_free_heroes(a)).contains([old_hero])

func test_start_waits_for_a_peer_without_a_player() -> void:
	var a: Player = await _join(JOINING_ID)
	a.ready_to_start = true
	assert_bool(Lobby.call("_can_start_with", PackedInt32Array([JOINING_ID]))).is_true()
	assert_bool(Lobby.call("_can_start_with", PackedInt32Array([JOINING_ID, PEER_WITHOUT_PLAYER]))).is_false()
	a.ready_to_start = false
	assert_bool(Lobby.call("_can_start_with", PackedInt32Array([JOINING_ID]))).is_false()

func test_start_is_allowed_offline() -> void:
	assert_bool(Lobby.can_start()).is_true()
