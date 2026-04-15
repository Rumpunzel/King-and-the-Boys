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

const DIRECTION_VECTORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var grid_size: float = 2.0
@export var grid_extents: Vector2i = Vector2i(13, 13)

@export var _reveals_per_second: float = 16.0
@export var _discovers_per_second: float = 2.0

@export_group("Configuration")
@export var _starting_tile: StructureProfile
@export var _tile_set: DungeonTileSet

var _placed_tiles: Dictionary[Vector2i, Structure]
# {Structure -> Array[Structure]}
var _tile_connections: Dictionary[Structure, Array]
var _tile_connectors: Dictionary[Vector3, Structure]

var _placed_things: Dictionary[Vector2i, Thing]

var _reveal_queue: Array[Structure] = []
# Direction -> Array[Structure]
var _discover_queue: Dictionary[Direction, Array] = {}

var _remaining_tile_reveal_delay: float = 0.0
var _remaining_tile_discover_delay: float = 0.0

func _ready() -> void:
	_build_outer_wall()

func _process(delta: float) -> void:
	# Reveal
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
	# Discover
	_remaining_tile_discover_delay = maxf(_remaining_tile_discover_delay - delta, 0.0)
	if _remaining_tile_discover_delay <= 0.0:
		for direction: Direction in Direction.values():
			var discover_queue: Array[Structure] = _discover_queue.get(direction, [] as Array[Structure])
			var tile_to_discover: Structure = null
			while not discover_queue.is_empty() and not tile_to_discover:
				tile_to_discover = discover_queue.pop_front()
				if tile_to_discover.status >= Structure.Status.DISCOVERED: tile_to_discover = null
			if tile_to_discover:
				tile_to_discover.discover()
				_remaining_tile_discover_delay += 1.0 / _discovers_per_second / Direction.size()

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

func build_level() -> void:
	assert(is_multiplayer_authority())
	var starting_grid_position: Vector2i = _place_starting_tile()
	_build_dungeon_from(starting_grid_position)

func world_to_grid_position(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x / grid_size), roundi(world_position.z / grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x, 0.0, grid_position.y) * grid_size

func spawn_at(grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	assert(absi(grid_position.x) < grid_extents.x)
	assert(absi(grid_position.y) < grid_extents.y)
	if _placed_tiles.has(grid_position):
		var placed_tile: Structure = _placed_tiles[grid_position]
		assert(placed_tile)
		if status >= placed_tile.status: placed_tile.status = status
		return
	var fitting_blueprint: DungeonTileSet.TileBlueprint = _tile_set.get_tile_blueprint_for(grid_position, _get_surrounding_tiles(grid_position))
	assert(fitting_blueprint)
	_spawn_at(fitting_blueprint, grid_position, status)

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
	if origin_grid_position.distance_squared_to(from_grid_position) > vision_radius ** 2.0: return
	var from_tile: Structure = _placed_tiles.get(from_grid_position)
	assert(from_tile)
	if reveal_check.call(from_tile): reveal_function.call(from_tile, Direction.UP)
	var origin_tile_room_type: RoomType = _placed_tiles[origin_grid_position].profile.room_type
	for direction: Direction in from_tile.get_connections():
		if not from_tile.has_connection(direction): continue
		var direction_vector: Vector2i = direction_to_vector(direction)
		var tile_grid_position: Vector2i = from_grid_position + direction_vector
		var tile: Structure = _placed_tiles.get(tile_grid_position)
		for radius: int in range(1, ceili(vision_radius) + 1):
			var next_tile_grid_position: Vector2i = from_grid_position + direction_vector * radius
			if origin_grid_position.distance_squared_to(next_tile_grid_position) > vision_radius ** 2.0: continue
			if not _placed_tiles.has(next_tile_grid_position): continue
			var next_tile: Structure = _placed_tiles.get(next_tile_grid_position)
			assert(next_tile)
			if reveal_check.call(next_tile): reveal_function.call(next_tile, direction)
			#await get_tree().process_frame
		if not origin_tile_room_type or origin_tile_room_type != tile.profile.room_type: continue
		_update_player_vision_in_room(tile_grid_position, direction, vision_radius, reveal_check, reveal_function, origin_grid_position)

func _update_player_vision_in_room(from_grid_position: Vector2i, direction: Direction, vision_radius: float, reveal_check: Callable, reveal_function: Callable, origin_grid_position: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > vision_radius ** 2.0: return
	var from_tile: Structure = _placed_tiles.get(from_grid_position)
	assert(from_tile)
	if reveal_check.call(from_tile): reveal_function.call(from_tile, direction)
	var origin_tile_room_type: RoomType = _placed_tiles[origin_grid_position].profile.room_type
	assert(origin_tile_room_type)
	assert(from_tile.profile.room_type == origin_tile_room_type)
	for connection: Direction in from_tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(connection)
		var tile_grid_position: Vector2i = from_grid_position + direction_vector
		var tile: Structure = _placed_tiles.get(tile_grid_position)
		if origin_tile_room_type == tile.profile.room_type and not already_visited.has(tile_grid_position):
			already_visited.append(from_grid_position)
			await get_tree().process_frame
			_update_player_vision_in_room(tile_grid_position, direction, vision_radius, reveal_check, reveal_function, origin_grid_position, already_visited)

func _build_dungeon_from(origin_grid_position: Vector2i) -> void:
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var already_visited: Array[Vector2i] = [origin_grid_position]
	if tile.profile.room_type: _build_room_from(origin_grid_position, tile.profile.room_type, already_visited)
	for direction: Direction in tile.get_connections(): _build_corridor_from(origin_grid_position, direction, already_visited)

func _build_corridor_from(origin_grid_position: Vector2i, direction: Direction, already_visited: Array[Vector2i]) -> void:
	already_visited.append(origin_grid_position)
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var relative_direction: Vector2i = direction_to_vector(direction)
	var index: int = 0
	while tile.has_connection(direction):
		var grid_position: Vector2i = origin_grid_position + relative_direction * index
		already_visited.append(origin_grid_position)
		spawn_at(grid_position)
		tile = _placed_tiles[grid_position]
		if tile.profile.room_type: _build_room_from(grid_position, tile.profile.room_type, already_visited)
		for connection: Direction in tile.get_connections():
			if connection == direction: continue
			var neighbour_direction: Vector2i = direction_to_vector(connection)
			var neighbour_position: Vector2i = grid_position + neighbour_direction
			spawn_at(neighbour_position)
		index += 1

func _build_room_from(origin_grid_position: Vector2i, room_type: RoomType, already_visited: Array[Vector2i]) -> void:
	assert(room_type)
	if already_visited.has(origin_grid_position): return
	already_visited.append(origin_grid_position)
	var tile: Structure = _placed_tiles.get(origin_grid_position)
	assert(tile)
	if not room_type == tile.profile.room_type: return
	for connection: Direction in tile.get_connections():
		var relative_direction: Vector2i = direction_to_vector(connection)
		var grid_position: Vector2i = origin_grid_position + relative_direction
		if already_visited.has(grid_position): continue
		spawn_at(grid_position)
		_build_room_from(grid_position, room_type, already_visited)

func _place_starting_tile() -> Vector2i:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	assert(_starting_tile)
	var starting_tile_blueprint: DungeonTileSet.TileBlueprint = DungeonTileSet.TileBlueprint.new(_starting_tile, 0)
	var starting_grid_position: Vector2i = world_to_grid_position(player_spawn_point.global_position)
	_spawn_at(starting_tile_blueprint, starting_grid_position)
	var starting_tile: Structure = _placed_tiles.get(starting_grid_position)
	assert(starting_tile)
	starting_tile.reveal()
	return starting_grid_position

func _build_outer_wall() -> void:
	for y: int in range(-grid_extents.y, grid_extents.y + 1):
		for x: int in range(-grid_extents.x, grid_extents.x + 1):
			if absi(y) != grid_extents.y and absi(x) != grid_extents.x: continue
			var wall_roation: int = 1 if absi(y) == grid_extents.y else 0
			var wall_position: Vector2i = Vector2i(x, y)
			_spawn_at(DungeonTileSet.TileBlueprint.new(preload("uid://d3cc5nj7ogal8"), wall_roation), wall_position)
			var wall: Structure = _placed_tiles.get(wall_position)
			wall.reveal()

func _spawn_at(tile_blueprint: DungeonTileSet.TileBlueprint, grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	assert(absi(grid_position.x) <= grid_extents.x)
	assert(absi(grid_position.y) <= grid_extents.y)
	var tile_position: Vector3 = grid_to_world_position(grid_position)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position)
	tile_placement_requested.emit(tile_blueprint.profile, tile_transform, tile_blueprint.clockwise_turns, status)

func _queue_reveal(tile: Structure, _direction: Direction) -> void:
	if _reveal_queue.has(tile): return
	_reveal_queue.append(tile)

func _queue_discover(tile: Structure, direction: Direction) -> void:
	var queued_discovers: Array[Structure] = _discover_queue.get_or_add(direction, [] as Array[Structure])
	if queued_discovers.has(tile): return
	queued_discovers.append(tile)

func _get_surrounding_tiles(grid_position: Vector2i) -> Array[Structure]:
	var surrounding_tiles: Array[Structure] = []
	for direction_vector: Vector2i in DIRECTION_VECTORS:
		var position_to_check: Vector2i = grid_position + direction_vector
		if not _placed_tiles.has(position_to_check): continue
		var surrounding_tile: Structure = _placed_tiles[position_to_check]
		surrounding_tiles.append(surrounding_tile)
	return surrounding_tiles

func _create_connection(tile: Structure, connection: Direction) -> void:
	assert(tile)
	var direction_vector: Vector2i = direction_to_vector(connection)
	var connection_position: Vector3 = tile.global_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5 * tile.model.get_max_mesh_scale()
	var tile_connection: Structure = _tile_set.tile_connection.create(-1, Transform3D(Basis.IDENTITY, connection_position), connection, Structure.Status.PLACED)
	var tile_connections: Array[Structure] = _tile_connections.get_or_add(tile, [] as Array[Structure])
	assert(not tile_connections.has(tile))
	tile_connections.append(tile_connection)
	add_child(tile_connection)

func _create_connector(tile_position: Vector3, connection: Direction) -> void:
	var direction_vector: Vector2i = direction_to_vector(connection)
	var connector_position: Vector3 = tile_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5
	if _tile_connectors.has(connector_position): return
	var tile_connector: Structure = _tile_set.tile_connector.create(-1, Transform3D(Basis.IDENTITY, connector_position), connection, Structure.Status.PLACED)
	_tile_connectors[connector_position] = tile_connector
	add_child(tile_connector)

func _on_structure_created(structure: Structure) -> void:
	structure.level = self
	var tile_grid_position: Vector2i = world_to_grid_position(structure.global_position)
	_placed_tiles[tile_grid_position] = structure
	for connection: Direction in structure.get_connections():
		_create_connection(structure, connection)
		_create_connector(structure.global_position, connection)
	structure.status_changed.connect(_on_tile_status_changed.bind(structure))

func _on_tile_status_changed(status: Structure.Status, tile: Structure) -> void:
	var grid_position: Vector2i = tile.get_grid_position()
	if _placed_things.has(grid_position):
		var thing_on_tile: Thing = _placed_things[grid_position]
		thing_on_tile.status = Thing.structure_status_to_thing_status(tile.status)
	if not status == Structure.Status.REVEALED: return
	await get_tree().create_timer(0.5).timeout
	for connection: Direction in tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(connection)
		for tile_connection: Structure in _tile_connections[tile]: tile_connection.reveal()
		var neighbour_position: Vector2i = grid_position + direction_vector
		assert(_placed_tiles.has(neighbour_position))
		var neighbour: Structure = _placed_tiles[neighbour_position]
		if not neighbour.status == Structure.Status.REVEALED:
			neighbour.discover()
			continue
		var connector_position: Vector3 = tile.global_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5
		var tile_connector: Structure = _tile_connectors[connector_position]
		tile_connector.reveal()

func _on_thing_created(thing: Thing) -> void:
	var thing_grid_position: Vector2i = world_to_grid_position(thing.global_position)
	_placed_things[thing_grid_position] = thing

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	var character: Character = player_ghost.character
	character.level = self
	if not multiplayer.is_server(): return
	character.entered_grid_cell.connect(_on_player_moved.bind(character))

func _on_player_moved(character_grid_position: Vector2i, character: Character) -> void:
	var entered_tile: Structure = _placed_tiles.get(character_grid_position)
	assert(entered_tile)
	_build_dungeon_from(character_grid_position)
	_update_player_vision(character_grid_position, character.profile.vision, func(tile: Structure) -> bool: return tile.status < Structure.Status.REVEALED, _queue_reveal)
	_update_player_vision(character_grid_position, character.profile.vision + character.profile.dark_vision, func(tile: Structure) -> bool: return tile.status < Structure.Status.DISCOVERED, _queue_discover)
	_remaining_tile_reveal_delay = character.profile.move_animation.duration * 0.1
	_remaining_tile_discover_delay = character.profile.move_animation.duration * 0.1

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
