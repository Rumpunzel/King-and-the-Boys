@tool
@abstract
@icon("uid://ba48wfee2hq2x")
class_name ModelAnimation
extends Resource

## Moves a whole [Model] by tweens (a hop, a bounce), and may play the model's own animations along with it (see
## [method Model.play_model_animation]), e.g. a jump while it hops; models without them only move

@export var duration: float = 1.0

@export_group("Travel")
## How a figure travels to its target as a move starts (see [Character]), e.g. a hop pulling back a little first (back, ease in)
@export var travel_transition: Tween.TransitionType = Tween.TRANS_BACK
@export var travel_ease: Tween.EaseType = Tween.EASE_IN
## How it travels on when a quick further step redirects the move under way
@export var redirect_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var redirect_ease: Tween.EaseType = Tween.EASE_IN_OUT
## How long the figure stays put before it travels, as a fraction of [member duration], e.g. while winding up on the spot; it
## still arrives by the end of [member duration]
@export_range(0.0, 0.9) var travel_delay: float = 0.0

@export_group("Body")
## The model's own animation as this one starts, e.g. a jump; any animation file of the bodies' rig
@export var body_animation: Animation
## The model's own animation at [member body_landing_time], e.g. landing; then the model goes back to its idle
@export var body_landing: Animation
## When [member body_landing] starts, as a fraction of [member duration]; a little before the model touches down, as it lands
## in a crouch
@export_range(0.0, 2.0) var body_landing_time: float = 0.8
## The model's own animation once it landed, e.g. drawing a sword after spawning; then the model goes back to its idle
@export var body_follow_up: Animation
## How fast the body animations play
@export var body_speed: float = 1.0
## How long [member body_animation] waits, as a fraction of [member duration]; the model keeps its pose meanwhile, e.g. so a
## figure's wind-up shows before it rolls
@export_range(0.0, 1.0) var body_delay: float = 0.0
## Where [member body_animation] starts, in seconds into it, e.g. to skip its own wind-up
@export var body_start: float = 0.0
## How fast [member body_landing] plays; [member body_speed] if 0
@export var body_landing_speed: float = 0.0
## How fast [member body_follow_up] plays; [member body_speed] if 0
@export var body_follow_up_speed: float = 0.0
## How long the body animations blend into each other, in seconds
@export var body_blend: float = 0.15

## @returns the tween playing the animation, so it can be stopped
@abstract func animate(model: Model) -> Tween

## Plays on from where [param model] is, e.g. when a quick further step redirects a move under way.
## Animations without an own continuation play again.
func continue_animation(model: Model) -> Tween:
	return animate(model)

func has_body_animations() -> bool:
	return body_animation != null or body_landing != null or body_follow_up != null
