extends GdUnitTestSuite
## The host counts which peers show the scene it sent everyone to

func after_test() -> void:
	SceneManager.begin_confirmations()

func test_the_host_confirms_itself() -> void:
	var host_id: int = SceneManager.multiplayer.get_unique_id()
	SceneManager.begin_confirmations()
	assert_bool(SceneManager.has_confirmed(host_id)).is_false()
	SceneManager.confirm_transition()
	assert_bool(SceneManager.has_confirmed(host_id)).is_true()

func test_a_new_transition_starts_counting_again() -> void:
	var host_id: int = SceneManager.multiplayer.get_unique_id()
	SceneManager.confirm_transition()
	SceneManager.begin_confirmations()
	assert_bool(SceneManager.has_confirmed(host_id)).is_false()

func test_confirming_tells_who() -> void:
	var confirmed: Array[int] = []
	var record: Callable = func(peer_id: int) -> void: confirmed.append(peer_id)
	SceneManager.transition_confirmed.connect(record)
	SceneManager.begin_confirmations()
	SceneManager.confirm_transition()
	SceneManager.transition_confirmed.disconnect(record)
	assert_array(confirmed).contains_exactly([SceneManager.multiplayer.get_unique_id()])
