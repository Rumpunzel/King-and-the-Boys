extends Node

## Host only: a peer confirmed it shows the scene the host sent everyone to, see [method confirm_transition]
signal transition_confirmed(peer_id: int)

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

# Host only: the peers that confirmed the current transition
var _confirmed_peers: Dictionary[int, bool] = {}

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

## Host only: starts counting confirmations for a transition everyone takes, see [method has_confirmed]
func begin_confirmations() -> void:
	assert(multiplayer.is_server())
	_confirmed_peers.clear()

## Host only: whether [param peer_id] shows the scene of the transition since [method begin_confirmations]
func has_confirmed(peer_id: int) -> bool:
	return _confirmed_peers.has(peer_id)

@rpc("call_remote", "reliable")
func transition_to_scene_remotely(scene_path: String) -> void:
	_exection = Execution.REMOTE
	# Shown before the change: a scene loaded already changes at once and confirms on the way
	_show_loading_screen()
	preload_scene(scene_path)
	var scene_loaded: bool = ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED
	set_process(not scene_loaded)
	if scene_loaded: _transition_to_scene(scene_path)

## Tells the host the sender shows the scene now; the host calls it for itself
@rpc("any_peer", "call_local", "reliable")
func confirm_transition() -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = multiplayer.get_unique_id()
	_confirmed_peers[sender_id] = true
	transition_confirmed.emit(sender_id)

## Shows [param message] on the loading screen, which is shown if it is not yet
@rpc("call_local", "reliable")
func update_loading_screen(message: String) -> void:
	if not _loading_screen:
		_show_loading_screen(message)
		return
	_loading_screen.set_loading_message(message)

@rpc("call_remote", "reliable")
func remove_loading_screen() -> void:
	if not _loading_screen: return
	remove_child(_loading_screen)
	_loading_screen.queue_free()
	_loading_screen = null

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
		await scene_tree.scene_changed
		confirm_transition.rpc_id(Multiplayer.HOST_ID)
		return
	if _loading_screen:
		await scene_tree.scene_changed
		remove_loading_screen()

func _show_loading_screen(message: String = "Loading") -> void:
	assert(_loading_screen_scene)
	if not _loading_screen:
		_loading_screen = _loading_screen_scene.instantiate()
		add_child(_loading_screen)
	_loading_screen.set_loading_message(message)

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
