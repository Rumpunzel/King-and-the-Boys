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
		var old_status: Status = status
		status = new_status
		match status:
			Status.PLACED: model.visible = false
			Status.DISCOVERED:
				model.apply_material_override(_hidden_material)
				model.visible = true
			Status.REVEALED:
				model.visible = true
				model.remove_material_override(_hidden_material)
			_: push_error("Status %s not implemented!" % status)
		if old_status < Status.PLACED: return
		match status:
			Status.DISCOVERED:
				var tween: Tween = create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
			Status.REVEALED:
				var tween: Tween = create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "rotation:x", PI, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
				_debug_draw_connections()

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D
@export var _hidden_material: Material = preload("uid://cgb4im743eoct")

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
	if status == Status.NONE: status = Status.PLACED

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

func has_connection(direction: Level.Direction) -> bool:
	return get_connections().has(direction)

func get_connection(direction: Level.Direction) -> RoomType:
	assert(has_connection(direction))
	return get_connections()[direction]

func can_connect(direction: Level.Direction, room_type: RoomType) -> bool:
	if not has_connection(direction): return false
	var connections: Dictionary[Level.Direction, RoomType] = get_connections()
	var required_room_type: RoomType = connections[direction]
	return not required_room_type or room_type == required_room_type

func get_connections() -> Dictionary[Level.Direction, RoomType]:
	var adjusted_connections: Dictionary[Level.Direction, RoomType] = {}
	for connection: Level.Direction in profile.connections.keys():
		adjusted_connections[_get_adjusted_direction(connection)] = profile.connections[connection]
	return adjusted_connections

func get_connection_vectors() -> Array[Vector2i]:
	var connection_vectors: Array[Vector2i]
	connection_vectors.assign(get_connections().keys().map(func(direction: Level.Direction) -> Vector2i: return Level.direction_to_vector(direction)))
	return connection_vectors

func get_portrait() -> Texture:
	if model.portrait_override:
		return model.portrait_override
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

func _get_adjusted_direction(direction: Level.Direction) -> Level.Direction:
	var direction_count: int = Level.Direction.size()
	return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)

func _debug_draw_connections() -> void:
	assert(level)
	for index: int in get_connection_vectors().size():
		var direction: Level.Direction = get_connections().keys()[index]
		var tile_grid_offset: Vector2i = Level.direction_to_vector(direction)
		var edge_offset: Vector3 = level.grid_to_world_position(tile_grid_offset) * 0.5
		var connection_room_type: RoomType = get_connections()[direction]
		var color: Color = profile.room_type.color if profile.room_type else Color.WHEAT
		var connection_color: Color = connection_room_type.color if connection_room_type else color
		DebugDraw3D.draw_line(global_position + Vector3.UP * 0.05, global_position + level.grid_to_world_position(tile_grid_offset) - edge_offset + Vector3.UP * 0.05, connection_color, INF)

func _to_string() -> String:
	return "[%s turned %d times: %s]" % [profile, clockwise_turns, get_connections()]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	if not _hidden_material: warnings.append("Missing hidden material reference.")
	return warnings
