@tool
@icon("uid://whiw21f5vngd")
class_name Thing
extends RigidBody3D

signal profile_changed

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"

## Determines the varation of the [Model]
## If [code]<0[/code] a random [Model] will be used
@export var variation: int = -1:
	set(new_variation):
		if new_variation == variation: return
		variation = new_variation
		if not profile: return
		if not model: return
		model = profile.create_model(variation)

@export var profile: ThingProfile:
	set(new_profile):
		profile = new_profile
		if not profile:
			assert(Engine.is_editor_hint())
			model = null
			_collision_shape.shape = null
			_collision_shape.position = Vector3.ZERO
			_collision_shape.rotation_degrees = Vector3.ZERO
			profile_changed.emit()
			return
		mass = profile.mass
		variation = profile.get_random_variation()
		model = profile.create_model(variation)
		profile.configure_collision_shape(_collision_shape)
		profile_changed.emit()
		add_to_group(profile.get_group_name())

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D

var model: Model:
	set(new_model):
		if model:
			remove_child(model)
			model.queue_free()
		model = new_model
		if not model: return
		add_child(model, true)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property(model, "position:y", 2.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tween.tween_property(model, "rotation:x", -0.5, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "rotation:x", 0.0, 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(0.5)

#func _process(_delta: float) -> void:
	#if Engine.is_editor_hint(): return
	#if model: model.play_animation(_normalized_velocity, _is_on_floor)

static func from_thing_data(thing_data: Dictionary[StringName, Variant]) -> Thing:
	validate_thing_data(thing_data)
	var new_variation: int = thing_data[VARIATION]
	var new_profile_path: String = thing_data[PROFILE_PATH]
	var new_profile: ThingProfile = load(new_profile_path)
	assert(new_profile)
	var new_spawn_transform: Transform3D = thing_data[SPAWN_TRANSFORM]
	return new_profile.create(new_variation, new_spawn_transform)

static func validate_thing_data(thing_data: Dictionary[StringName, Variant]) -> void:
	assert(thing_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM]))
	assert(thing_data.size() == 3)

@rpc("any_peer", "call_local")
func apply_input_force(input_force: Vector3) -> void:
	apply_central_force(input_force)

func apply_thing_data(thing_data: Dictionary[StringName, Variant]) -> void:
	validate_thing_data(thing_data)
	variation = thing_data[VARIATION]
	var profile_path: String = thing_data[PROFILE_PATH]
	profile = load(profile_path)
	PhysicsServer3D.body_set_state(
		get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		thing_data[SPAWN_TRANSFORM],
	)

func to_thing_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var thing_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
	}
	validate_thing_data(thing_data)
	return thing_data

func get_portrait() -> Texture:
	if model.portrait_override:
		return model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

#func get_grid_cell() -> Vector3i:
	#return Level.get_grid_cell_of_node(self)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	return warnings
