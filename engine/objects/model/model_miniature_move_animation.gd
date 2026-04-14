class_name ModelMiniatureMoveAnimation
extends ModelAnimation

@export var _move_height: float = 1.25
@export var _tilt: float = -0.3
@export var _side_tilt: float = 0.5

func animate(model: Model) -> void:
	var tween: Tween = model.create_tween()
	tween.set_parallel()
	tween.tween_property(model, "position:y", _move_height, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "position:y", 0.0, duration * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(duration * 0.8)
	tween.tween_property(model, "rotation:x", _tilt, duration * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "rotation:x", 0.0, duration * 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(duration * 0.9)
	var random_side_tilt: float = pow(randf_range(-_side_tilt, _side_tilt), 2.0)
	tween.tween_property(model, "position:x", random_side_tilt, duration * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:x", 0.0, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(duration * 0.75)
	tween.tween_property(model, "rotation:z", random_side_tilt * 0.5, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:z", 0.0, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(duration * 0.5)
