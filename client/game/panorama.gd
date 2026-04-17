@tool
@icon("uid://bgjmcb04v358t")
extends CanvasLayer

@export_group("Configuration")
@export var _background_placeholder: Control

var _background_scene_path: String:
	set(new_background_scene_path):
		if new_background_scene_path.is_empty():
			_background_scene_path = new_background_scene_path
			set_process(false)
			return
		SceneManager.verify_scene_path(new_background_scene_path)
		_background_scene_path = new_background_scene_path
		if ResourceLoader.load_threaded_get_status(_background_scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			return
		ResourceLoader.load_threaded_request(_background_scene_path)
		set_process(true)

var _background_scene: Node

@onready var _tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not _background_scene_path.is_empty(): ResourceLoader.load_threaded_request(_background_scene_path)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not _background_scene_path.is_empty() and not _background_scene: _load_background_scene_when_ready()

func set_background(background_scene_path: String) -> void:
	if _background_scene: clear_background(true)
	assert(_background_placeholder)
	if not _background_placeholder.visible: _background_placeholder.modulate.a = 1.0
	_background_placeholder.visible = true
	_background_scene_path = background_scene_path

func clear_background(fade_out: bool = false) -> void:
	if _tween: _tween.kill()
	if fade_out:
		_tween = create_tween()
		_tween.tween_property(_background_placeholder, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _tween.finished
	else:
		_background_placeholder.visible = false
	remove_child(_background_scene)
	_background_scene.queue_free()
	_background_scene = null

func _load_background_scene_when_ready() -> void:
	if not ResourceLoader.load_threaded_get_status(_background_scene_path) == ResourceLoader.THREAD_LOAD_LOADED: return
	var background_scene: PackedScene = ResourceLoader.load_threaded_get(_background_scene_path)
	_background_scene = background_scene.instantiate()
	add_child(_background_scene)
	_tween = create_tween()
	_tween.tween_property(_background_placeholder, "modulate:a", 0.0, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_background_scene_path = ""

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _background_placeholder: warnings.append("Missing background placeholder reference.")
	return warnings
