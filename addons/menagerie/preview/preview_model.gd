@tool
@icon("uid://cpbv0myc0qfxb")
class_name PreviewModel
extends Node3D

signal profile_changed
signal model_changed(model: Model)
signal model_removed

## Determines the varation of the [Model]
## If [code]<0[/code] a random [Model] will be used
@export var variation: int = -1:
	set(new_variation):
		variation = new_variation
		if not profile: return
		if variation >= profile.get_variation_count(): return
		if variation >= 0: _model = profile.create_model(variation)

@export var profile: Profile:
	set(new_profile):
		if profile: profile.changed.disconnect(_update)
		profile = new_profile
		if not profile:
			_reset_model()
			profile_changed.emit()
			return
		_update()
		profile.changed.connect(_update)

@export_group("Configuration")
@export var _heads_up_anchor: HeadsUpAnchor

var _model: Model:
	set(new_model):
		if _model:
			remove_child(_model)
			_model.queue_free()
			model_removed.emit()
		_model = new_model
		if not _model: return
		add_child(_model, true)
		model_changed.emit(_model)

func get_portrait() -> Texture:
	if _model and _model.portrait_override: return _model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	if not profile: return Vector3.ZERO
	return position + profile.heads_up_display_offset

func _update() -> void:
	if not is_node_ready(): await ready
	if variation >= profile.get_variation_count(): variation = 0
	if variation >= 0: _model = profile.create_model(variation)
	_heads_up_anchor.position = get_heads_up_anchor()
	profile_changed.emit()

func _reset_model() -> void:
	_model = null
	_heads_up_anchor.position = Vector3.ZERO

func _on_active_profile_changed(active_profile: Profile) -> void:
	profile = active_profile

func _on_variation_changed(new_variation: int) -> void:
	variation = new_variation

func _on_randomized() -> void:
	assert(profile)
	assert(profile is CharacterProfile)
	assert(_model)
	assert(_model is ModularModel)
	var character_profile: CharacterProfile = profile
	var modular_model: ModularModel = _model
	character_profile.setup_model(modular_model, true)
