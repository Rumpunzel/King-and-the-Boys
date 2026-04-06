@tool
@icon("uid://cpbv0myc0qfxb")
class_name PreviewModel
extends RigidBody3D

signal profile_changed

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
@export var _collision_shape: CollisionShape3D
@export var _collision_mesh: MeshInstance3D
@export var _hit_box_mesh: MeshInstance3D
@export var _interaction_area_mesh: MeshInstance3D
@export var _heads_up_anchor: HeadsUpAnchor

var _model: Model:
	set(new_model):
		if _model:
			remove_child(_model)
			_model.queue_free()
		_model = new_model
		if not _model: return
		add_child(_model, true)

func play_animation(normalized_velocity: Vector3, is_on_floor: bool) -> void:
	_model.play_animation(normalized_velocity, is_on_floor)

func get_portrait() -> Texture:
	if _model.portrait_override:
		return _model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

func _update() -> void:
	if not is_node_ready(): await ready
	if profile is ThingProfile:
		var thing_profile: ThingProfile = profile
		mass = thing_profile.mass
	else:
		mass = 1.0
	if variation >= profile.get_variation_count(): variation = 0
	if variation >= 0: _model = profile.create_model(variation)
	profile.configure_collision_shape(_collision_shape)
	profile.configure_collision_mesh(_collision_mesh)
	profile.configure_hit_box_mesh(_hit_box_mesh)
	profile.configure_interaction_area_mesh(_interaction_area_mesh)
	_heads_up_anchor.position = get_heads_up_anchor()
	profile_changed.emit()

func _reset_model() -> void:
	_model = null
	_collision_shape.shape = null
	_collision_shape.position = Vector3.ZERO
	_collision_shape.rotation_degrees = Vector3.ZERO
	_collision_mesh.mesh = null
	_collision_mesh.position = Vector3.ZERO
	_collision_mesh.rotation_degrees = Vector3.ZERO
	_hit_box_mesh.mesh = null
	_hit_box_mesh.position = Vector3.ZERO
	_hit_box_mesh.rotation_degrees = Vector3.ZERO
	_heads_up_anchor.position = Vector3.ZERO
	_interaction_area_mesh.mesh = null
	_interaction_area_mesh.position = Vector3.ZERO
	_interaction_area_mesh.rotation_degrees = Vector3.ZERO
	_interaction_area_mesh.position = Vector3.ZERO

func _on_active_profile_changed(active_profile: Profile) -> void:
	profile = active_profile

func _on_variation_changed(new_variation: int) -> void:
	variation = new_variation
