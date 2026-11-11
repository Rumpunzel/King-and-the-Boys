@tool
@icon("uid://ba48wfee2hq2x")
class_name ModelMiniatureMoveAnimation
extends ModelAnimation

## A board game figure's hop from tile to tile: it may wind up on the spot (leaning back), rises, sways a little to the side, falls
## and bounces as it lands, swinging upright again. Times are fractions of [member ModelAnimation.duration]

@export var _move_height: float = 1.25
## How long the figure stays on the spot before it lifts off, leaning back; e.g. so the pull back shows before a roll
@export_range(0.0, 0.6) var _wind_up: float = 0.0
## How long it takes to rise, once it lifts off
@export_range(0.05, 1.0) var _rise_time: float = 0.25
## When it starts to fall back down
@export_range(0.0, 1.5) var _fall_start: float = 0.8
## How long the fall and the bounce on landing take
@export_range(0.05, 1.0) var _fall_time: float = 0.5
@export_group("Lean")
## Leaning back before the jump (negative); only when a move starts, not when a quick further step redirects it
@export var _tilt: float = -0.3
## How long leaning back takes
@export_range(0.05, 1.5) var _tilt_time: float = 0.75
## When it swings upright again
@export_range(0.0, 1.5) var _tilt_release: float = 0.9
@export var _side_tilt: float = 0.5

func animate(model: Model) -> Tween:
	return _animate(model, true)

## Keeps the figure in the air, leaning back, and lands it again, without starting the lean or a side sway over
func continue_animation(model: Model) -> Tween:
	return _animate(model, false)

func _animate(model: Model, from_standing: bool) -> Tween:
	var tween: Tween = model.create_tween()
	tween.set_parallel()
	# A redirected move is in the air already: no wind-up
	var lift_off: float = duration * _wind_up if from_standing else 0.0
	# Height: tweens start from the current value, so a figure in the air stays up
	tween.tween_property(model, "position:y", _move_height, duration * _rise_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(lift_off)
	tween.tween_property(model, "position:y", 0.0, duration * _fall_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(duration * _fall_start)
	# Lean back first (anticipation), then swing upright on landing. A redirected move leans on from the current angle
	# (tweens start there), so the lean keeps going instead of starting over
	if from_standing: tween.tween_property(model, "rotation:x", _tilt, duration * _tilt_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	else: tween.tween_property(model, "rotation:x", _tilt, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:x", 0.0, duration * 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(duration * _tilt_release)
	# A random sway to the side, settled before landing
	if from_standing:
		var random_side_tilt: float = randf_range(-_side_tilt, _side_tilt) ** 2.0
		tween.tween_property(model, "position:x", random_side_tilt, duration * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(lift_off)
		tween.tween_property(model, "rotation:z", random_side_tilt * 0.5, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(lift_off)
	tween.tween_property(model, "position:x", 0.0, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(duration * 0.75)
	tween.tween_property(model, "rotation:z", 0.0, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(duration * 0.5)
	return tween
