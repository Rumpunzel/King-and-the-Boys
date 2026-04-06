@tool
@icon("uid://bv63hb5gynt8d")
class_name ThingHitBox
extends HitBox

@export var thing: Thing

@export_group("Configuration")

func update_hitbox() -> void:
	assert(thing)
	if not thing.profile:
		assert(Engine.is_editor_hint())
		_collision_shape.shape = null
		_collision_shape.position = Vector3.ZERO
		_collision_shape.rotation_degrees = Vector3.ZERO
		return
	thing.profile.configure_hit_box(_collision_shape)

func get_body() -> Thing:
	return thing

func get_model() -> Model:
	return thing.model

func get_heads_up_anchor() -> Vector3:
	return thing.get_heads_up_anchor()

func _on_profile_changed() -> void:
	update_hitbox()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not thing: warnings.append("Missing Thing reference.")
	return warnings + super._get_configuration_warnings()
