extends Node

enum Execution {
	LOCAL,
	REMOTE,
}

enum SetupMode {
	PRE_CHANGE,
	POST_CHANGE,
}

const VALID_SCENE_FORMATS: Array[StringName] = ["tscn", "scn"]

@export var _loading_screen_scene: PackedScene = preload("uid://dmweuj7kxaxov")

var confirmed_transitions: int = -1

var _scene_path_to_load: String:
	set(new_scene_path_to_load):
		if new_scene_path_to_load.is_empty():
			_scene_path_to_load = new_scene_path_to_load
			set_process(false)
			return
		verify_scene_path(new_scene_path_to_load)
		_scene_path_to_load = new_scene_path_to_load
		if ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED: return
		ResourceLoader.load_threaded_request(_scene_path_to_load)

var _scene_setup: Callable
var _exection: Execution
var _setup_mode: SetupMode

var _loading_screen: LoadingScreen
var _progress_array: Array[float]

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	var loading_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_scene_path_to_load, _progress_array)
	assert(_progress_array.size() == 1)
	if _loading_screen: _loading_screen.set_loading_progress(_progress_array[0])
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED: _transition_to_scene(_scene_path_to_load)

## Only loads the scene into memory without transitioning
func preload_scene(scene_path: String) -> void:
	_scene_path_to_load = scene_path

## Loads the scene and transitions to it when it's ready
func transition_to_scene(scene_path: String, show_loading_screen: bool = true) -> void:
	_exection = Execution.LOCAL
	preload_scene(scene_path)
	if ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_transition_to_scene(scene_path)
		return
	set_process(true)
	if show_loading_screen: _show_loading_screen()

func transition_to_scene_with_setup(scene_path: String, scene_setup: Callable, setup_mode: SetupMode) -> void:
	_scene_setup = scene_setup
	_exection = Execution.LOCAL
	_setup_mode = setup_mode
	transition_to_scene(scene_path)

func to_main(show_loading_screen: bool = true) -> void:
	_exection = Execution.LOCAL
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert(not get_tree().current_scene or get_tree().current_scene.scene_file_path != main_scene_path)
	transition_to_scene(main_scene_path, show_loading_screen)

func verify_scene_path(scene_path: String) -> void:
	var path: String = ResourceUID.ensure_path(scene_path)
	assert(FileAccess.file_exists(path))
	assert(VALID_SCENE_FORMATS.has(path.get_extension()))

@rpc("call_remote", "reliable")
func transition_to_scene_remotely(scene_path: String) -> void:
	assert(confirmed_transitions == -1)
	confirmed_transitions = 0
	_exection = Execution.REMOTE
	preload_scene(scene_path)
	var scene_loaded: bool = ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED
	set_process(not scene_loaded)
	if scene_loaded: _transition_to_scene(scene_path)
	_show_loading_screen()

@rpc("any_peer", "call_local", "reliable")
func confirm_transition() -> void:
	assert(confirmed_transitions >= 0)
	confirmed_transitions += 1

@rpc("call_local", "reliable")
func reset_confirmed_transition() -> void:
	assert(confirmed_transitions >= 0)
	confirmed_transitions = -1

@rpc("call_local", "reliable")
func update_loading_screen(message: String) -> void:
	assert(_loading_screen)
	_loading_screen.set_loading_message(message)

@rpc("call_remote", "reliable")
func remove_loading_screen() -> void:
	assert(_loading_screen)
	remove_child(_loading_screen)
	_loading_screen.queue_free()

@rpc("call_remote", "reliable")
func _transition_new_peer_to_scene_remotely(scene_path: String) -> void:
	# Local execution as this is only called from the server, but a local loading screen
	_exection = Execution.LOCAL
	preload_scene(scene_path)
	var scene_loaded: bool = ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED
	set_process(not scene_loaded)
	if scene_loaded: _transition_to_scene(scene_path)
	else: _show_loading_screen("Joining Game")

func _transition_to_scene(scene_path: String) -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	assert(packed_scene)
	if scene_path == _scene_path_to_load: _scene_path_to_load = ""
	var scene_tree: SceneTree = get_tree()
	if _scene_setup.is_null():
		_transition_to_packed_scene(packed_scene)
		return
	assert(_exection == Execution.LOCAL)
	var scene: Node = packed_scene.instantiate()
	if _setup_mode == SetupMode.PRE_CHANGE: var error: Error = await _scene_setup.call(scene)
	scene_tree.change_scene_to_node(scene)
	await scene_tree.scene_changed
	if _setup_mode == SetupMode.POST_CHANGE: var error: Error = await _scene_setup.call(scene)
	_scene_setup = Callable()
	if _loading_screen: remove_loading_screen()

func _transition_to_packed_scene(packed_scene: PackedScene) -> void:
	var scene_tree: SceneTree = get_tree()
	scene_tree.change_scene_to_packed(packed_scene)
	if _exection == Execution.REMOTE:
		assert(_loading_screen)
		await scene_tree.scene_changed
		SceneManager.confirm_transition.rpc()
		return
	if _loading_screen:
		await scene_tree.scene_changed
		remove_loading_screen()

func _show_loading_screen(message: String = "Loading") -> void:
	assert(_loading_screen_scene)
	_loading_screen = _loading_screen_scene.instantiate()
	update_loading_screen(message)
	add_child(_loading_screen)

## When a peer connects, transition them to either the current scene or client version of the current scene.
func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var current_scene_path: String = get_tree().current_scene.scene_file_path
	var scene_path: String = current_scene_path
	var lobby_menu_scene_path: String = ResourceUID.ensure_path("uid://becdxlww4k13g")
	match current_scene_path:
		lobby_menu_scene_path:
			var lobby_guest_menu_scene_path: String = ResourceUID.ensure_path("uid://d3blbqb654ekr")
			scene_path = lobby_guest_menu_scene_path
	_transition_new_peer_to_scene_remotely.rpc_id(peer_id, scene_path)
