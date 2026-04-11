@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

signal tile_placement_requested(tile_profile: StructureProfile, tile_transform: Transform3D, clockwise_turns: int, tile_status: Structure.Status)

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

@export var grid_size: float = 2.0

@export var _reveals_per_second: float = 32.0
@export var _discovers_per_second: float = 8.0

@export_group("Configuration")
@export var _starting_tile: StructureProfile
@export var _available_tiles: Array[StructureProfile]
@export var _emergency_tiles: Array[StructureProfile]

@export_group("Configuration")
@export var _navigation_region: NavigationRegion3D

var _placed_tiles: Dictionary[Vector2i, Structure]

var _grid: Dictionary[Vector3i, GridCell]
var _debugs: Dictionary[Vector3i, Label3D]

var _reveal_queue: Array[Structure] = []
var _discover_queue: Array[Structure] = []

var _remaining_tile_reveal_delay: float = 0.0
var _remaining_tile_discover_delay: float = 0.0

@onready var _available_tile_blueprints: Array[TileBlueprint] = _generate_blueprints(_available_tiles)
@onready var _emergency_tile_blueprints: Array[TileBlueprint] = _generate_blueprints(_emergency_tiles)

func _ready() -> void:
	if not is_multiplayer_authority(): return
	_request_starting_placed_tile()
	for z: int in range(-32, 32):
		for x: int in range(-32, 32):
			var cell_position: Vector3i = Vector3i(x, 0, z)
			#if not _debugs.has(cell_position): _create_debug_label(cell_position)

func _process(delta: float) -> void:
	_remaining_tile_reveal_delay = maxf(_remaining_tile_reveal_delay - delta, 0.0)
	if _remaining_tile_reveal_delay <= 0.0:
		var tile_to_reveal: Structure = null
		while not _reveal_queue.is_empty() and not tile_to_reveal:
			tile_to_reveal = _reveal_queue.pop_front()
			if tile_to_reveal.status >= Structure.Status.REVEALED: tile_to_reveal = null
		if tile_to_reveal:
			tile_to_reveal.reveal()
			_remaining_tile_reveal_delay += 1.0 / _reveals_per_second
	if not _reveal_queue.is_empty(): return
	_remaining_tile_discover_delay = maxf(_remaining_tile_discover_delay - delta, 0.0)
	if _remaining_tile_discover_delay <= 0.0:
		var tile_to_discover: Structure = null
		while not _discover_queue.is_empty() and not tile_to_discover:
			tile_to_discover = _discover_queue.pop_front()
			if tile_to_discover.status >= Structure.Status.DISCOVERED: tile_to_discover = null
		if tile_to_discover:
			tile_to_discover.discover()
			_remaining_tile_discover_delay += 1.0 / _discovers_per_second

static func direction_to_vector(direction: Direction) -> Vector2i:
	match direction:
		Direction.UP: return Vector2i.UP
		Direction.RIGHT: return Vector2i.RIGHT
		Direction.DOWN: return Vector2i.DOWN
		Direction.LEFT: return Vector2i.LEFT
		_: push_error("direction %s is not implemented!" % direction)
	assert(false)
	return Vector2i.ZERO

static func get_direction(first_grid_position: Vector2i, second_grid_position: Vector2i) -> Direction:
	var delta_grid_position: Vector2i = second_grid_position - first_grid_position
	match delta_grid_position:
		Vector2i.UP: return Direction.UP
		Vector2i.RIGHT: return Direction.RIGHT
		Vector2i.DOWN: return Direction.DOWN
		Vector2i.LEFT: return Direction.LEFT
		_: push_error("delta_grid_position %s is not implemented!" % delta_grid_position)
	assert(false)
	return Direction.UP

func world_to_grid_position(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / grid_size), floori(world_position.z / grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x, 0.0, grid_position.y) * grid_size

func spawn_at(grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	if _placed_tiles.has(grid_position):
		var placed_tile: Structure = _placed_tiles[grid_position]
		assert(placed_tile)
		if status >= placed_tile.status: placed_tile.status = status
		return
	var tile_blueprints: Array[TileBlueprint] = _get_available_tile_blueprints_for_position(grid_position)
	assert(not tile_blueprints.is_empty())
	var fitting_tile_blueprint: TileBlueprint = tile_blueprints.pick_random()
	assert(fitting_tile_blueprint)
	_spawn_at(fitting_tile_blueprint, grid_position, status)

func spawn_at_all(grid_positions: Array[Vector2i], status: Structure.Status) -> void:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position, status)

func get_placed_tile(grid_position: Vector2i) -> Structure:
	return _placed_tiles.get(grid_position)

func _update_player_vision(
	from_grid_position: Vector2i,
	vision_radius: float,
	reveal_check: Callable,
	reveal_function: Callable,
	origin_grid_position: Vector2i = from_grid_position,
) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > pow(vision_radius, 2.0): return
	var from_tile: Structure = _placed_tiles.get(from_grid_position)
	assert(from_tile)
	if reveal_check.call(from_tile): reveal_function.call(from_tile)
	var origin_tile_room_type: RoomType = _placed_tiles[origin_grid_position].profile.room_type
	for direction: Direction in from_tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(direction)
		var tile_grid_position: Vector2i = from_grid_position + direction_vector
		var tile: Structure = _placed_tiles.get(tile_grid_position)
		_update_player_vision_in_direction(tile_grid_position, direction, vision_radius, reveal_check, reveal_function, origin_grid_position)
		if not origin_tile_room_type or origin_tile_room_type != tile.profile.room_type: continue
		_update_player_vision_in_room(tile_grid_position, vision_radius, reveal_check, reveal_function, origin_grid_position)

func _update_player_vision_in_direction(from_grid_position: Vector2i, direction: Direction, vision_radius: float, reveal_check: Callable, reveal_function: Callable, origin_grid_position: Vector2i) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > pow(vision_radius, 2.0): return
	var from_tile: Structure = _placed_tiles.get(from_grid_position)
	assert(from_tile)
	if reveal_check.call(from_tile): reveal_function.call(from_tile)
	if not from_tile.has_connection(direction): return
	var direction_vector: Vector2i = direction_to_vector(direction)
	for radius: int in range(1, ceili(vision_radius) + 1):
		var tile_grid_position: Vector2i = from_grid_position + direction_vector * radius
		if not _placed_tiles.has(tile_grid_position): return
		_update_player_vision_in_direction(tile_grid_position, direction, vision_radius, reveal_check, reveal_function, origin_grid_position)

func _update_player_vision_in_room(from_grid_position: Vector2i, vision_radius: float, reveal_check: Callable, reveal_function: Callable, origin_grid_position: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > pow(vision_radius, 2.0): return
	var from_tile: Structure = _placed_tiles.get(from_grid_position)
	assert(from_tile)
	if reveal_check.call(from_tile): reveal_function.call(from_tile)
	var origin_tile_room_type: RoomType = _placed_tiles[origin_grid_position].profile.room_type
	assert(origin_tile_room_type)
	assert(from_tile.profile.room_type == origin_tile_room_type)
	for direction: Direction in from_tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(direction)
		var tile_grid_position: Vector2i = from_grid_position + direction_vector
		var tile: Structure = _placed_tiles.get(tile_grid_position)
		if origin_tile_room_type == tile.profile.room_type and not already_visited.has(tile_grid_position):
			already_visited.append(from_grid_position)
			_update_player_vision_in_room(tile_grid_position, vision_radius, reveal_check, reveal_function, origin_grid_position, already_visited)

func _build_dungeon_from(origin_grid_position: Vector2i, direction: Direction) -> void:
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	if tile.profile.room_type: _build_room_from(origin_grid_position)
	_build_corridor_from(origin_grid_position, direction)

func _build_corridor_from(origin_grid_position: Vector2i, direction: Direction) -> void:
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var relative_direction: Vector2i = direction_to_vector(direction)
	var grid_position: Vector2i = origin_grid_position + relative_direction
	spawn_at(grid_position)
	var placed_tile: Structure = _placed_tiles[grid_position]
	if not placed_tile.get_connections().has(direction): return
	_build_dungeon_from(grid_position, direction)

func _build_room_from(origin_grid_position: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	if already_visited.has(origin_grid_position): return
	assert(not already_visited.has(origin_grid_position))
	already_visited.append(origin_grid_position)
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var room_type: RoomType = tile.profile.room_type
	assert(room_type)
	for connection: Direction in tile.get_connections().keys():
		var relative_direction: Vector2i = direction_to_vector(connection)
		var grid_position: Vector2i = origin_grid_position + relative_direction
		if already_visited.has(grid_position): continue
		assert(not already_visited.has(grid_position))
		spawn_at(grid_position)
		var placed_tile: Structure = _placed_tiles.get(grid_position)
		if not placed_tile or not placed_tile.profile.room_type == room_type:
			already_visited.append(grid_position)
			continue
		_build_room_from(grid_position, already_visited)

func _get_available_tile_blueprints_for_position(new_tile_position: Vector2i) -> Array[TileBlueprint]:
	var surrounding_tiles: Dictionary[Vector2i, Structure] = {}
	for y: int in range(new_tile_position.y - 1, new_tile_position.y + 2):
		for x: int in range(new_tile_position.x - 1, new_tile_position.x + 2):
			if not (x == new_tile_position.x or y == new_tile_position.y): continue
			var position_to_check: Vector2i = Vector2i(x, y)
			if _placed_tiles.has(position_to_check):
				var surrounding_tile: Structure = _placed_tiles[position_to_check]
				surrounding_tiles[position_to_check] = surrounding_tile
	var tile_blueprints: Array[TileBlueprint] = _available_tile_blueprints.duplicate()
	for surrounding_tile_grid_position: Vector2i in surrounding_tiles.keys():
		var surrounding_tile: Structure = surrounding_tiles[surrounding_tile_grid_position]
		tile_blueprints.assign(tile_blueprints.filter(func(tile: TileBlueprint) -> bool: return tile.is_legal_neighbour(surrounding_tile, new_tile_position)))
	if not tile_blueprints.is_empty(): return tile_blueprints
	print_debug("No fitting tile found; looking for emergency tile.")
	tile_blueprints = _emergency_tile_blueprints.duplicate()
	for surrounding_tile_grid_position: Vector2i in surrounding_tiles.keys():
		var surrounding_tile: Structure = surrounding_tiles[surrounding_tile_grid_position]
		tile_blueprints.assign(tile_blueprints.filter(func(tile: TileBlueprint) -> bool: return tile.is_legal_neighbour(surrounding_tile, new_tile_position)))
	return tile_blueprints

func _request_starting_placed_tile() -> void:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	assert(_starting_tile)
	var starting_tile: TileBlueprint = TileBlueprint.new(_starting_tile, 0)
	var starting_grid_position: Vector2i = world_to_grid_position(player_spawn_point.global_position)
	_spawn_at(starting_tile, starting_grid_position, Structure.Status.REVEALED)

func _spawn_at(tile_blueprint: TileBlueprint, grid_position: Vector2i, status: Structure.Status) -> void:
	var tile_position: Vector3 = grid_to_world_position(grid_position) - Vector3(0.0, 0.05, 0.0)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position)
	tile_placement_requested.emit(tile_blueprint.profile, tile_transform, tile_blueprint.clockwise_turns, status)

func _generate_blueprints(for_profiles: Array[StructureProfile]) -> Array[TileBlueprint]:
	var available_tile_blueprints: Array[TileBlueprint] = []
	for profile: StructureProfile in for_profiles:
		for clockwise_rotation: int in range(4): available_tile_blueprints.append(TileBlueprint.new(profile, clockwise_rotation))
	return available_tile_blueprints

func _on_character_entered_grid_cell(cell_position: Vector3i) -> void:
	var ground_cell: GroundCell = _grid.get_or_add(cell_position, GridCell.get_default())
	ground_cell.times_entered += 1
	_grid[cell_position] = ground_cell
	_update_debug(cell_position, ground_cell)

func _on_structure_created(structure: Structure) -> void:
	structure.level = self
	var tile_grid_position: Vector2i = world_to_grid_position(structure.global_position)
	_placed_tiles[tile_grid_position] = structure
	for cell_position: Vector2i in structure.get_grid_cells():
		var vector3: Vector3i = Vector3i(cell_position.x, 0, cell_position.y)
		var structure_cell: StructureCell = StructureCell.new(structure.profile, vector3)
		_grid[vector3] = structure_cell
		_update_debug(vector3, structure_cell)
	#if _navigation_region.is_baking():
		#await _navigation_region.bake_finished
		#_navigation_region.bake_navigation_mesh()

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	var character: Character = player_ghost.character
	character.level = self
	character.entered_grid_cell.connect(_on_player_moved.bind(character))
	#if not character.is_inside_tree(): await character.ready
	#_on_player_moved(world_to_grid_position(character.global_position), character)

func _on_player_moved(character_grid_position: Vector2i, character: Character) -> void:
	var entered_tile: Structure = _placed_tiles.get(character_grid_position)
	assert(entered_tile)
	var connections: Array[Direction] = entered_tile.get_connections().keys()
	for direction: Direction in connections: _build_dungeon_from(character_grid_position, direction)
	_update_player_vision(character_grid_position, character.profile.vision, func(tile: Structure) -> bool: return tile.status < Structure.Status.REVEALED, func(tile: Structure) -> void: _reveal_queue.append(tile))
	_update_player_vision(character_grid_position, 32.0, func(tile: Structure) -> bool: return tile.status < Structure.Status.DISCOVERED, func(tile: Structure) -> void: _discover_queue.append(tile))

func _create_debug_label(cell_position: Vector3i) -> GridDebugLabel:
	var debug_label: GridDebugLabel = GridDebugLabel.new()
	debug_label.cell_position = cell_position
	add_child(debug_label)
	_debugs[cell_position] = debug_label
	return debug_label

func _update_debug(cell_position: Vector3i, grid_cell: GridCell) -> void:
	var debug_label: GridDebugLabel = _debugs.get_or_add(cell_position, _create_debug_label(cell_position * grid_size))
	debug_label.grid_cell = grid_cell
	debug_label.update_text()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _navigation_region: warnings.append("Missing NavigationRegion3D reference.")
	return warnings

class TileBlueprint extends RefCounted:
	var profile: StructureProfile
	var clockwise_turns: int
	
	func _init(for_profile: StructureProfile, with_clockwise_turns: int = 0) -> void:
		profile = for_profile
		clockwise_turns = with_clockwise_turns
	
	func is_legal_neighbour(existing_tile: Structure, grid_position: Vector2i) -> bool:
		# Check horizontal/vertical neighbours
		var direction: Level.Direction = Level.get_direction(grid_position, existing_tile.get_grid_position())
		var reverse_direction: Level.Direction = Level.get_direction(existing_tile.get_grid_position(), grid_position)
		if not has_connection(direction) and not existing_tile.has_connection(reverse_direction): return true
		# Must have opposite connections
		if has_connection(direction) != existing_tile.has_connection(reverse_direction): return false
		return can_connect(direction, existing_tile.profile.room_type) and existing_tile.can_connect(reverse_direction, profile.room_type)
	
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
	
	func _get_adjusted_direction(direction: Level.Direction) -> Level.Direction:
		var direction_count: int = Level.Direction.size()
		return posmod(direction + clockwise_turns * (direction_count / 4), direction_count)
