@tool
@icon("uid://bnaoddhf8gssj")
class_name Character
extends CharacterBody3D

signal entered_grid_cell(cell: Vector3i)
signal exited_grid_cell(cell: Vector3i)
signal destination_reached

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

@export var profile: CharacterProfile:
	set(new_character_profile):
		profile = new_character_profile
		if not profile:
			assert(Engine.is_editor_hint())
			model = null
			_collision_shape.shape = null
			_collision_shape.position = Vector3.ZERO
			_collision_shape.rotation_degrees = Vector3.ZERO
			profile_changed.emit()
			return
		if variation < 0: variation = profile.get_random_variation()
		model = profile.create_model(variation)
		profile.configure_collision_shape(_collision_shape)
		profile_changed.emit()
		add_to_group(profile.get_group_name())

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D
@export var _navigation_agent: NavigationAgent3D

var model: Model:
	set(new_model):
		if model:
			remove_child(model)
			model.queue_free()
		model = new_model
		if not model: return
		add_child(model, true)

var look_target: Vector3 = Vector3.BACK

var _is_on_floor: bool = true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	entered_grid_cell.emit(get_grid_cell())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var grid_cell_before: Vector3i = get_grid_cell()
	_is_on_floor = is_on_floor()
	if not _is_on_floor: _apply_gravity(delta)
	_handle_pathfinding()
	move_and_slide()
	_look_forward(delta)
	var grid_cell_after: Vector3i = get_grid_cell()
	if grid_cell_after != grid_cell_before:
		exited_grid_cell.emit(grid_cell_before)
		entered_grid_cell.emit(grid_cell_after)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	#if model: model.play_animation(_normalized_velocity, _is_on_floor)

static func from_character_data(character_data: Dictionary[StringName, Variant]) -> Character:
	validate_character_data(character_data)
	var new_variation: int = character_data[VARIATION]
	var new_character_profile_path: String = character_data[PROFILE_PATH]
	var new_character_profile: CharacterProfile = load(new_character_profile_path)
	assert(new_character_profile)
	var new_spawn_transform: Transform3D = character_data[SPAWN_TRANSFORM]
	return new_character_profile.create(new_variation, new_spawn_transform)

static func validate_character_data(character_data: Dictionary[StringName, Variant]) -> void:
	assert(character_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM]))
	assert(character_data.size() == 3)

@rpc("any_peer", "call_local", "reliable")
func move_to_position(position_input: Vector3) -> void:
	_navigation_agent.target_position = position_input

@rpc("call_local", "reliable")
func hide_character(keep_physics: bool = false) -> void:
	assert(visible)
	visible = false
	if keep_physics: return
	_disable_physics()

@rpc("call_local", "reliable")
func unhide_character() -> void:
	assert(not visible)
	visible = true
	_enable_physics()

func apply_character_data(character_data: Dictionary[StringName, Variant]) -> void:
	validate_character_data(character_data)
	variation = character_data[VARIATION]
	var character_profile_path: String = character_data[PROFILE_PATH]
	profile = load(character_profile_path)
	transform = character_data[SPAWN_TRANSFORM]

func to_character_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var character_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
	}
	validate_character_data(character_data)
	return character_data

func get_portrait() -> Texture:
	if model.portrait_override:
		return model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

func get_grid_cell() -> Vector3i:
	return Level.get_grid_cell_of_node(self)

func _apply_gravity(delta: float) -> void:
	velocity.y -= _gravity * delta

func _handle_pathfinding() -> void:
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer3D.map_get_iteration_id(_navigation_agent.get_navigation_map()) == 0: return
	if _navigation_agent.is_navigation_finished(): return
	var next_path_position: Vector3 = _navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * profile.speed
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(new_velocity)
	else:
		_on_navigation_agent_velocity_computed(new_velocity)

func _look_forward(delta: float) -> void:
	look_target = position + velocity
	look_target.y = position.y
	if look_target.is_equal_approx(transform.origin): return
	var transform_looking_into_direction: Transform3D = transform.looking_at(look_target, Vector3.UP, true)
	transform = transform.interpolate_with(transform_looking_into_direction, 16.0 * delta)

func _enable_physics() -> void:
	set_physics_process(true)
	set_process(true)

func _disable_physics() -> void:
	set_physics_process(false)
	set_process(false)

func _on_navigation_agent_velocity_computed(safe_velocity: Vector3) -> void:
	if _navigation_agent.is_navigation_finished(): return
	velocity = safe_velocity

func _on_navigation_agent_navigation_finished() -> void:
	velocity = Vector3.ZERO
	destination_reached.emit()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	if not _navigation_agent: warnings.append("Missing NavigationAgent3D reference.")
	return warnings
