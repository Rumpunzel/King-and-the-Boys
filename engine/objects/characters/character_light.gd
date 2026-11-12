extends OmniLight3D
## The light a character shines in, so its figure shows in the dark without carrying a light; dims while the character carries a
## light of its own (e.g. a torch in hand, see [method ModularModel.carries_light]), so that one's colour leads

## The energy while the character carries a light; the light's own energy otherwise
@export var carried_energy: float = 0.8
## How long the light takes to dim or brighten, in seconds
@export var fade_time: float = 0.4

@export_group("Configuration")
@export var _character: Character

var _energy: float
var _model: ModularModel
var _tween: Tween

func _ready() -> void:
	_energy = light_energy
	_character.model_changed.connect(_on_model_changed)
	_on_model_changed()

func _on_model_changed() -> void:
	if _model and _model.carried_light_changed.is_connected(_fade): _model.carried_light_changed.disconnect(_fade)
	_model = _character.model as ModularModel
	if _model: _model.carried_light_changed.connect(_fade)
	_fade()

func _fade() -> void:
	var target: float = carried_energy if _model and _model.carries_light() else _energy
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "light_energy", target, fade_time)
