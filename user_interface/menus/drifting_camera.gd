class_name DriftingCamera
extends Camera3D

## Drifts slowly around where it stands while looking at a point ahead of it, so the scene shows its depth: what stands near
## that point (e.g. the lobby's characters) stays put, nearer and farther things shift against each other. The path is a smooth
## figure of eight, eased in from rest

## How far it strays right and up, in metres
@export var drift: Vector2 = Vector2(0.12, 0.05)
## Seconds for one figure of eight
@export var period: float = 40.0
## How far ahead the point it looks at lies, in metres
@export var focus_distance: float = 1.6
## Seconds until it drifts fully, from rest
@export var ease_in_duration: float = 4.0

var _rest: Transform3D
var _focus: Vector3
var _time: float = 0.0

func _ready() -> void:
	_rest = transform
	_focus = _rest * (Vector3.FORWARD * focus_distance)

func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / period
	var strength: float = smoothstep(0.0, ease_in_duration, _time)
	var offset: Vector3 = _rest.basis.x.normalized() * drift.x * sin(phase) + _rest.basis.y.normalized() * drift.y * sin(phase * 2.0)
	transform = Transform3D(_rest.basis, _rest.origin + offset * strength).looking_at(_focus, _rest.basis.y.normalized())
