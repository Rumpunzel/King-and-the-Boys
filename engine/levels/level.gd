@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

signal tile_placement_requested(tile_profile: TileProfile, tile_transform: Transform3D)

@export var grid_size: float = 2.0

@export_group("Configuration")
@export var _starting_tile: TileProfile
@export var _available_tiles: Array[TileProfile]

var _placed_tiles: Dictionary[Vector2i, PlacedTile]

@export_group("Configuration")
@export var _navigation_region: NavigationRegion3D

var _grid: Dictionary[Vector3i, GridCell]
var _debugs: Dictionary[Vector3i, Label3D]

func _ready() -> void:
	_request_starting_placed_tile()
	for z: int in range(-32, 32):
		for x: int in range(-32, 32):
			var cell_position: Vector3i = Vector3i(x, 0, z)
			#if not _debugs.has(cell_position): _create_debug_label(cell_position)

static func get_grid_cell_of_node(node: Node3D) -> Vector3i:
	return get_grid_cell(node.global_position)

static func get_grid_cell(world_position: Vector3) -> Vector3i:
	return Vector3i(world_position)

func world_to_grid_position(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / grid_size), floori(world_position.z / grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x, 0.0, grid_position.y) * grid_size

func spawn_at(grid_position: Vector2i, status: PlacedTile.Status = PlacedTile.Status.PLACED) -> void:
	if _placed_tiles.has(grid_position):
		var placed_tile: PlacedTile = _placed_tiles[grid_position]
		assert(placed_tile)
		if status >= placed_tile.status: placed_tile.status = status
		return
	var available_tiles: Array[PlacedTile] = _get_available_tiles_for_position(grid_position)
	assert(not available_tiles.is_empty())
	var fitting_tile: PlacedTile = available_tiles.pick_random()
	assert(fitting_tile)
	fitting_tile.status = status
	_spawn_at(fitting_tile, grid_position)

func spawn_at_all(grid_positions: Array[Vector2i], status: PlacedTile.Status) -> void:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position, status)

func get_placed_tile(grid_position: Vector2i) -> PlacedTile:
	return _placed_tiles.get(grid_position)

func _update_player_vision(origin_grid_position: Vector2i, direction: TileProfile.Direction, vision_radius: float) -> void:
	var tile: PlacedTile = _placed_tiles.get(origin_grid_position)
	assert(tile)
	if not tile.has_connection(direction): return
	assert(tile.has_connection(direction))
	var direction_vector: Vector2i = TileProfile.direction_to_vector(direction)
	var clockwise_vector: Vector2i = Vector2(direction_vector).rotated(-PI * 0.5)
	var counter_clockwise_vector: Vector2i = Vector2(direction_vector).rotated(PI * 0.5)
	var max_vision: int = ceili(vision_radius)
	for radius: int in range(max_vision + 1):
		var tile_grid_position: Vector2i = origin_grid_position + direction_vector * radius
		var revealed: bool = _update_vision_for_tile(tile_grid_position, tile, direction, origin_grid_position, vision_radius)
		if not revealed: continue
		var revaled_tile: PlacedTile = _placed_tiles[tile_grid_position]
		for diagonal_radius: int in range(max_vision - radius + 1):
			var clockwise_direction: TileProfile.Direction = TileProfile.get_direction(Vector2i.ZERO, clockwise_vector)
			_update_vision_for_tile(tile_grid_position + clockwise_vector * diagonal_radius, revaled_tile, clockwise_direction, origin_grid_position, vision_radius, true)
			var counter_clockwise_direction: TileProfile.Direction = TileProfile.get_direction(Vector2i.ZERO, counter_clockwise_vector)
			_update_vision_for_tile(tile_grid_position + counter_clockwise_vector * diagonal_radius, revaled_tile, counter_clockwise_direction, origin_grid_position, vision_radius, true)

func _update_vision_for_tile(tile_grid_position: Vector2i, from_tile: PlacedTile, direction: TileProfile.Direction, origin_grid_position: Vector2i, vision_radius: float, check_connection_type: bool = false) -> bool:
	if not from_tile.has_connection(direction): return false
	if origin_grid_position.distance_squared_to(tile_grid_position) > pow(vision_radius, 2.0): return false
	var tile: PlacedTile = _placed_tiles.get(tile_grid_position)
	if not tile: return false
	var connection_room_type: RoomType = from_tile.get_connection(direction)
	if check_connection_type and (not connection_room_type or not connection_room_type == tile.tile_profile.room_type): return false
	tile.status = PlacedTile.Status.REVEALED
	return true

func _build_dungeon_from(origin_grid_position: Vector2i, direction: TileProfile.Direction) -> void:
	var tile: PlacedTile = _placed_tiles.get(origin_grid_position)
	assert(tile)
	if tile.tile_profile.room_type: _build_room_from(origin_grid_position)
	_build_corridor_from(origin_grid_position, direction)

func _build_corridor_from(origin_grid_position: Vector2i, direction: TileProfile.Direction) -> void:
	var tile: PlacedTile = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var relative_direction: Vector2i = TileProfile.direction_to_vector(direction)
	var grid_position: Vector2i = origin_grid_position + relative_direction
	spawn_at(grid_position)
	var placed_tile: PlacedTile = _placed_tiles[grid_position]
	if not placed_tile.get_connections().has(direction): return
	_build_dungeon_from(grid_position, direction)

func _build_room_from(origin_grid_position: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	if already_visited.has(origin_grid_position): return
	assert(not already_visited.has(origin_grid_position))
	already_visited.append(origin_grid_position)
	var tile: PlacedTile = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var room_type: RoomType = tile.tile_profile.room_type
	assert(room_type)
	for connection: TileProfile.Direction in tile.get_connections().keys():
		var relative_direction: Vector2i = TileProfile.direction_to_vector(connection)
		var grid_position: Vector2i = origin_grid_position + relative_direction
		if already_visited.has(grid_position): continue
		assert(not already_visited.has(grid_position))
		spawn_at(grid_position)
		var placed_tile: PlacedTile = _placed_tiles.get(grid_position)
		if not placed_tile or not placed_tile.tile_profile.room_type == room_type:
			already_visited.append(grid_position)
			continue
		_build_room_from(grid_position, already_visited)

func _get_available_tiles_for_position(new_tile_position: Vector2i) -> Array[PlacedTile]:
	var surrounding_tiles: Dictionary[Vector2i, PlacedTile] = {}
	for y: int in range(new_tile_position.y - 1, new_tile_position.y + 2):
		for x: int in range(new_tile_position.x - 1, new_tile_position.x + 2):
			if not (x == new_tile_position.x or y == new_tile_position.y): continue
			var position_to_check: Vector2i = Vector2i(x, y)
			if _placed_tiles.has(position_to_check):
				var surrounding_tile: PlacedTile = _placed_tiles[position_to_check]
				surrounding_tiles[position_to_check] = surrounding_tile
	var available_tiles: Array[PlacedTile] = _get_all_available_tile_placements()
	for surrounding_tile_grid_position: Vector2i in surrounding_tiles.keys():
		var surrounding_tile: PlacedTile = surrounding_tiles[surrounding_tile_grid_position]
		available_tiles.assign(available_tiles.filter(func(tile: PlacedTile) -> bool: return tile.is_legal_neighbour(surrounding_tile, new_tile_position, surrounding_tile_grid_position)))
	return available_tiles

func _request_starting_placed_tile() -> void:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	assert(_starting_tile)
	var starting_tile: PlacedTile = PlacedTile.create(_starting_tile, 0, PlacedTile.Status.REVEALED)
	var starting_grid_position: Vector2i = world_to_grid_position(player_spawn_point.global_position)
	_spawn_at(starting_tile, starting_grid_position)

func _spawn_at(tile: PlacedTile, grid_position: Vector2i) -> void:
	var tile_position: Vector3 = grid_to_world_position(grid_position) - Vector3(0.0, 0.05, 0.0)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position).rotated_local(Vector3.DOWN, tile.clockwise_turns * PI * 0.5)
	_placed_tiles[grid_position] = tile
	for index: int in tile.get_connection_vectors().size():
		var direction: TileProfile.Direction = tile.get_connections().keys()[index]
		var tile_grid_offset: Vector2i = TileProfile.direction_to_vector(direction)
		var edge_offset: Vector3 = grid_to_world_position(tile_grid_offset) * 0.5
		var connection_room_type: RoomType = tile.get_connections()[direction]
		var color: Color = tile.tile_profile.room_type.color if tile.tile_profile.room_type else Color.WHEAT
		var connection_color: Color = connection_room_type.color if connection_room_type else color
		DebugDraw3D.draw_line(grid_to_world_position(grid_position), grid_to_world_position(grid_position + tile_grid_offset) - edge_offset, connection_color, INF)
	tile_placement_requested.emit(tile.tile_profile, tile_transform)

func _get_all_available_tile_placements() -> Array[PlacedTile]:
	var available_tiles: Array[PlacedTile] = []
	for available_tile: TileProfile in _available_tiles:
		for clockwise_rotation: int in range(4): available_tiles.append(PlacedTile.create(available_tile, clockwise_rotation))
	return available_tiles

func _create_debug_label(cell_position: Vector3i) -> GridDebugLabel:
	var debug_label: GridDebugLabel = GridDebugLabel.new()
	debug_label.cell_position = cell_position
	add_child(debug_label)
	_debugs[cell_position] = debug_label
	return debug_label

func _update_debug(cell_position: Vector3i, grid_cell: GridCell) -> void:
	var debug_label: GridDebugLabel = _debugs.get_or_add(cell_position, _create_debug_label(cell_position))
	debug_label.grid_cell = grid_cell
	debug_label.update_text()

func _on_character_entered_grid_cell(cell_position: Vector3i) -> void:
	var ground_cell: GroundCell = _grid.get_or_add(cell_position, GridCell.get_default())
	ground_cell.times_entered += 1
	_grid[cell_position] = ground_cell
	_update_debug(cell_position, ground_cell)

func _on_structure_created(structure: Structure) -> void:
	if structure.profile is TileProfile:
		var tile_grid_position: Vector2i = world_to_grid_position(structure.global_position)
		var placed_tile: PlacedTile = _placed_tiles[tile_grid_position]
		assert(placed_tile)
		assert(not placed_tile.structure)
		placed_tile.structure = structure
	for cell_position: Vector3i in structure.get_grid_cells():
		var structure_cell: StructureCell = StructureCell.new(structure.profile, cell_position)
		_grid[cell_position] = structure_cell
		_update_debug(cell_position, structure_cell)
	if _navigation_region.is_baking():
		await _navigation_region.bake_finished
		_navigation_region.bake_navigation_mesh()

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	var character: Character = player_ghost.character
	character.level = self
	character.moved.connect(_on_player_moved.bind(character))
	if not character.is_inside_tree(): await character.ready
	_on_player_moved(character)

func _on_player_moved(character: Character) -> void:
	var character_grid_position: Vector2i = world_to_grid_position(character.global_position)
	var tile: PlacedTile = _placed_tiles.get(character_grid_position)
	assert(tile)
	var connections: Array[TileProfile.Direction] = tile.get_connections().keys()
	for direction: TileProfile.Direction in connections: _build_dungeon_from(character_grid_position, direction)
	for direction: TileProfile.Direction in connections: _update_player_vision(character_grid_position, direction, character.profile.vision)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _navigation_region: warnings.append("Missing NavigationRegion3D reference.")
	return warnings
