extends GdUnitTestSuite
## Loading screens are added and removed in one place (its background lies in protoype_assets/)

func after_test() -> void:
	SceneManager.remove_loading_screen()
	await await_idle_frame()

func _loading_screens() -> int:
	return SceneManager.get_children().filter(func(child: Node) -> bool: return child is LoadingScreen).size()

func test_a_message_alone_shows_no_screen() -> void:
	# E.g. a peer already in the game when the host tells the others it is generating
	SceneManager.update_loading_screen("Generating")
	assert_int(_loading_screens()).is_equal(0)

func test_showing_again_keeps_one_screen() -> void:
	SceneManager.show_loading_screen("Waiting")
	SceneManager.show_loading_screen("Generating")
	assert_int(_loading_screens()).is_equal(1)

func test_removing_twice_is_harmless() -> void:
	SceneManager.show_loading_screen()
	SceneManager.remove_loading_screen()
	SceneManager.remove_loading_screen()
	await await_idle_frame()
	assert_int(_loading_screens()).is_equal(0)
