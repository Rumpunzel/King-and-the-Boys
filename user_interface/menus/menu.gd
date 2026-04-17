@abstract
class_name Menu
extends PanelContainer

signal opened
signal fully_opened
signal closed
signal fully_closed

enum Start {
	INVISIBLE = -1,
	FADE_IN,
	VISIBLE,
}

@export var _fade_in_duration: float = 0.1
@export var _fade_out_duration: float = 0.25
@export var _start: Start = Start.FADE_IN

var _tween: Tween

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	visible = _start >= Start.VISIBLE
	if _start <= Start.FADE_IN: modulate.a = 0.0
	if _start >= Start.FADE_IN: open_menu()

func open_menu() -> void:
	if visible: return
	get_tree().call_group("HUD", "hide")
	show()
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, _fade_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_callback(fully_opened.emit)
	opened.emit()

func close_menu() -> void:
	if not visible: return
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, _fade_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_callback(hide)
	_tween.tween_callback(get_tree().call_group.bind("HUD", "show"))
	_tween.tween_callback(fully_closed.emit)
	closed.emit()
