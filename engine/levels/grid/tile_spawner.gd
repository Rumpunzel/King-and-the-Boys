@tool
@icon("uid://ccy2lx7al4tvu")
class_name TileSpawner
extends Spawner

signal tile_created(tile: Structure)

@export var _grid_size: float = 2.0

@export_group("Configuration")
@export var _tile: StructureProfile

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

func spawn_at(grid_position: Vector2i) -> Array[Structure]:
	assert(multiplayer.is_server())
	var tile_data: Dictionary[StringName, Variant] = {
		Structure.VARIATION: -1,
		Structure.PROFILE_PATH: _tile.resource_path,
		Structure.SPAWN_TRANSFORM: Transform3D(Basis.IDENTITY, grid_to_world_position(grid_position)),
	}
	Structure.validate_structure_data(tile_data)
	spawn(tile_data)
	return _tiles.values()

func spawn_at_all(grid_positions: Array[Vector2i]) -> Array[Structure]:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position)
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

func _on_child_entered_tree(node: Node) -> void:
	if not node is Structure: return
	var tile: Structure = node
	assert(not _tiles.values().has(tile))
	var grid_position: Vector2i = world_to_grid_position(tile.global_position)
	assert(not _tiles.has(grid_position))
	_tiles[grid_position] = tile
	tile_created.emit(tile)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _tile: warnings.append("Missing Tile reference.")
	return warnings
