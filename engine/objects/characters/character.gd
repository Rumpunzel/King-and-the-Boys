@tool
@icon("uid://bnaoddhf8gssj")
class_name Character
extends CharacterBody3D

signal entered_grid_cell(cell: Vector2i)
signal exited_grid_cell(cell: Vector2i)
signal destination_reached
signal movement_points_changed(movement_points: int)
## Emitted on every peer when the animated figure crosses into [param cell], which lags behind [member grid_cell]
signal figure_entered_grid_cell(cell: Vector2i)

signal profile_changed

const GROUP: StringName = "Characters"

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"

const _TURN_DURATION: float = 0.5

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
@export var _synchronizer: MultiplayerSynchronizer

var model: Model:
	set(new_model):
		if model:
			remove_child(model)
			model.queue_free()
		model = new_model
		if not model: return
		add_child(model, true)

var level: Level
var look_target: Vector3 = Vector3.BACK
## The [Character] currently haunting (controlling) this one, if any
var haunted_by: Character
## [code]true[/code] once the [Character] left the cell it spawned on, on every peer
var has_stepped: bool = false

# Grid state: owned by the host, replicated on change by the CharacterSynchronizer.
# Every peer turns it into a world position and animates the model itself.
var grid_cell: Vector2i = Vector2i.ZERO:
	set(new_grid_cell):
		var previous_grid_cell: Vector2i = grid_cell
		grid_cell = new_grid_cell
		_queue_grid_visual_update()
		if previous_grid_cell == grid_cell or not _has_grid_state: return
		# Several steps can land in one frame; the figure walks each of them
		_passed_cells.append(grid_cell)
		has_stepped = true
		exited_grid_cell.emit(previous_grid_cell)
		entered_grid_cell.emit(grid_cell)
## Offset from the center of [member grid_cell], see [method Level.get_free_spots]
var tile_spot: Vector2 = Vector2.ZERO:
	set(new_tile_spot):
		tile_spot = new_tile_spot
		_queue_grid_visual_update()
var facing: Level.Direction = Level.Direction.DOWN:
	set(new_facing):
		facing = new_facing
		_queue_grid_visual_update()
## Movement points left in the current turn; [code]<0[/code] until the host first resets them
var movement_points: int = -1:
	set(new_movement_points):
		if new_movement_points == movement_points: return
		movement_points = new_movement_points
		movement_points_changed.emit(movement_points)
## Steps the host can still undo this turn; replicated, the steps themselves stay on the host
var undo_steps: int = 0

var _has_grid_state: bool = false
var _grid_visual_update_queued: bool = false
var _grid_visuals_applied: bool = false
# Steps the figure still has to walk, oldest first; quick moves queue up and are walked faster
var _figure_steps: Array[FigureStep] = []
var _figure_tween: Tween
var _look_tween: Tween
# Cells entered since the figure last got its steps, oldest first
var _passed_cells: Array[Vector2i] = []
# The cell of the newest queued figure step
var _figure_target_cell: Vector2i

## Where the figure walks to and how it faces there
class FigureStep extends RefCounted:
	var position: Vector3
	var rotation_y: float

	func _init(new_position: Vector3, new_rotation_y: float) -> void:
		position = new_position
		rotation_y = new_rotation_y
var _figure_grid_cell: Vector2i = Vector2i.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if model: model.play_model_animation(profile.spawn_animation)
	if multiplayer.is_server():
		# Initial grid state comes from the spawn transform
		grid_cell = level.world_to_grid_position(global_position)
		facing = rotation_to_facing(rotation.y)
		var free_spots: Array[Vector2] = level.get_free_spots(grid_cell, self)
		if not free_spots.is_empty(): tile_spot = free_spots.front()
		reset_movement_points()
	_has_grid_state = true
	_queue_grid_visual_update()
	entered_grid_cell.emit(grid_cell)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	#_is_on_floor = is_on_floor()
	#if not _is_on_floor: _apply_gravity(delta)
	#_handle_pathfinding()
	#move_and_slide()
	#_look_forward(delta)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_update_figure_grid_cell()
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

static func facing_to_rotation(direction: Level.Direction) -> float:
	return (2 - direction) * PI * 0.5

static func rotation_to_facing(rotation_y: float) -> Level.Direction:
	return posmod(2 - roundi(rotation_y / (PI * 0.5)), Level.Direction.size()) as Level.Direction

## Used to move the [Character] without pathfinding
@rpc("any_peer", "call_local")
func move_into_direction(direction_input: Vector2, delta: float) -> void:
	if not direction_input:
		var deceleration: float = delta
		velocity.x = move_toward(velocity.x, 0.0, deceleration)
		velocity.z = move_toward(velocity.z, 0.0, deceleration)
		return
	var move_speed: float = 16.0
	var acceleration: float = delta
	velocity.x = move_toward(velocity.x, direction_input.x * move_speed, acceleration)
	velocity.z = move_toward(velocity.z, direction_input.y * move_speed, acceleration)

## Host only: places the [Character] on the grid; peers follow through replication
func place_on_grid(new_grid_cell: Vector2i, new_tile_spot: Vector2, new_facing: Level.Direction) -> void:
	assert(multiplayer.is_server())
	tile_spot = new_tile_spot
	facing = new_facing
	grid_cell = new_grid_cell

## The host owns the grid state of every piece, whoever controls it.
## Call after changing the multiplayer authority of this [Character].
func give_grid_state_to_host() -> void:
	_synchronizer.set_multiplayer_authority(Multiplayer.HOST_ID)

## Host only
func reset_movement_points() -> void:
	assert(multiplayer.is_server())
	movement_points = profile.speed

## Snaps the model back onto its grid state, e.g. after something else moved it locally
func snap_to_grid() -> void:
	_grid_visuals_applied = false
	_queue_grid_visual_update()

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
	if model and model.portrait_override: return model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

func get_grid_position() -> Vector2i:
	return grid_cell

## @returns the cell the animated figure currently stands in
func get_figure_grid_cell() -> Vector2i:
	return _figure_grid_cell

func _update_figure_grid_cell() -> void:
	if not level or not _grid_visuals_applied: return
	var figure_grid_cell: Vector2i = level.world_to_grid_position(global_position)
	if figure_grid_cell == _figure_grid_cell: return
	_figure_grid_cell = figure_grid_cell
	figure_entered_grid_cell.emit(_figure_grid_cell)

func _queue_grid_visual_update() -> void:
	if _grid_visual_update_queued: return
	_grid_visual_update_queued = true
	_apply_grid_visuals.call_deferred()

func _apply_grid_visuals() -> void:
	_grid_visual_update_queued = false
	if not level or not is_inside_tree(): return
	var step: FigureStep = FigureStep.new(level.get_spot_position(grid_cell, tile_spot), facing_to_rotation(facing))
	var passed_cells: Array[Vector2i] = _passed_cells
	_passed_cells = []
	if not _grid_visuals_applied:
		_grid_visuals_applied = true
		_figure_target_cell = grid_cell
		_figure_steps.clear()
		if _figure_tween: _figure_tween.kill()
		if _look_tween: _look_tween.kill()
		global_position = step.position
		rotation.y = step.rotation_y
		_update_figure_grid_cell()
		return
	# Cells passed on the way: through their middle, facing the way of walking
	if not passed_cells.is_empty() and passed_cells.back() == grid_cell: passed_cells.pop_back()
	for cell: Vector2i in passed_cells:
		var walking_direction: Level.Direction = Level.get_direction(_figure_target_cell, cell) if (cell - _figure_target_cell).length_squared() == 1 else facing
		_figure_steps.append(FigureStep.new(level.get_spot_position(cell, Vector2.ZERO), facing_to_rotation(walking_direction)))
		_figure_target_cell = cell
	_figure_steps.append(step)
	_figure_target_cell = grid_cell
	if not _figure_tween or not _figure_tween.is_running():
		_walk_next_figure_step()
		return
	# Catch up: the step under way speeds up as more steps queue behind it
	_figure_tween.set_speed_scale(1.0 + _figure_steps.size())

## Walks the oldest queued step; the more steps wait behind it, the quicker it goes
func _walk_next_figure_step() -> void:
	if _figure_steps.is_empty(): return
	var step: FigureStep = _figure_steps.pop_front()
	var steps_behind: int = _figure_steps.size()
	if _look_tween: _look_tween.kill()
	var walking: bool = not global_position.is_equal_approx(step.position)
	var animation: ModelAnimation = _get_step_animation(step, steps_behind)
	var duration: float = animation.duration / (1.0 + steps_behind) if walking else _TURN_DURATION
	_figure_tween = create_tween()
	_figure_tween.set_parallel()
	var relative_rotation: float = wrapf(step.rotation_y - rotation.y, -PI, PI)
	_figure_tween.tween_property(self, "rotation:y", relative_rotation, minf(_TURN_DURATION, duration)).as_relative().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if walking:
		# Chained steps flow into each other; the last one keeps the hop-in feel
		var transition: Tween.TransitionType = Tween.TRANS_LINEAR if steps_behind > 0 else Tween.TRANS_BACK
		_figure_tween.tween_property(self, "global_position", step.position, duration).set_trans(transition).set_ease(Tween.EASE_IN)
		if model: model.play_model_animation(animation)
	_figure_tween.chain().tween_callback(_on_figure_step_done.bind(walking and not _is_walking_backwards(step)))

## Steps back (undo) keep facing the way the step went, so the figure walks backwards
func _is_walking_backwards(step: FigureStep) -> bool:
	var movement: Vector3 = step.position - global_position
	var facing_vector: Vector3 = Vector3(sin(step.rotation_y), 0.0, cos(step.rotation_y))
	return movement.length_squared() > 0.0 and movement.normalized().dot(facing_vector) < -0.5

func _get_step_animation(step: FigureStep, steps_behind: int) -> ModelAnimation:
	if _is_walking_backwards(step) and profile.undo_animation: return profile.undo_animation
	if steps_behind > 0 and profile.fast_move_animation: return profile.fast_move_animation
	return profile.move_animation

func _on_figure_step_done(walked_forwards: bool) -> void:
	if not _figure_steps.is_empty():
		_walk_next_figure_step()
		return
	if walked_forwards: _look_at_thing_on_tile()

## Something interesting on the tile (e.g. a chest) catches the figure's eye when it arrives
func _look_at_thing_on_tile() -> void:
	var thing: Thing = level.get_placed_thing(grid_cell)
	if not thing or not thing.visible: return
	var to_thing: Vector3 = thing.global_position - global_position
	to_thing.y = 0.0
	if to_thing.length_squared() < 0.01: return
	var relative_rotation: float = wrapf(atan2(to_thing.x, to_thing.z) - rotation.y, -PI, PI)
	_look_tween = create_tween()
	_look_tween.tween_property(self, "rotation:y", relative_rotation, _TURN_DURATION).as_relative().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

func _look_forward(delta: float, direction: Vector3 = velocity) -> void:
	look_target = direction
	look_target.y = position.y
	if look_target.is_equal_approx(transform.origin): return
	var transform_looking_into_direction: Transform3D = transform.looking_at(look_target, Vector3.UP, true)
	transform = transform.interpolate_with(transform_looking_into_direction, 8.0 * delta)

func _enable_physics() -> void:
	set_physics_process(true)
	set_process(true)

func _disable_physics() -> void:
	set_physics_process(false)
	set_process(false)

## @returns [code]true[/code] if the peer [param peer_id] may move this [Character]
func is_controlled_by(peer_id: int) -> bool:
	if haunted_by: return haunted_by.get_multiplayer_authority() == peer_id
	return get_multiplayer_authority() == peer_id

func _on_haunted(haunting: Character) -> void:
	haunted_by = haunting

func _on_unhaunted() -> void:
	haunted_by = null

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
	if not _synchronizer: warnings.append("Missing MultiplayerSynchronizer reference.")
	return warnings
