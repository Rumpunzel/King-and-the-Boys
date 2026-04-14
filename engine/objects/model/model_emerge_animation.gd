class_name ModelEmergeAnimation
extends ModelAnimation

@export var _emerge_depth: float = 1.0

func animate(model: Model) -> void:
	var tween: Tween = model.create_tween()
	tween.tween_property(model, "position:y", 0.0, duration).from(-_emerge_depth).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
