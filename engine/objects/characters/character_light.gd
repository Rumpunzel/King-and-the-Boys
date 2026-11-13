extends OmniLight3D
## The light a character shines in from above, so its figure and the board around it show in the dark: a faint, wide light
## of its own (the cool baseline) and, while it carries lights, a second one, [member _carried_light], in the colour, energy
## and range of the brightest it carries (see [method Character.get_light_sources]), e.g. a torch's warm glow, so the torch
## lights the ground around the figure. The carried light hangs lower, so its pool stays small and apart from the flames
## nearby. The baseline reaches [member reach_beyond_carried] further than the carried light, so the warm pool fades into a
## cool rim of the same width at its edge. Only one of them casts shadows. Neither lights fog: fog between the camera and
## the figure would glow in front of it

## How long the lights take to change, in seconds
@export var fade_time: float = 0.4
## How much further the baseline reaches than a carried light, so a cool rim of the same width always shows around the
## warm pool; without a carried light it reaches as far as the scene sets it
@export var reach_beyond_carried: float = 6.0

@export_group("Configuration")
@export var _character: Character
## Shines the carried light; off while the character carries none
@export var _carried_light: OmniLight3D

var _own_range: float
var _tween: Tween

func _ready() -> void:
	_own_range = omni_range
	light_volumetric_fog_energy = 0.0
	_carried_light.light_volumetric_fog_energy = 0.0
	_carried_light.light_energy = 0.0
	_carried_light.visible = false
	_character.light_sources_changed.connect(_on_light_sources_changed)
	_on_light_sources_changed()

func _on_light_sources_changed() -> void:
	var carried: LightSource = null
	for light_source: LightSource in _character.get_light_sources():
		if not carried or light_source.energy > carried.energy: carried = light_source
	# Both shine from above the figure, so one shadow is enough
	shadow_enabled = carried == null
	_carried_light.shadow_enabled = carried != null
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "omni_range", carried.light_range + reach_beyond_carried if carried else _own_range, fade_time)
	if not carried:
		_tween.tween_property(_carried_light, "light_energy", 0.0, fade_time)
		_tween.chain().tween_callback(_carried_light.hide)
		return
	_carried_light.show()
	_tween.tween_property(_carried_light, "light_color", carried.color, fade_time)
	_tween.tween_property(_carried_light, "light_energy", carried.energy, fade_time)
	_tween.tween_property(_carried_light, "omni_range", carried.light_range, fade_time)
