class_name ModelBounceAnimation
extends ModelAnimation

@export var _bounce_height: float = 1.0
@export var _side_tilt: float = 0.5

func animate(model: Model) -> void:
	var tween: Tween = model.create_tween()
	tween.set_parallel()
	tween.tween_property(model, "position:y", _bounce_height, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", 0.0, duration * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(duration * 0.5)
	var random_side_tilt: float = randf_range(-_side_tilt, _side_tilt)
	tween.tween_property(model, "rotation:x", -random_side_tilt, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "rotation:x", 0.0, duration * 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(duration * 0.5)
