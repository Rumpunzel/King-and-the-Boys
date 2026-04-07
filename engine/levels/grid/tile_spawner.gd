@tool
@icon("uid://ccy2lx7al4tvu")
class_name TileSpawner
extends Spawner

signal tile_created(tile: Structure)

@export var _grid_size: float = 2.0

@export_group("Configuration")
@export var _starting_tile: TileProfile
@export var _available_tiles: Array[TileProfile]

var _tiles: Dictionary[Vector2i, Structure]

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_tile

func _ready() -> void:
	super._ready()

func world_to_grid_position(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / _grid_size), floori(world_position.z / _grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x * _grid_size, 0.0, grid_position.y * _grid_size)

func spawn_at(grid_position: Vector2i, tile: TileProfile) -> Array[Structure]:
	assert(multiplayer.is_server())
	assert(tile)
	if _tiles.has(grid_position):
		print_debug("Skipping spawning tile at %s, already a tile there!" % grid_position)
		return _tiles.values()
	var tile_data: Dictionary[StringName, Variant] = {
		Structure.VARIATION: -1,
		Structure.PROFILE_PATH: tile.resource_path,
		Structure.SPAWN_TRANSFORM: Transform3D(Basis.IDENTITY, grid_to_world_position(grid_position) + Vector3(0.0, 0.05, 0.0)),
	}
	Structure.validate_structure_data(tile_data)
	spawn(tile_data)
	return _tiles.values()

func spawn_at_all(grid_positions: Array[Vector2i]) -> Array[Structure]:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position, _starting_tile)
	return _tiles.values()

func spawn_at_from(grid_position: Vector2i, existing_position: Vector2i) -> Array[Structure]:
	if _tiles.has(grid_position):
		print_debug("Skipping spawning tile at %s, already a tile there!" % grid_position)
		return _tiles.values()
	var available_tiles: Array[TileProfile] = _get_available_tiles_for_tile(grid_position, existing_position)
	var fitting_tile: TileProfile = available_tiles.pick_random()
	assert(fitting_tile)
	spawn_at(grid_position, fitting_tile)
	return _tiles.values()

func spawn_at_from_all(grid_positions: Array[Vector2i], existing_position: Vector2i) -> Array[Structure]:
	for grid_position: Vector2i in grid_positions: spawn_at_from(grid_position, existing_position)
	return _tiles.values()

func remove_all_tiles() -> void:
	assert(multiplayer.is_server())
	remove_all_spawned_nodes()

func remove_tile(tile: Structure) -> void:
	assert(multiplayer.is_server())
	var grid_position: Vector2i = world_to_grid_position(tile.global_position)
	assert(_tiles.has(grid_position))
	assert(_tiles[grid_position] == tile)
	_tiles.erase(grid_position)
	remove_child(tile)
	tile.queue_free()

func get_all_node_data() -> Array[Variant]:
	var tiles_data: Array[Variant] = []
	for tile: Structure in _tiles.values():
		tiles_data.append(tile.to_structure_data())
	return tiles_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_tiles_paths: Array[NodePath] = []
	var tiles: Array[Structure] = _tiles.values()
	while not tiles.is_empty():
		var tile: Structure = tiles.pop_back()
		removed_tiles_paths.append(tile.get_path())
		remove_tile(tile)
	_tiles.clear()
	return removed_tiles_paths

func _spawn_tile(tile_data: Dictionary[StringName, Variant]) -> Structure:
	Structure.validate_structure_data(tile_data)
	return Structure.from_structure_data(tile_data)

func _update_player_vision(character: Character) -> void:
	var character_grid_position: Vector2i = world_to_grid_position(character.global_position)
	var blocked_vision: Array[Vector2i] = []
	blocked_vision.assign(_get_vision_for_tile(character_grid_position, character.profile.vision))
	var visible_adjacent_tiles: Array[Vector2i] = []
	visible_adjacent_tiles.assign(blocked_vision.map(func(direction: Vector2i) -> Vector2i: return character_grid_position + direction))
	spawn_at_from_all(visible_adjacent_tiles, character_grid_position)

func _get_vision_for_tile(tile_position: Vector2i, vision: Array[Vector2i]) -> Array[Vector2i]:
	if not _tiles.has(tile_position): spawn_at(tile_position, _starting_tile)
	var tile: Structure = _tiles[tile_position]
	var blocked_vision: Array[Vector2i] = []
	blocked_vision.assign(vision.filter(func(direction: Vector2i) -> bool: return (tile.profile as TileProfile).connections.has(direction)))
	return blocked_vision

func _get_available_tiles_for_tile(new_tile_position: Vector2i, existing_tile_position: Vector2i) -> Array[TileProfile]:
	var existing_tile: TileProfile = _tiles[existing_tile_position].profile
	assert(existing_tile)
	var direction: Vector2i = new_tile_position - existing_tile_position
	var available_tiles: Array[TileProfile] = []
	if not existing_tile.connections.has(direction): return available_tiles
	available_tiles.assign(_available_tiles.filter(func(tile: TileProfile) -> bool: return tile.connections.has(direction * -1)))
	return available_tiles

func _on_child_entered_tree(node: Node) -> void:
	if not node is Structure: return
	var tile: Structure = node
	assert(not _tiles.values().has(tile))
	var grid_position: Vector2i = world_to_grid_position(tile.global_position)
	assert(not _tiles.has(grid_position))
	_tiles[grid_position] = tile
	tile_created.emit(tile)

func _on_player_spawned(player: PlayerGhost) -> void:
	var character: Character = player.character
	character.moved.connect(_on_player_moved.bind(character))
	if not character.is_inside_tree(): await character.ready
	_update_player_vision(character)

func _on_player_moved(character: Character) -> void:
	_update_player_vision(character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _starting_tile: warnings.append("Missing StartingTile reference.")
	return warnings
