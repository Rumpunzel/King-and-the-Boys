@tool
@icon("uid://btm20iemr2nfr")
class_name Structure
extends StaticBody3D

signal profile_changed

enum Status {
	NONE = -1,
	PLACED,
	DISCOVERED,
	REVEALED,
}

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"
const CLOCKWISE_TURNS: StringName = "clockwise_turns"
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

@export var clockwise_turns: int = 0:
	get: return posmod(-rotation.y / (PI * 0.5), 4)
	set(new_clockwise_turns):
		rotation.y = TAU - new_clockwise_turns * (PI * 0.5)

@export var status: Status = Status.NONE:
	set(new_status):
		if new_status == status: return
		status = new_status
		match status:
			Status.PLACED:
				model.visible = false
				model.rotation.x = PI
			Status.DISCOVERED:
				model.apply_material_override(_hidden_material)
				model.visible = true
				var tween: Tween = create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
			Status.REVEALED:
				model.visible = true
				model.remove_material_override(_hidden_material)
				var tween: Tween = create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "rotation:x", 0.0, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
				_debug_draw_connections()
			_: push_error("Status %s not implemented!" % status)

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D
@export var _hidden_material: Material

var model: Model:
	set(new_model):
		if model:
			remove_child(model)
			model.queue_free()
		model = new_model
		if not model: return
		add_child(model, true)

var level: Level

func _ready() -> void:
	if Engine.is_editor_hint(): return
	name = "%s %s" % [get_grid_position(), profile.name]
	if status == Status.NONE: status = Status.PLACED
	@warning_ignore("unsafe_property_access")
	$Label3D.text = "%s\n%s" % [profile.name, get_grid_position()]

static func from_structure_data(structure_data: Dictionary[StringName, Variant]) -> Structure:
	validate_structure_data(structure_data)
	var new_variation: int = structure_data[VARIATION]
	var new_profile_path: String = structure_data[PROFILE_PATH]
	var new_profile: StructureProfile = load(new_profile_path)
	assert(new_profile)
	var new_spawn_transform: Transform3D = structure_data[SPAWN_TRANSFORM]
	var new_clockwise_turns: Status = structure_data[CLOCKWISE_TURNS]
	var new_status: Status = structure_data[STATUS]
	return new_profile.create(new_variation, new_spawn_transform, new_clockwise_turns, new_status)

static func validate_structure_data(structure_data: Dictionary[StringName, Variant]) -> void:
	assert(structure_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM, CLOCKWISE_TURNS, STATUS]))
	assert(structure_data.size() == 5)

@rpc("call_local", "reliable")
func discover() -> bool:
	if status >= Status.DISCOVERED: return false
	status = Status.DISCOVERED
	return true

@rpc("call_local", "reliable")
func reveal() -> bool:
	if status >= Status.REVEALED: return false
	status = Status.REVEALED
	return true

func apply_structure_data(structure_data: Dictionary[StringName, Variant]) -> void:
	validate_structure_data(structure_data)
	variation = structure_data[VARIATION]
	var profile_path: String = structure_data[PROFILE_PATH]
	profile = load(profile_path)
	transform = structure_data[SPAWN_TRANSFORM]
	clockwise_turns = structure_data[CLOCKWISE_TURNS]
	status = structure_data[STATUS]

func to_structure_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var structure_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
		CLOCKWISE_TURNS: clockwise_turns,
		STATUS: status,
	}
	validate_structure_data(structure_data)
	return structure_data

func can_connect(direction: Level.Direction, other_profile: StructureProfile) -> bool: return profile.can_connect(direction, clockwise_turns, other_profile)

func has_connection(direction: Level.Direction) -> bool: return profile.has_connection(direction, clockwise_turns)
func get_connections() -> Array[Level.Direction]: return profile.get_connections(clockwise_turns)
func get_connection_vectors() -> Array[Vector2i]: return profile.get_connection_vectors(clockwise_turns)

func get_restriction(direction: Level.Direction) -> ConnectionRestriction: return profile.get_restriction(direction, clockwise_turns)
func get_restrictions() -> Dictionary[Level.Direction, ConnectionRestriction]: return profile.get_restrictions(clockwise_turns)

func get_portrait() -> Texture:
	if model.portrait_override: return model.portrait_override
	return profile.portrait

func get_heads_up_anchor() -> Vector3:
	return position + profile.heads_up_display_offset

func get_grid_position() -> Vector2i:
	return level.world_to_grid_position(global_position)

func get_grid_cells() -> Array[Vector2i]:
	var grid_cells: Array[Vector2i] = []
	var origin_cell: Vector2i = get_grid_position()
	for y: int in range(profile.grid_cell_extents.z):
		for x: int in range(profile.grid_cell_extents.x):
			var cell_position: Vector2i = Vector2i.RIGHT * x + Vector2i.UP * y
			grid_cells.append(origin_cell + cell_position)
	return grid_cells

func _debug_draw_connections() -> void:
	assert(level)
	for connection: Level.Direction in get_connections():
		var tile_grid_offset: Vector2i = Level.direction_to_vector(connection)
		var edge_offset: Vector3 = level.grid_to_world_position(tile_grid_offset) * 0.5
		var color: Color = profile.room_type.color if profile.room_type else Color.WHEAT
		DebugDraw3D.draw_line(global_position + Vector3.UP * 0.0, global_position + level.grid_to_world_position(tile_grid_offset) - edge_offset + Vector3.UP * 0.15, color, INF)
	var restrictions: Dictionary[Level.Direction, ConnectionRestriction] = get_restrictions()
	for direction: Level.Direction in restrictions.keys():
		var restriction: ConnectionRestriction = restrictions[direction]
		if not restriction: continue
		var tile_grid_offset: Vector2i = Level.direction_to_vector(direction)
		var edge_offset: Vector3 = level.grid_to_world_position(tile_grid_offset) * 0.6
		var color: Color = Color.BROWN if restriction._invert else Color.WEB_GREEN
		color.a = 0.5
		DebugDraw3D.draw_sphere(global_position + level.grid_to_world_position(tile_grid_offset) - edge_offset + Vector3.UP * 0.15, 0.1, color, INF)

func _to_string() -> String:
	return "[%s turned %d times: %s]" % [name, clockwise_turns, get_connections()]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	if not _hidden_material: warnings.append("Missing hidden material reference.")
	return warnings
