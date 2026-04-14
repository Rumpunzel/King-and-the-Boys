class_name ModelSlideAnimation
extends ModelAnimation

@export_enum("x", "y", "z") var _axis: String
@export var _slide_distance: float = 1.0

func animate(model: Model) -> void:
	var tween: Tween = model.create_tween()
	tween.tween_property(model, "position:%s" % _axis, 0.0, duration).from(_slide_distance).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
