extends OmniLight3D
## The light a character shines in from above, so its figure shows in the dark: its own colour without a light, or the colour of
## the light it carries (see [method Character.get_light_sources]), e.g. a torch's warm glow, so the torch lights the ground
## around the figure as one from above would. Its own light gives way where flames already light the figure (see
## [method FlickeringLight.get_light_at]), so torches beside it keep their warm colour. It lights no fog: fog between the camera
## and the figure would glow in front of it

## How long the light takes to change, in seconds
@export var fade_time: float = 0.4
## How brightly flames must light the figure's spot for its own light to give way fully
@export var lit_spot: float = 1.5
## What is left of its own light on a fully lit spot, as a share of its energy
@export_range(0.0, 1.0) var lit_spot_share: float = 0.15
## Seconds between looks at how well the figure's spot is lit, while it carries no light
@export var check_interval: float = 0.25

@export_group("Configuration")
@export var _character: Character

var _own_color: Color
var _own_energy: float
var _own_range: float
# The brightest light the character carries, or null; follows Character.light_sources_changed
var _carried: LightSource
var _tween: Tween
var _target_energy: float = -1.0
var _since_check: float

func _ready() -> void:
	_own_color = light_color
	_own_energy = light_energy
	_own_range = omni_range
	light_volumetric_fog_energy = 0.0
	_character.light_sources_changed.connect(_on_light_sources_changed)
	_on_light_sources_changed()

func _process(delta: float) -> void:
	# A carried light shines as it is; only the own light depends on the flames around
	if _carried: return
	_since_check += delta
	if _since_check < check_interval: return
	_since_check = 0.0
	_fade_to(_own_color, _own_energy * _own_share(), _own_range)

func _on_light_sources_changed() -> void:
	var light_sources: Array[LightSource] = _character.get_light_sources()
	_carried = null
	for light_source: LightSource in light_sources:
		if not _carried or light_source.energy > _carried.energy: _carried = light_source
	if _carried: _fade_to(_carried.color, _carried.energy, _carried.light_range)
	else: _fade_to(_own_color, _own_energy * _own_share(), _own_range)

func _fade_to(color: Color, energy: float, reach: float) -> void:
	if is_equal_approx(energy, _target_energy) and color.is_equal_approx(light_color) and is_equal_approx(reach, omni_range): return
	_target_energy = energy
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "light_color", color, fade_time)
	_tween.tween_property(self, "light_energy", energy, fade_time)
	_tween.tween_property(self, "omni_range", reach, fade_time)

## The share of its own light left where the figure stands, less where flames light it already; flames out of reach are
## skipped by their squared distance
func _own_share() -> float:
	var figure: Vector3 = _character.global_position + Vector3.UP
	var lit: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(FlickeringLight.GROUP):
		var flame: FlickeringLight = node as FlickeringLight
		if flame.global_position.distance_squared_to(figure) < flame.omni_range * flame.omni_range: lit += flame.get_light_at(figure)
	return lerpf(1.0, lit_spot_share, clampf(lit / lit_spot, 0.0, 1.0))
