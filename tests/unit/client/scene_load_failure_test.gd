extends GdUnitTestSuite
## A scene that fails to load drops the transition and says so, instead of being polled forever

const BROKEN_SCENE: String = "user://broken_scene_for_tests.tscn"

func before_test() -> void:
	var file: FileAccess = FileAccess.open(BROKEN_SCENE, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n\nnot a scene at all\n")
	file.close()

func after_test() -> void:
	DirAccess.remove_absolute(BROKEN_SCENE)

func test_a_failed_load_stops_and_tells() -> void:
	var failed: Array[String] = []
	var record: Callable = func(scene_path: String) -> void: failed.append(scene_path)
	SceneManager.scene_load_failed.connect(record)
	var scene_before: Node = get_tree().current_scene
	SceneManager.transition_to_scene(BROKEN_SCENE, false)
	for _frame: int in 60:
		if not failed.is_empty(): break
		await await_idle_frame()
	SceneManager.scene_load_failed.disconnect(record)
	assert_array(failed).contains_exactly([BROKEN_SCENE])
	assert_bool(SceneManager.is_processing()).is_false()
	# Offline it stays where it was
	assert_object(get_tree().current_scene).is_same(scene_before)

func test_online_the_host_stops_hosting_forgets_the_transition_and_heads_for_the_main_menu() -> void:
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_int(server.create_server(47123)).is_equal(OK)
	SceneManager.multiplayer.multiplayer_peer = server
	assert_bool(Multiplayer.is_online()).is_true()
	SceneManager.transition_everyone_to(BROKEN_SCENE)
	SceneManager.transition_to_scene(BROKEN_SCENE, false)
	for _frame: int in 60:
		if not Multiplayer.is_online(): break
		await await_idle_frame()
	# Nobody else took the host to the main menu here: SceneManager heads there itself; stopped before it gets there
	var heading_for: String = SceneManager.get("_scene_path_to_load")
	SceneManager.set("_scene_path_to_load", "")
	assert_bool(Multiplayer.is_online()).is_false()
	assert_array(SceneManager.get_transitioning_peers()).is_empty()
	assert_str(heading_for).is_equal(SceneManager.get_main_scene_path())
