@tool
class_name PlacedTile
extends Resource

enum Status {
	NONE = -1,
	PLACED,
	DISCOVERED,
	REVEALED,
}

@export var tile_profile: TileProfile
@export var clockwise_turns: int = 0:
	set(new_rotation): clockwise_turns = posmod(new_rotation, 4)

@export var status: Status = Status.NONE:
	set(new_status):
		if new_status == status: return
		var old_status: Status = status
		status = new_status
		if not structure: return
		_update_model()
		if old_status < Status.PLACED: return
		var model: Model = structure.model
		match status:
			Status.DISCOVERED:
				var tween: Tween = model.create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.4)
			Status.REVEALED:
				var tween: Tween = model.create_tween()
				tween.set_parallel()
				tween.tween_property(model, "position:y", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "rotation:x", PI, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.4)

var structure: Structure:
	set(new_structure):
		assert(not structure or new_structure)
		structure = new_structure
		_update_model()

@export_group("Configuration")
@export var _hidden_material: Material = preload("res://protoype_assets/quaternius/medieval_village/Buildings/GLB/Windows.material")

static func create(
	with_tile_profile: TileProfile,
	with_clockwise_turns: int = 0,
	with_status: Status = Status.PLACED,
	with_structure: Structure = null,
) -> PlacedTile:
	var new_placed_tile: PlacedTile = PlacedTile.new()
	new_placed_tile.tile_profile = with_tile_profile
	new_placed_tile.clockwise_turns = with_clockwise_turns
	new_placed_tile.status = with_status
	if with_structure: new_placed_tile.structure = with_structure
	return new_placed_tile

func discover() -> bool:
	if status >= Status.DISCOVERED: return false
	status = Status.DISCOVERED
	return true

func reveal() -> bool:
	if status >= Status.REVEALED: return false
	status = Status.REVEALED
	return true

func is_legal_neighbour(other_placed_tile: PlacedTile, first_grid_position: Vector2i, second_grid_position: Vector2i) -> bool:
	# Check horizontal/vertical neighbours
	var direction: TileProfile.Direction = TileProfile.get_direction(first_grid_position, second_grid_position)
	var reverse_direction: TileProfile.Direction = TileProfile.get_direction(second_grid_position, first_grid_position)
	if not has_connection(direction) and not other_placed_tile.has_connection(reverse_direction): return true
	# Must have opposite connections
	if has_connection(direction) != other_placed_tile.has_connection(reverse_direction): return false
	return can_connect(direction, other_placed_tile.tile_profile.room_type) and other_placed_tile.can_connect(reverse_direction, tile_profile.room_type)

func has_connection(direction: TileProfile.Direction) -> bool:
	return get_connections().has(direction)

func get_connection(direction: TileProfile.Direction) -> RoomType:
	assert(has_connection(direction))
	return get_connections()[direction]

func can_connect(direction: TileProfile.Direction, room_type: RoomType) -> bool:
	if not has_connection(direction): return false
	var connections: Dictionary[TileProfile.Direction, RoomType] = get_connections()
	var required_room_type: RoomType = connections[direction]
	return not required_room_type or room_type == required_room_type

func get_connections() -> Dictionary[TileProfile.Direction, RoomType]:
	var adjusted_connections: Dictionary[TileProfile.Direction, RoomType] = {}
	for connection: TileProfile.Direction in tile_profile.connections.keys():
		adjusted_connections[_get_adjusted_direction(connection)] = tile_profile.connections[connection]
	return adjusted_connections

func get_connection_vectors() -> Array[Vector2i]:
	var connection_vectors: Array[Vector2i]
	connection_vectors.assign(get_connections().keys().map(func(direction: TileProfile.Direction) -> Vector2i: return TileProfile.direction_to_vector(direction)))
	return connection_vectors

func _update_model() -> void:
	assert(structure)
	var model: Model = structure.model
	assert(model)
	match status:
		Status.PLACED: model.visible = false
		Status.DISCOVERED:
			model.apply_material_override(_hidden_material)
			model.visible = true
		Status.REVEALED:
			model.visible = true
			model.remove_material_override(_hidden_material)
		_: push_error("Status %s not implemented!" % status)

func _get_adjusted_direction(direction: TileProfile.Direction) -> TileProfile.Direction:
	var direction_count: int = TileProfile.Direction.size()
	return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)

func _to_string() -> String:
	return "[%s turned %d times: %s]" % [tile_profile, clockwise_turns, get_connections()]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
