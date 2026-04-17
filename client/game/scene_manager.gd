extends Node

enum SetupMode {
	PRE_CHANGE,
	POST_CHANGE,
}

@export var _loading_screen_scene: PackedScene = preload("uid://dmweuj7kxaxov")

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
var _setup_mode: SetupMode

var _loading_screen: LoadingScreen
var _progress_array: Array[float]

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	var loading_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_scene_path_to_load, _progress_array)
	assert(_progress_array.size() == 1)
	_loading_screen.set_loading_progress(_progress_array[0])
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED: _transition_to_scene(_scene_path_to_load)

func verify_scene_path(scene_path: String) -> void:
	var path: String = ResourceUID.ensure_path(scene_path)
	assert(FileAccess.file_exists(path))
	assert(path.get_extension() == "tscn")

## Only loads the scene into memory without transitioning
func preload_scene(scene_path: String) -> void:
	_scene_path_to_load = scene_path

## Loads the scene and transitions to it when it's ready
@rpc("call_local", "reliable")
func transition_to_scene(scene_path: String) -> void:
	preload_scene(scene_path)
	if ResourceLoader.load_threaded_get_status(_scene_path_to_load) == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_transition_to_scene(scene_path)
		return
	assert(_loading_screen_scene)
	_loading_screen = _loading_screen_scene.instantiate()
	add_child(_loading_screen)
	set_process(true)

@rpc("call_local", "reliable")
func transition_to_scene_with_setup(scene_path: String, scene_setup: Callable, setup_mode: SetupMode) -> void:
	_scene_setup = scene_setup
	_setup_mode = setup_mode
	transition_to_scene(scene_path)

func to_main() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert(not get_tree().current_scene or get_tree().current_scene.scene_file_path != main_scene_path)
	transition_to_scene(main_scene_path)

func _transition_to_scene(scene_path: String) -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	assert(packed_scene)
	if scene_path == _scene_path_to_load: _scene_path_to_load = ""
	var scene_tree: SceneTree = get_tree()
	if _scene_setup.is_null():
		scene_tree.change_scene_to_packed(packed_scene)
		if not _loading_screen: return
		await scene_tree.scene_changed
		remove_child(_loading_screen)
		_loading_screen.queue_free()
	else:
		var scene: Node = packed_scene.instantiate()
		if _setup_mode == SetupMode.PRE_CHANGE: var error: Error = await _scene_setup.call(scene)
		scene_tree.change_scene_to_node(scene)
		await scene_tree.scene_changed
		if _setup_mode == SetupMode.POST_CHANGE: var error: Error = await _scene_setup.call(scene)
		_scene_setup = Callable()
		if not _loading_screen: return
		remove_child(_loading_screen)
		_loading_screen.queue_free()
