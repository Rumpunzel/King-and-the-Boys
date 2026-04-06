@tool
@icon("uid://cl8p01b5kagvw")
extends Node3D

signal zoom_value_changed(zoom_value: float)
signal tilt_value_changed(tilt_value: float)

@export var _follow_distance_min = 1.0
@export var _follow_distance_max = 8.0
@export var _zoom_rate: float = 0.25
@export var _zoom_time: float = 0.1

@export_custom(PROPERTY_HINT_RANGE, "0.0,360.0,suffix:°") var _turn_increment_min: float = 2.0
@export_custom(PROPERTY_HINT_RANGE, "0.0,360.0,suffix:°") var _turn_increment_max: float = 32.0
@export var _turn_time: float = 0.1

@export var _tilt_min = 0.0
@export var _tilt_max = 4.0
@export var _tilt_rate: float = 0.05
@export var _tilt_time: float = 0.1

@export var _look_at_time: float = 0.1

@export var _view_target: PreviewModel

@export_group("Configuration")
@export var _camera: Camera3D

var _target_rotation: float = 0.0:
	set(new_target_rotation):
		_target_rotation = new_target_rotation
		if _rotation_tween: _rotation_tween.kill()
		if not get_tree(): return
		_rotation_tween = get_tree().create_tween()
		_rotation_tween.tween_property(self, "rotation_degrees:y", _target_rotation, _turn_time)

var _target_follow_distance: float = _follow_distance_min:
	set(new_target_follow_distance):
		_target_follow_distance = new_target_follow_distance
		var reverse_tilt: float = 1.1 - ((_target_tilt - _tilt_min) / (_tilt_max - _tilt_min))
		var new_follow_position: Vector3 = _view_target.global_position + Vector3(reverse_tilt, _target_tilt, reverse_tilt) * _target_follow_distance
		_camera.position = new_follow_position

var _target_tilt: float = _tilt_min:
	set(new_target_tilt):
		_target_tilt = new_target_tilt
		_target_follow_distance = _target_follow_distance

var _rotation_tween: Tween

func _ready() -> void:
	_target_rotation = fmod(abs(rotation_degrees.y), 180.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var look_at_position: Vector3 = (_view_target.global_position + _view_target.get_heads_up_anchor()) / 2.0
	_camera.look_at(look_at_position)

func _calculate_turn_increment() -> float:
	var turn_modifier: float = 1.0 + fmod(abs(_target_rotation - rotation_degrees.y), 180.0)
	return clampf(turn_modifier, _turn_increment_min, _turn_increment_max)

func _on_model_preview_zoom_changed(new_zoom: float) -> void:
	var follow_distance: float = _follow_distance_min + new_zoom * _follow_distance_max
	_target_follow_distance = follow_distance

func _on_model_preview_zoomed_out() -> void:
	_target_follow_distance = minf(_target_follow_distance + _zoom_rate, _follow_distance_max)
	var zoom_ratio: float = (_target_follow_distance - _follow_distance_min) / (_follow_distance_max - _follow_distance_min)
	zoom_value_changed.emit(zoom_ratio)

func _on_model_preview_zoomed_in() -> void:
	_target_follow_distance = maxf(_target_follow_distance - _zoom_rate, _follow_distance_min)
	var zoom_ratio: float = (_target_follow_distance - _follow_distance_min) / (_follow_distance_max - _follow_distance_min)
	zoom_value_changed.emit(zoom_ratio)

func _on_model_preview_turned_left() -> void:
	_target_rotation += _calculate_turn_increment()

func _on_model_preview_turned_right() -> void:
	_target_rotation -= _calculate_turn_increment()

func _on_model_preview_tilt_changed(new_tilt: float) -> void:
	var tilt: float = _tilt_min + new_tilt * _tilt_max
	_target_tilt = tilt

func _on_model_preview_tilted_more() -> void:
	_target_tilt = minf(_target_tilt + _tilt_rate, _tilt_max)
	var tilt_ratio: float = (_target_tilt - _tilt_min) / (_tilt_max - _tilt_min)
	tilt_value_changed.emit(tilt_ratio)

func _on_model_preview_tilted_less() -> void:
	_target_tilt = maxf(_target_tilt - _tilt_rate, _tilt_min)
	var tilt_ratio: float = (_target_tilt - _tilt_min) / (_tilt_max - _tilt_min)
	tilt_value_changed.emit(tilt_ratio)

func _on_sky_box_changed(new_sky_box: PanoramaSkyMaterial) -> void:
	_camera.environment.sky.sky_material = new_sky_box

func _on_model_preview_visibility_changed() -> void:
	visible = owner.is_visible_in_tree()
