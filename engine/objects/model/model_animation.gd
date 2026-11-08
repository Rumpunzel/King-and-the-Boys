@abstract
class_name ModelAnimation
extends Resource

@export var duration: float = 1.0

## @returns the tween playing the animation, e.g. to stretch it with [method Tween.set_speed_scale]
@abstract func animate(model: Model) -> Tween
