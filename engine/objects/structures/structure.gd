@tool
@icon("uid://btm20iemr2nfr")
class_name Structure
extends StaticBody3D

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

@export var profile: StructureProfile:
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

#func _process(_delta: float) -> void:
	#if Engine.is_editor_hint(): return
	#if model: model.play_animation(_normalized_velocity, _is_on_floor)

static func from_structure_data(structure_data: Dictionary[StringName, Variant]) -> Structure:
	validate_structure_data(structure_data)
	var new_variation: int = structure_data[VARIATION]
	var new_profile_path: String = structure_data[PROFILE_PATH]
	var new_profile: StructureProfile = load(new_profile_path)
	assert(new_profile)
	var new_spawn_transform: Transform3D = structure_data[SPAWN_TRANSFORM]
	return new_profile.create(new_variation, new_spawn_transform)

static func validate_structure_data(structure_data: Dictionary[StringName, Variant]) -> void:
	assert(structure_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM]))
	assert(structure_data.size() == 3)

func apply_structure_data(thing_data: Dictionary[StringName, Variant]) -> void:
	validate_structure_data(thing_data)
	variation = thing_data[VARIATION]
	var profile_path: String = thing_data[PROFILE_PATH]
	profile = load(profile_path)
	transform = thing_data[SPAWN_TRANSFORM]

func to_structure_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var structure_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
	}
	validate_structure_data(structure_data)
	return structure_data

func get_portrait() -> Texture:
	if model.portrait_override:
		return model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

func get_grid_cells() -> Array[Vector3i]:
	var grid_cells: Array[Vector3i] = []
	var origin_cell: Vector3i = Level.get_grid_cell_of_node(self)
	for y: int in range(1): # range(profile.grid_cell_extents.y):
		for z: int in range(profile.grid_cell_extents.z):
			for x: int in range(profile.grid_cell_extents.x):
				var cell_position: Vector3i = Vector3i.LEFT * x + Vector3i.UP * y + Vector3i.FORWARD * z
				grid_cells.append(origin_cell + cell_position)
	return grid_cells

func _on_haunted(_haunting: Character) -> void:
	model.apply_material_overlay(profile.haunted_material)

func _on_unhaunted() -> void:
	model.remove_material_overlay(profile.haunted_material)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	return warnings
