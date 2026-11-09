@abstract
class_name ModelAnimation
extends Resource

@export var duration: float = 1.0

## @returns the tween playing the animation, so it can be stopped
@abstract func animate(model: Model) -> Tween

## Plays on from where [param model] is, e.g. when a quick further step redirects a move under way.
## Animations without an own continuation play again.
func continue_animation(model: Model) -> Tween:
	return animate(model)
