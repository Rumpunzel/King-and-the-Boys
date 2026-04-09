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

func spawn_at(grid_position: Vector2i, status: PlacedTile.Status) -> void:
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

func _update_player_vision(character: Character) -> void:
	var character_grid_position: Vector2i = world_to_grid_position(character.global_position)
	var tile: PlacedTile = _placed_tiles.get(character_grid_position)
	assert(tile)
	var vision: Array[TileProfile.Direction] = tile.get_connections()
	for direction: TileProfile.Direction in vision: _build_from_into(character_grid_position, direction)
	for direction: TileProfile.Direction in vision: _build_from_into(character_grid_position, direction, character.profile.vision, PlacedTile.Status.REVEALED)

func _build_from_into(origin_grid_position: Vector2i, direction: TileProfile.Direction, max_iterations: int = -1, tile_status: PlacedTile.Status = PlacedTile.Status.PLACED) -> void:
	if max_iterations == 0: return
	var tile: PlacedTile = _placed_tiles.get(origin_grid_position)
	assert(tile)
	var relative_direction: Vector2i = TileProfile.direction_to_vector(direction)
	var grid_position: Vector2i = origin_grid_position + relative_direction
	spawn_at(grid_position, tile_status)
	var placed_tile: PlacedTile = _placed_tiles[grid_position]
	if not placed_tile.get_connections().has(direction): return
	_build_from_into(grid_position, direction, max_iterations - 1, tile_status)

func _get_available_tiles_for_position(new_tile_position: Vector2i) -> Array[PlacedTile]:
	var surrounding_tiles: Dictionary[Vector2i, PlacedTile] = {}
	for y: int in range(new_tile_position.y - 1, new_tile_position.y + 2):
		for x: int in range(new_tile_position.x - 1, new_tile_position.x + 2):
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
	for tile_grid_offset: Vector2i in tile.get_connection_vectors():
		var edge_offset: Vector3 = grid_to_world_position(tile_grid_offset) * 0.5
		DebugDraw3D.draw_line(grid_to_world_position(grid_position), grid_to_world_position(grid_position + tile_grid_offset) - edge_offset, Color.WHEAT, INF)
	for tile_grid_offset: Vector2i in tile.get_corner_connection_vectors():
		var edge_offset: Vector3 = grid_to_world_position(tile_grid_offset) * 0.5
		DebugDraw3D.draw_line(grid_to_world_position(grid_position), grid_to_world_position(grid_position + tile_grid_offset) - edge_offset, Color.MAROON, INF)
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
	_update_player_vision(character)

func _on_player_moved(character: Character) -> void:
	_update_player_vision(character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _navigation_region: warnings.append("Missing NavigationRegion3D reference.")
	return warnings
