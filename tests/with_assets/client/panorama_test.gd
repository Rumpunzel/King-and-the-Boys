extends GdUnitTestSuite
## The menus' backdrop: shown once loaded, and not at all once cleared before that (the backdrop is the Polygon
## Dungeon demo, in assets/)

const BACKDROP: String = "res://user_interface/menus/menu_background.tscn"

func after_test() -> void:
	Panorama.clear_background()
	await await_idle_frame()

func _wait_until_loaded() -> void:
	for _frame: int in 600:
		if ResourceLoader.load_threaded_get_status(BACKDROP) != ResourceLoader.THREAD_LOAD_IN_PROGRESS: break
		await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()

func test_the_backdrop_shows_once_loaded() -> void:
	Panorama.set_background(BACKDROP)
	await _wait_until_loaded()
	assert_bool(Panorama.is_showing_panorama()).is_true()

func test_cleared_before_it_loaded_it_never_shows() -> void:
	# E.g. the host pressing Start while the menu's backdrop still loads
	Panorama.set_background(BACKDROP)
	Panorama.clear_background()
	await _wait_until_loaded()
	assert_bool(Panorama.is_showing_panorama()).is_false()

func test_asked_for_again_once_loaded_it_still_shows() -> void:
	Panorama.set_background(BACKDROP)
	Panorama.clear_background()
	await _wait_until_loaded()
	# The load is done but nobody took it: asking again has to take it, not wait for a load that already ended
	Panorama.set_background(BACKDROP)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(Panorama.is_showing_panorama()).is_true()
