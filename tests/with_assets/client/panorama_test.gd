extends GdUnitTestSuite
## The menus' backdrop: shown once loaded, not at all once cleared before that, kept when asked for again while it
## fades out, and no load left in the loader (the backdrop is the Polygon Dungeon demo, in assets/)

const BACKDROP: String = "res://user_interface/menus/menu_background.tscn"
const BROKEN_BACKDROP: String = "user://broken_backdrop_for_tests.tscn"
## Long enough for the demo to load after heavy test runs
const LOAD_TIMEOUT_SECONDS: float = 30.0

func before_test() -> void:
	await _start_clean()

func after_test() -> void:
	await _start_clean()
	DirAccess.remove_absolute(BROKEN_BACKDROP)

## No backdrop, no load waited for or given up on
func _start_clean() -> void:
	Panorama.clear_background()
	await _wait_until(func() -> bool: return _abandoned_loads() == 0)
	# A removed backdrop is freed at the end of the frame
	await await_idle_frame()

func _abandoned_loads() -> int:
	var abandoned_paths: Array[String] = Panorama.get("_abandoned_paths")
	return abandoned_paths.size()

## Waits by time, not by frames: headless frames run as fast as they can
func _wait_until(condition: Callable, seconds: float = LOAD_TIMEOUT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await await_idle_frame()
	return true

func test_the_backdrop_shows_once_loaded() -> void:
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()

func test_cleared_before_it_loaded_it_never_shows_nor_stays_in_the_loader() -> void:
	# E.g. the host pressing Start while the menu's backdrop still loads
	Panorama.set_background(BACKDROP)
	Panorama.clear_background()
	assert_bool(await _wait_until(func() -> bool: return _abandoned_loads() == 0)).is_true()
	assert_bool(Panorama.is_showing_panorama()).is_false()
	# Taken from the loader, so its resources are not held for the rest of the session
	assert_int(ResourceLoader.load_threaded_get_status(BACKDROP)).is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)

func test_asked_for_again_before_a_given_up_load_ended_it_shows() -> void:
	Panorama.set_background(BACKDROP)
	Panorama.clear_background()
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()

func test_asked_for_again_while_it_fades_out_it_stays() -> void:
	Panorama.set_background(BACKDROP)
	await _wait_until(Panorama.is_showing_panorama)
	Panorama.clear_background(true)
	Panorama.set_background(BACKDROP)
	await _wait_until(func() -> bool: return false, Panorama.FADE_OUT_DURATION + 0.5)
	assert_bool(Panorama.is_showing_panorama()).is_true()

func test_cleared_again_while_it_fades_out_it_goes_at_once() -> void:
	Panorama.set_background(BACKDROP)
	await _wait_until(Panorama.is_showing_panorama)
	Panorama.clear_background(true)
	Panorama.clear_background()
	assert_bool(Panorama.is_showing_panorama()).is_false()

func test_a_failed_backdrop_is_asked_for_anew() -> void:
	var file: FileAccess = FileAccess.open(BROKEN_BACKDROP, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n\nnot a scene at all\n")
	file.close()
	Panorama.set_background(BROKEN_BACKDROP)
	await _wait_until(func() -> bool: return Panorama.get("_requested_path") == "")
	assert_bool(Panorama.is_showing_panorama()).is_false()
	# Asking again requests it again instead of waiting for a failure that never changes
	Panorama.set_background(BROKEN_BACKDROP)
	assert_int(ResourceLoader.load_threaded_get_status(BROKEN_BACKDROP)).is_not_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	await _wait_until(func() -> bool: return Panorama.get("_requested_path") == "")
