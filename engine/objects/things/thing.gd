@tool
@icon("uid://whiw21f5vngd")
class_name Thing
extends RigidBody3D

signal status_changed(status: Status)
signal profile_changed

enum Status {
	NONE = -1,
	PLACED,
	REVEALED,
}

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"
const STATUS: StringName = "status"

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

@export var status: Status = Status.NONE:
	set(new_status):
		if new_status == status: return
		status = new_status
		match status:
			Status.PLACED:
				model.visible = false
			Status.REVEALED:
				model.visible = true
				model.play_model_animation(profile.spawn_animation)
			_: push_error("Status %s not implemented!" % status)
		status_changed.emit(status)

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
	if status == Status.NONE: status = Status.PLACED

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
	var new_status: Status = thing_data[STATUS]
	return new_profile.create(new_variation, new_spawn_transform, new_status)

static func validate_thing_data(thing_data: Dictionary[StringName, Variant]) -> void:
	assert(thing_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM, STATUS]))
	assert(thing_data.size() == 4)

static func structure_status_to_thing_status(structure_status: Structure.Status) -> Thing.Status:
	match structure_status:
		Structure.Status.NONE: return Thing.Status.NONE
		Status.PLACED: return Thing.Status.PLACED
		Structure.Status.DISCOVERED: return Thing.Status.PLACED
		Structure.Status.REVEALED: return Thing.Status.REVEALED
		_: push_error("Conversion for structure_status %s not implemented!" % structure_status)
	assert(false)
	return Thing.Status.NONE

@rpc("call_local", "reliable")
func reveal() -> bool:
	if status >= Status.REVEALED: return false
	status = Status.REVEALED
	return true

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
	status = thing_data[STATUS]

func to_thing_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var thing_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
		STATUS: status,
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
