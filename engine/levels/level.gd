@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

signal tile_placement_requested(tile_profile: TileProfile, tile_transform: Transform3D)

@export var _grid_size: float = 2.0

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
	return Vector2i(floori(world_position.x / _grid_size), floori(world_position.z / _grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x * _grid_size, 0.0, grid_position.y * _grid_size)

func spawn_at(grid_position: Vector2i) -> void:
	if _placed_tiles.has(grid_position):
		print_debug("Skipping spawning tile at %s, already a tile there!" % grid_position)
		return
	var available_tiles: Array[PlacedTile] = _get_available_tiles_for_tile(grid_position)
	assert(not available_tiles.is_empty())
	var fitting_tile: PlacedTile = available_tiles.pick_random()
	assert(fitting_tile)
	_spawn_at(fitting_tile, grid_position)

func spawn_at_all(grid_positions: Array[Vector2i]) -> void:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position)

func _update_player_vision(character: Character) -> void:
	var character_grid_position: Vector2i = world_to_grid_position(character.global_position)
	var blocked_vision: Array[Vector2i] = []
	blocked_vision.assign(_get_vision_for_tile(character_grid_position, character.profile.vision))
	var visible_adjacent_tiles: Array[Vector2i] = []
	visible_adjacent_tiles.assign(blocked_vision.map(func(direction: Vector2i) -> Vector2i: return character_grid_position + direction))
	spawn_at_all(visible_adjacent_tiles)

func _get_vision_for_tile(tile_position: Vector2i, vision: Array[Vector2i]) -> Array[Vector2i]:
	var tile: PlacedTile = _placed_tiles.get(tile_position)
	if not tile: return []
	assert(tile)
	var blocked_vision: Array[Vector2i] = []
	blocked_vision.assign(vision.filter(func(direction: Vector2i) -> bool: return tile.has_connection(TileProfile.get_direction(tile_position + direction, tile_position))))
	return blocked_vision

func _get_available_tiles_for_tile(new_tile_position: Vector2i) -> Array[PlacedTile]:
	var surrounding_tiles: Dictionary[Vector2i, PlacedTile] = {}
	for y: int in range(new_tile_position.y - 1, new_tile_position.y + 2):
		for x: int in range(new_tile_position.x - 1, new_tile_position.x + 2):
			var position_to_check: Vector2i = Vector2i(x, y)
			if _placed_tiles.has(position_to_check):
				var surrounding_tile: PlacedTile = _placed_tiles[position_to_check]
				surrounding_tiles[position_to_check] = surrounding_tile
	var available_tiles: Array[PlacedTile] = _get_all_available_tile_placements()
	for surrounding_tile_grid_position: Vector2i in surrounding_tiles.keys():
		var direction: TileProfile.Direction = TileProfile.get_direction(new_tile_position, surrounding_tile_grid_position)
		var reverse_direction: TileProfile.Direction = TileProfile.get_direction(surrounding_tile_grid_position, new_tile_position)
		var surrounding_tile: PlacedTile = surrounding_tiles[surrounding_tile_grid_position]
		var open_connection: bool = surrounding_tile.has_connection(direction)
		available_tiles.assign(available_tiles.filter(func(tile: PlacedTile) -> bool: return open_connection == tile.has_connection(reverse_direction)))
	return available_tiles

func _request_starting_placed_tile() -> void:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	assert(_starting_tile)
	var starting_tile: PlacedTile = PlacedTile.create(_starting_tile)
	var starting_grid_position: Vector2i = world_to_grid_position(player_spawn_point.global_position)
	_spawn_at(starting_tile, starting_grid_position)

func _spawn_at(tile: PlacedTile, grid_position: Vector2i) -> void:
	var tile_position: Vector3 = grid_to_world_position(grid_position) - Vector3(0.0, 0.05, 0.0)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position).rotated_local(Vector3.UP, -tile.clockwise_turns * PI * 0.5)
	_placed_tiles[grid_position] = tile
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
	for cell_position: Vector3i in structure.get_grid_cells():
		var structure_cell: StructureCell = StructureCell.new(structure.profile, cell_position)
		_grid[cell_position] = structure_cell
		_update_debug(cell_position, structure_cell)
	if _navigation_region.is_baking():
		await _navigation_region.bake_finished
		_navigation_region.bake_navigation_mesh()

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	var character: Character = player_ghost.character
	character.moved.connect(_on_player_moved.bind(character))
	if not character.is_inside_tree(): await character.ready
	_update_player_vision(character)

func _on_player_moved(character: Character) -> void:
	_update_player_vision(character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _navigation_region: warnings.append("Missing NavigationRegion3D reference.")
	return warnings
