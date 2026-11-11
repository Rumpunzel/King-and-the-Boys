@icon("uid://7ku6kr8m1or8")
class_name FlickeringLight
extends OmniLight3D

## A light that wavers around the energy it was given, like a flame (quick, strong flicker) or a glowing crystal (slow, soft pulse).
## Each light wavers on its own

## How far the energy strays, as a fraction of the energy it was given
@export_range(0.0, 1.0) var flicker: float = 0.25
## How quickly it wavers
@export var speed: float = 8.0

var _energy: float
var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float

func _ready() -> void:
	_energy = light_energy
	_noise.seed = randi()
	_time = randf() * 100.0

func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = _energy * (1.0 + flicker * _noise.get_noise_1d(_time) * 2.0)
