@icon("uid://3b41umi7nady")
class_name FlickeringLight
extends OmniLight3D

## A light that wavers around the energy it was given, like a flame (quick, strong flicker) or a glowing crystal (slow, soft pulse).
## Each light wavers on its own

## Every flickering light is in it, so a character's own light can tell how well a spot is lit already
const GROUP: StringName = &"flickering_lights"

## How far the energy strays, as a fraction of the energy it was given
@export_range(0.0, 1.0) var flicker: float = 0.25
## How quickly it wavers
@export var speed: float = 8.0

var _energy: float
var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float

func _ready() -> void:
	add_to_group(GROUP)
	_energy = light_energy
	_noise.seed = randi()
	_time = randf() * 100.0

func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = _energy * (1.0 + flicker * _noise.get_noise_1d(_time) * 2.0)

## How brightly the light falls on [param point]: its steady energy, fading to nothing at its range
func get_light_at(point: Vector3) -> float:
	if not is_visible_in_tree(): return 0.0
	var nearness: float = 1.0 - global_position.distance_to(point) / omni_range
	return _energy * nearness * nearness if nearness > 0.0 else 0.0
