@tool
@icon("uid://whiw21f5vngd")
class_name Thing
extends BoardObject

signal status_changed(status: Status)

enum Status {
	NONE = -1,
	PLACED,
	REVEALED,
}

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"
const STATUS: StringName = "status"

@export var profile: ThingProfile:
	set(new_profile):
		var previous_profile: ThingProfile = profile
		profile = new_profile
		_show_profile(previous_profile)

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

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if status == Status.NONE: status = Status.PLACED

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

func apply_thing_data(thing_data: Dictionary[StringName, Variant]) -> void:
	validate_thing_data(thing_data)
	variation = thing_data[VARIATION]
	var profile_path: String = thing_data[PROFILE_PATH]
	profile = load(profile_path)
	transform = thing_data[SPAWN_TRANSFORM]
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

func get_profile() -> Profile: return profile

