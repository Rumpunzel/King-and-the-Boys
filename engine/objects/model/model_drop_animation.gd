class_name ModelDropAnimation
extends ModelAnimation

## Falls in from above, speeding up like a heavy piece, and settles with a small rebound, e.g. pillars and arches

@export var _drop_height: float = 6.0
## How far it springs back up after hitting the floor
@export var _rebound_height: float = 0.06

func animate(model: Model) -> Tween:
	var tween: Tween = model.create_tween()
	tween.tween_property(model, "position:y", 0.0, duration * 0.6).from(_drop_height).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "position:y", _rebound_height, duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", 0.0, duration * 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return tween
