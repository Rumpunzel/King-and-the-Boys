extends GdUnitTestSuite
## The host waits for the peers it sent to a scene: those that confirm it, minus those that leave

const SCENE_PATH: String = "res://engine/game.tscn"
const OTHER_PEER_ID: int = 2

var _progress: Array[Vector2i] = []
var _completions: Array[bool] = []

func before_test() -> void:
	_progress.clear()
	_completions.clear()
	SceneManager.transition_progressed.connect(_on_progressed)
	SceneManager.transition_completed.connect(_on_completed)

func after_test() -> void:
	SceneManager.transition_progressed.disconnect(_on_progressed)
	SceneManager.transition_completed.disconnect(_on_completed)
	SceneManager.end_transition()

func _on_progressed(ready_count: int, expected_count: int) -> void:
	_progress.append(Vector2i(ready_count, expected_count))

func _on_completed() -> void:
	_completions.append(true)

func _expect_other_peer() -> void:
	var expected_peers: Dictionary = SceneManager.get("_expected_peers")
	expected_peers[OTHER_PEER_ID] = true

func test_the_host_alone_completes_once_it_confirms() -> void:
	SceneManager.transition_everyone_to(SCENE_PATH)
	assert_bool(SceneManager.is_transition_complete()).is_false()
	SceneManager.confirm_transition(SCENE_PATH)
	assert_bool(SceneManager.is_transition_complete()).is_true()
	assert_array(_progress).contains_exactly([Vector2i(1, 1)])
	assert_int(_completions.size()).is_equal(1)

func test_confirming_another_scene_counts_for_nothing() -> void:
	SceneManager.transition_everyone_to(SCENE_PATH)
	SceneManager.confirm_transition("res://user_interface/menus/main_menu/main_menu.tscn")
	assert_bool(SceneManager.is_transition_complete()).is_false()
	assert_array(_progress).is_empty()

func test_confirming_twice_counts_once() -> void:
	SceneManager.transition_everyone_to(SCENE_PATH)
	_expect_other_peer()
	SceneManager.confirm_transition(SCENE_PATH)
	SceneManager.confirm_transition(SCENE_PATH)
	assert_array(_progress).contains_exactly([Vector2i(1, 2)])
	assert_int(_completions.size()).is_equal(0)

func test_a_peer_that_leaves_is_not_waited_for() -> void:
	SceneManager.transition_everyone_to(SCENE_PATH)
	_expect_other_peer()
	SceneManager.confirm_transition(SCENE_PATH)
	SceneManager.call("_on_peer_disconnected", OTHER_PEER_ID)
	assert_bool(SceneManager.is_transition_complete()).is_true()
	assert_array(_progress).contains_exactly([Vector2i(1, 2), Vector2i(1, 1)])
	assert_int(_completions.size()).is_equal(1)

func test_peers_not_sent_there_do_not_count() -> void:
	SceneManager.transition_everyone_to(SCENE_PATH)
	# A peer that left before is no longer awaited, and nobody else is
	SceneManager.call("_on_peer_disconnected", OTHER_PEER_ID)
	assert_array(_progress).is_empty()
