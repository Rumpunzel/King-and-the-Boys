extends GdUnitTestSuite
## The menus' backdrop: shown once loaded, not at all once cleared before that, kept when asked for again while it
## fades out, and no load left in the loader (the backdrop is the Polygon Dungeon demo, in assets/)

const BACKDROP: String = "res://user_interface/menus/menu_background.tscn"
## A small scene standing in for a second backdrop
const OTHER_BACKDROP: String = "res://user_interface/loading_screen/loading_bar.tscn"
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
	assert_bool(await _wait_until(func() -> bool: return _abandoned_loads() == 0)).is_true()
	# A removed backdrop is freed at the end of the frame
	await await_idle_frame()

func _abandoned_loads() -> int:
	var abandoned_paths: Array[String] = Panorama.get("_abandoned_paths")
	return abandoned_paths.size()

func _is_waiting_for_a_load() -> bool:
	var requested_path: String = Panorama.get("_requested_path")
	return not requested_path.is_empty()

## Backdrops in the tree, the placeholder aside
func _backdrops() -> int:
	return Panorama.get_children().filter(func(child: Node) -> bool: return not child is ColorRect and not child.is_queued_for_deletion()).size()

func _placeholder() -> ColorRect:
	return Panorama.get("_background_placeholder")

## Waits by time, not by frames: headless frames run as fast as they can
func _wait_until(condition: Callable, seconds: float = LOAD_TIMEOUT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await await_idle_frame()
	return true

func _wait_for(seconds: float) -> void:
	await _wait_until(func() -> bool: return false, seconds)

func test_the_backdrop_shows_once_loaded() -> void:
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()

func test_asked_for_by_uid_and_by_path_it_is_one_backdrop() -> void:
	# The main menu asks by uid://
	var uid: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(BACKDROP))
	Panorama.set_background(uid)
	Panorama.clear_background()
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

func test_faded_out_before_it_loaded_nothing_stays_black() -> void:
	Panorama.set_background(BACKDROP)
	Panorama.clear_background(true)
	assert_bool(_placeholder().visible).is_false()

func test_asked_for_again_before_a_given_up_load_ended_it_shows() -> void:
	Panorama.set_background(BACKDROP)
	Panorama.clear_background()
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()

func test_asked_for_again_while_it_fades_out_it_stays() -> void:
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()
	Panorama.clear_background(true)
	Panorama.set_background(BACKDROP)
	await _wait_for(Panorama.FADE_OUT_DURATION + 0.5)
	assert_bool(Panorama.is_showing_panorama()).is_true()

func test_back_to_the_shown_one_before_another_loaded_shows_one_backdrop() -> void:
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()
	Panorama.set_background(OTHER_BACKDROP)
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(func() -> bool: return _abandoned_loads() == 0 and not _is_waiting_for_a_load())).is_true()
	await _wait_for(Panorama.FADE_OUT_DURATION + 0.5)
	assert_int(_backdrops()).is_equal(1)
	assert_bool(Panorama.is_showing_panorama()).is_true()

func test_cleared_again_while_it_fades_out_it_goes_at_once() -> void:
	Panorama.set_background(BACKDROP)
	assert_bool(await _wait_until(Panorama.is_showing_panorama)).is_true()
	Panorama.clear_background(true)
	Panorama.clear_background()
	assert_bool(Panorama.is_showing_panorama()).is_false()

func test_a_failed_backdrop_is_asked_for_anew() -> void:
	var file: FileAccess = FileAccess.open(BROKEN_BACKDROP, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n\nnot a scene at all\n")
	file.close()
	Panorama.set_background(BROKEN_BACKDROP)
	assert_bool(await _wait_until(func() -> bool: return not _is_waiting_for_a_load())).is_true()
	assert_bool(Panorama.is_showing_panorama()).is_false()
	assert_int(ResourceLoader.load_threaded_get_status(BROKEN_BACKDROP)).is_equal(ResourceLoader.THREAD_LOAD_FAILED)
	# Asking again tries anew instead of waiting for a failure that never changes
	Panorama.set_background(BROKEN_BACKDROP)
	assert_bool(_is_waiting_for_a_load()).is_true()
	assert_bool(await _wait_until(func() -> bool: return not _is_waiting_for_a_load())).is_true()
