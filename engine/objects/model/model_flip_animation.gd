class_name ModelFlipAnimation
extends ModelAnimation

@export var _flip_height: float = 1.0

func animate(model: Model) -> void:
	var tween: Tween = model.create_tween()
	tween.set_parallel()
	tween.tween_property(model, "position:y", _flip_height, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:x", 0.0, duration).from(PI).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", 0.0, duration * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(duration * 0.5)
