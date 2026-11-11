@icon("uid://bgjmcb04v358t")
extends CanvasLayer
## The menus' 3D backdrop: loads a scene on a thread, fades it in from behind a black placeholder and out again.
## Every load it requests is taken from the loader once it ends, also when nobody waits for it any more, so a
## backdrop given up on does not stay in memory.

const FADE_IN_DURATION: float = 5.0
const FADE_OUT_DURATION: float = 1.0

var _background_placeholder: ColorRect
var _background_scene: Node
# The backdrop asked for and not shown yet; empty if none is
var _requested_path: String = ""
# Loads nobody waits for any more (cleared or replaced), taken once they end
var _abandoned_paths: Array[String] = []
# The backdrop the running fade-out removes at its end, if one runs
var _fading_out_scene: Node
var _tween: Tween

func _ready() -> void:
	layer = -100
	_background_placeholder = ColorRect.new()
	_background_placeholder.color = Color.BLACK
	_background_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_placeholder)

func _process(_delta: float) -> void:
	_take_abandoned_loads()
	if not _requested_path.is_empty(): _show_when_loaded()
	if _requested_path.is_empty() and _abandoned_paths.is_empty(): set_process(false)

func is_showing_panorama() -> bool: return _background_scene != null

func set_background(background_scene_path: String) -> void:
	SceneManager.verify_scene_path(background_scene_path)
	var scene_file_path: String = ResourceUID.ensure_path(background_scene_path)
	if _background_scene and _background_scene.scene_file_path == scene_file_path:
		# Asked for again while it fades out: it stays
		if _fading_out_scene == _background_scene: _cancel_fade_out()
		return
	if not _requested_path.is_empty() and ResourceUID.ensure_path(_requested_path) == scene_file_path: return
	if _background_scene: clear_background(true)
	_abandon_request()
	assert(_background_placeholder)
	if not _background_placeholder.visible: _background_placeholder.modulate.a = 1.0
	_background_placeholder.visible = true
	_abandoned_paths.erase(background_scene_path)
	_requested_path = background_scene_path
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(background_scene_path)
	# A load under way or done is shown by _process all the same; one that failed is taken and asked for again
	if status == ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(background_scene_path)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(background_scene_path)
	set_process(true)

## Removes the backdrop, at once or fading to black first; a backdrop still loading is not shown
@rpc("call_local", "reliable")
func clear_background(fade_out: bool = false) -> void:
	_abandon_request()
	if _tween: _tween.kill()
	if fade_out and _background_scene:
		_fading_out_scene = _background_scene
		# A callback at the tween's end, not an await: a tween killed meanwhile leaves nothing waiting
		_tween = create_tween()
		_tween.tween_property(_background_placeholder, "modulate:a", 1.0, FADE_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_remove_scene)
		return
	if not fade_out: _background_placeholder.visible = false
	_remove_scene()

func _show_when_loaded() -> void:
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_requested_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	var path: String = _requested_path
	_requested_path = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Failed to load the backdrop %s" % path)
		# Taken, so that asking for it again requests it anew
		if status == ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(path)
		return
	var background_scene: PackedScene = ResourceLoader.load_threaded_get(path)
	# The backdrop it replaces may still fade out
	if _fading_out_scene: _remove_scene()
	if _tween: _tween.kill()
	_background_scene = background_scene.instantiate()
	add_child(_background_scene)
	_background_placeholder.visible = true
	_tween = create_tween()
	_tween.tween_property(_background_placeholder, "modulate:a", 0.0, FADE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _cancel_fade_out() -> void:
	if _tween: _tween.kill()
	_fading_out_scene = null
	_tween = create_tween()
	_tween.tween_property(_background_placeholder, "modulate:a", 0.0, FADE_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _remove_scene() -> void:
	_fading_out_scene = null
	if not _background_scene: return
	remove_child(_background_scene)
	_background_scene.queue_free()
	_background_scene = null

func _abandon_request() -> void:
	if _requested_path.is_empty(): return
	if not _abandoned_paths.has(_requested_path): _abandoned_paths.append(_requested_path)
	_requested_path = ""
	set_process(true)

func _take_abandoned_loads() -> void:
	for path: String in _abandoned_paths.duplicate():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(path)
		_abandoned_paths.erase(path)
