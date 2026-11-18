extends GdUnitTestSuite
## The lobby menu gives the local player the hero picker however late their Player arrives, and forgets players who leave

const REMOTE_ID: int = 5

var _menu: LobbyMenu

func before_test() -> void:
	var menu_scene: PackedScene = load("uid://d3blbqb654ekr") # user_interface/menus/lobby_menu/lobby_guest_menu.tscn
	_menu = menu_scene.instantiate()
	# Its _ready starts the game, which creates the local player
	add_child(_menu)
	await await_idle_frame()

func after_test() -> void:
	_menu.queue_free()
	Client.stop_game()
	Lobby.hero_roster = null
	await await_idle_frame()

func test_the_local_player_picks_heroes() -> void:
	var picker: HeroPicker = _menu.get("_hero_picker")
	assert_object(picker.player).is_same(Lobby.get_local_player())

func test_a_local_player_arriving_late_still_picks_heroes() -> void:
	var local_player: Player = Lobby.get_local_player()
	var picker: HeroPicker = _menu.get("_hero_picker")
	var local_panel: LobbyPlayerPanel = _menu.get("_local_player_panel")
	# As on a guest whose own Player spawns after the menu is ready
	picker.player = null
	local_panel.player = null
	Lobby.player_created.emit(local_player)
	assert_object(picker.player).is_same(local_player)
	assert_object(local_panel.player).is_same(local_player)
	var panels: Dictionary = _menu.get("_player_panels")
	assert_bool(panels.has(local_player)).is_false()

func test_a_player_who_left_updates_no_preview() -> void:
	var player_info: Dictionary[StringName, Variant] = {Player.ID: REMOTE_ID, Player.NAME: "Remote"}
	Lobby.call("_on_player_joined", player_info)
	await await_idle_frame()
	var remote_player: Player = Lobby.get_player(REMOTE_ID)
	var update_preview: Callable = Callable(_menu, "_update_preview").bind(remote_player)
	assert_bool(remote_player.player_info_changed.is_connected(update_preview)).is_true()
	Lobby.call("_remove_player", remote_player)
	assert_bool(remote_player.player_info_changed.is_connected(update_preview)).is_false()
