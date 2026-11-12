extends OmniLight3D
## The light a character shines in from above, so its figure shows in the dark: its own colour without a light, or the colour of
## the light it carries (see [method Character.get_light_sources]), e.g. a torch's warm glow, so the torch lights the ground
## around the figure as one from above would

## How long the light takes to change, in seconds
@export var fade_time: float = 0.4

@export_group("Configuration")
@export var _character: Character

var _own_color: Color
var _own_energy: float
var _own_range: float
var _tween: Tween

func _ready() -> void:
	_own_color = light_color
	_own_energy = light_energy
	_own_range = omni_range
	_character.light_sources_changed.connect(_fade)
	_fade()

func _fade() -> void:
	var light_sources: Array[LightSource] = _character.get_light_sources()
	# The brightest light carried leads
	light_sources.sort_custom(func(first: LightSource, second: LightSource) -> bool: return first.energy > second.energy)
	var carried: LightSource = light_sources.front() if not light_sources.is_empty() else null
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "light_color", carried.color if carried else _own_color, fade_time)
	_tween.tween_property(self, "light_energy", carried.energy if carried else _own_energy, fade_time)
	_tween.tween_property(self, "omni_range", carried.light_range if carried else _own_range, fade_time)
