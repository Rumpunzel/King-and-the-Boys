@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

## Emitted on the host when a [Character] entering a cell or turning a tile discovered or revealed tiles
signal board_changed(character: Character)
## Emitted on the host when [param character] turned [param tile], see [method rotate_tile]
signal tile_rotated(tile: Structure, character: Character)

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

const DIRECTION_VECTORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var grid_size: float = 2.0
@export var grid_extents: Vector2i = Vector2i(13, 13)

@export var _starting_tile: StructureProfile
## Set in the scene rather than preloaded, so this script compiles without the tile's textures and meshes
@export var _wall_tile: StructureProfile
@export var _tile_set: DungeonTileSet

@export var _reveals_per_second: float = 16.0
@export var _discovers_per_second: float = 2.0

@export_group("Configuration")
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner

var _placed_tiles: Dictionary[Vector2i, Structure]
# {Structure -> Array[Structure]}
var _tile_connections: Dictionary[Structure, Array]
var _tile_connectors: Dictionary[Vector3, Structure]

var _placed_things: Dictionary[Vector2i, Thing]

# Visual queues, on every peer: tiles whose shown status lags behind their status, one per character whose step
# raised it. Each waits for its own character's figure, see _process.
var _reveal_queues: Dictionary[Character, Array] = {}
var _discover_queues: Dictionary[Character, Array] = {}
var _remaining_tile_reveal_delays: Dictionary[Character, float] = {}
var _remaining_tile_discover_delays: Dictionary[Character, float] = {}
# Host only: the character whose step is being processed, for tiles placed during it
var _stepping_character: Character

## Host only: counts tile status raises; used to detect board changes
var _board_change_count: int = 0

func _process(delta: float) -> void:
	for character: Character in _reveal_queues.keys(): _process_queues(character, delta)

## Shows [param character]'s queued tiles once its figure entered the cell of the step that raised them:
## revealed tiles one by one, then discovered ones ring by ring, nearest to the character first
func _process_queues(character: Character, delta: float) -> void:
	var reveal_queue: Array = _reveal_queues[character]
	var discover_queue: Array = _discover_queues[character]
	reveal_queue.assign(reveal_queue.filter(_is_waiting_to_show.bind(Structure.Status.REVEALED)))
	discover_queue.assign(discover_queue.filter(_is_waiting_to_show.bind(Structure.Status.DISCOVERED)))
	if reveal_queue.is_empty() and discover_queue.is_empty():
		_forget_queues(character)
		return
	if not _has_figure_caught_up(character, reveal_queue + discover_queue): return
	_remaining_tile_reveal_delays[character] = maxf(_remaining_tile_reveal_delays[character] - delta, 0.0)
	if not reveal_queue.is_empty():
		if _remaining_tile_reveal_delays[character] > 0.0: return
		var tile_to_reveal: Structure = reveal_queue.pop_front()
		tile_to_reveal.shown_status = Structure.Status.REVEALED
		_remaining_tile_reveal_delays[character] += 1.0 / _reveals_per_second
		return
	_remaining_tile_discover_delays[character] = maxf(_remaining_tile_discover_delays[character] - delta, 0.0)
	if _remaining_tile_discover_delays[character] > 0.0: return
	var distances: Dictionary[Structure, int] = {}
	for tile: Structure in discover_queue: distances[tile] = _get_distance(tile.get_grid_position(), character.grid_cell)
	var nearest_distance: int = distances.values().min()
	for tile: Structure in distances:
		if distances[tile] != nearest_distance: continue
		discover_queue.erase(tile)
		tile.shown_status = Structure.Status.DISCOVERED
	_remaining_tile_discover_delays[character] += 1.0 / _discovers_per_second

func _is_waiting_to_show(tile: Structure, target_status: Structure.Status) -> bool:
	# Loading a game frees the tiles still queued
	return is_instance_valid(tile) and tile.shown_status < target_status

## @returns [code]true[/code] once this peer has the steps that raised [param tiles] and the figure entered its cell
func _has_figure_caught_up(character: Character, tiles: Array) -> bool:
	if not character.visible or not character.level: return true
	for tile: Structure in tiles:
		if character.step_count < tile.status_cause_step: return false
	return character.get_figure_grid_cell() == character.grid_cell

func _queue_tile(tile: Structure, character: Character) -> void:
	if not _reveal_queues.has(character):
		_reveal_queues[character] = [] as Array[Structure]
		_discover_queues[character] = [] as Array[Structure]
		_remaining_tile_reveal_delays[character] = 0.0
		_remaining_tile_discover_delays[character] = 0.0
		# A character that leaves has no figure to wait for
		character.tree_exiting.connect(_show_queued_tiles_at_once.bind(character), CONNECT_ONE_SHOT)
	var queue: Array = _reveal_queues[character] if tile.status == Structure.Status.REVEALED else _discover_queues[character]
	if not queue.has(tile): queue.append(tile)

func _show_queued_tiles_at_once(character: Character) -> void:
	if not _reveal_queues.has(character): return
	for queue: Array in [_reveal_queues[character], _discover_queues[character]]:
		for tile: Structure in queue:
			if is_instance_valid(tile): tile.shown_status = maxi(tile.shown_status, tile.status) as Structure.Status
	_forget_queues(character)

func _forget_queues(character: Character) -> void:
	if character.tree_exiting.is_connected(_show_queued_tiles_at_once.bind(character)): character.tree_exiting.disconnect(_show_queued_tiles_at_once.bind(character))
	_reveal_queues.erase(character)
	_discover_queues.erase(character)
	_remaining_tile_reveal_delays.erase(character)
	_remaining_tile_discover_delays.erase(character)

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

static func get_opposite(direction: Direction) -> Direction:
	return posmod(direction + Direction.size() / 2, Direction.size()) as Direction

## @returns [param direction] turned by [param clockwise_turns] quarter turns
static func turn_direction(direction: Direction, clockwise_turns: int) -> Direction:
	return posmod(direction + clockwise_turns, Direction.size()) as Direction

## @returns [param spot] (an offset from a tile's center, see [method get_spot_position]) turned with its tile
static func turn_spot(spot: Vector2, clockwise_turns: int) -> Vector2:
	var turned_spot: Vector2 = spot
	for _turn: int in posmod(clockwise_turns, Direction.size()): turned_spot = Vector2(-turned_spot.y, turned_spot.x)
	return turned_spot

func world_to_grid_position(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x / grid_size), roundi(world_position.z / grid_size))

func grid_to_world_position(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x, 0.0, grid_position.y) * grid_size

func build_level() -> void:
	assert(multiplayer.is_server())
	assert(is_multiplayer_authority())
	_build_outer_wall()
	var starting_grid_position: Vector2i = _place_starting_tile()
	_build_dungeon_from(starting_grid_position)
	#_structure_spawner.spawn_all_from_spawn_spoints()
	#_thing_spawner.spawn_all_from_spawn_spoints()
	#_agent_spawner.spawn_all_from_spawn_spoints()

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

func get_placed_tile(grid_position: Vector2i) -> Structure: return _placed_tiles.get(grid_position)
func get_placed_thing(grid_position: Vector2i) -> Thing: return _placed_things.get(grid_position)

## @returns the cell reached by stepping from [param grid_position] into [param direction], or [param grid_position] itself if a wall blocks it
func get_step_target(grid_position: Vector2i, direction: Direction) -> Vector2i:
	assert(get_placed_tile(grid_position))
	if not is_passage(grid_position, direction): return grid_position
	return grid_position + direction_to_vector(direction)

## @returns [code]true[/code] if pieces and sight pass from [param grid_position] into [param direction]: both tiles open
## to each other and neither is lifted. A turned tile may open into a closed side, which is a dead end.
func is_passage(grid_position: Vector2i, direction: Direction) -> bool:
	var tile: Structure = get_placed_tile(grid_position)
	if not tile or not tile.has_connection(direction): return false
	var neighbour: Structure = get_placed_tile(grid_position + direction_to_vector(direction))
	return neighbour != null and neighbour.has_connection(get_opposite(direction))

func get_spot_position(grid_position: Vector2i, spot: Vector2) -> Vector3:
	return grid_to_world_position(grid_position) + Vector3(spot.x, 0.0, spot.y)

## Spots follow the tile's order of preference: the center first, then the corners.
## Things (e.g. chests) hold the first spot; pieces keep their spot when others leave.
## @returns the free spots on [param grid_position], ignoring [param except]; empty if the tile is full
func get_free_spots(grid_position: Vector2i, except: Character = null) -> Array[Vector2]:
	var tile: Structure = get_placed_tile(grid_position)
	assert(tile)
	var free_spots: Array[Vector2] = tile.profile.get_tile_spots()
	if _placed_things.has(grid_position): free_spots.pop_front()
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if character == except or not character.visible or character.grid_cell != grid_position: continue
		free_spots.erase(character.tile_spot)
	return free_spots

## Host only: turns [param tile] by [param clockwise_turns] quarter turns with the pieces on it, then builds and looks
## along its new passages as a step of [param character] would: the heroes' sight is updated from where they stand.
## Emits [signal board_changed] for [param character] if that discovered or revealed tiles.
func rotate_tile(tile: Structure, clockwise_turns: int, character: Character) -> void:
	assert(multiplayer.is_server())
	var grid_position: Vector2i = tile.get_grid_position()
	assert(_placed_tiles.get(grid_position) == tile)
	var tile_spots: Array[Vector2] = tile.profile.get_tile_spots()
	for piece: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if not piece.visible or piece.grid_cell != grid_position: continue
		var turned_spot: Vector2 = _get_nearest_spot(turn_spot(piece.tile_spot, clockwise_turns), tile_spots)
		piece.place_on_grid(grid_position, turned_spot, turn_direction(piece.facing, clockwise_turns))
	var thing: Thing = _placed_things.get(grid_position)
	if thing: thing.rotate_y(-clockwise_turns * PI * 0.5)
	tile.clockwise_turns = posmod(tile.clockwise_turns + clockwise_turns, Direction.size())
	tile_rotated.emit(tile, character)
	var board_change_count_before: int = _board_change_count
	_stepping_character = character
	_build_dungeon_from(grid_position)
	for hero: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if not hero.visible or hero.level != self or hero.profile.group != CharacterProfile.Groups.HEROES: continue
		_update_player_vision(hero.grid_cell, hero.profile.vision, _reveal_tile.bind(character))
		_update_player_vision(hero.grid_cell, hero.profile.dark_vision, _discover_tile.bind(character))
	_stepping_character = null
	if _board_change_count != board_change_count_before: board_changed.emit(character)

static func _get_nearest_spot(spot: Vector2, tile_spots: Array[Vector2]) -> Vector2:
	var nearest_spot: Vector2 = spot
	var nearest_distance: float = INF
	for tile_spot: Vector2 in tile_spots:
		var distance: float = tile_spot.distance_squared_to(spot)
		if distance >= nearest_distance: continue
		nearest_spot = tile_spot
		nearest_distance = distance
	return nearest_spot

func _build_outer_wall() -> void:
	for y: int in range(-grid_extents.y, grid_extents.y + 1):
		for x: int in range(-grid_extents.x, grid_extents.x + 1):
			if absi(y) != grid_extents.y and absi(x) != grid_extents.x: continue
			var wall_roation: int = 1 if absi(y) == grid_extents.y else 0
			var wall_position: Vector2i = Vector2i(x, y)
			_spawn_at(DungeonTileSet.TileBlueprint.new(_wall_tile, wall_roation), wall_position)
			var wall: Structure = _placed_tiles[wall_position]
			wall.reveal()

func _place_starting_tile() -> Vector2i:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	assert(_starting_tile)
	var starting_tile_blueprint: DungeonTileSet.TileBlueprint = DungeonTileSet.TileBlueprint.new(_starting_tile, 0)
	var starting_grid_position: Vector2i = world_to_grid_position(player_spawn_point.global_position)
	_spawn_at(starting_tile_blueprint, starting_grid_position)
	var starting_tile: Structure = _placed_tiles[starting_grid_position]
	assert(starting_tile)
	_reveal_tile(starting_tile)
	return starting_grid_position

func _build_dungeon_from(origin_grid_position: Vector2i) -> void:
	var tile: Structure = _placed_tiles[origin_grid_position]
	assert(tile)
	var already_visited: Array[Vector2i] = [origin_grid_position]
	if tile.profile.room_type: _build_room_from(origin_grid_position, tile.profile.room_type, already_visited)
	for direction: Direction in tile.get_connections(): _build_corridor_from(origin_grid_position, direction, already_visited)

func _build_corridor_from(origin_grid_position: Vector2i, direction: Direction, already_visited: Array[Vector2i]) -> void:
	var tile: Structure = _placed_tiles[origin_grid_position]
	assert(tile)
	var relative_direction: Vector2i = direction_to_vector(direction)
	var index: int = 0
	while tile.has_connection(direction):
		var grid_position: Vector2i = origin_grid_position + relative_direction * index
		if not already_visited.has(grid_position): already_visited.append(grid_position)
		spawn_at(grid_position)
		tile = _placed_tiles[grid_position]
		if tile.profile.room_type: _build_room_from(grid_position, tile.profile.room_type, already_visited)
		for connection: Direction in tile.get_connections():
			if connection == direction or connection == direction - Level.Direction.size() / 2: continue
			var neighbour_direction: Vector2i = direction_to_vector(connection)
			var neighbour_position: Vector2i = grid_position + neighbour_direction
			spawn_at(neighbour_position)
		index += 1

func _build_room_from(origin_grid_position: Vector2i, room_type: RoomType, already_visited: Array[Vector2i]) -> void:
	assert(room_type)
	var tile: Structure = _placed_tiles[origin_grid_position]
	assert(tile)
	if not room_type == tile.profile.room_type: return
	for connection: Direction in tile.get_connections():
		var relative_direction: Vector2i = direction_to_vector(connection)
		var grid_position: Vector2i = origin_grid_position + relative_direction
		if already_visited.has(grid_position): continue
		already_visited.append(grid_position)
		spawn_at(grid_position)
		_build_room_from(grid_position, room_type, already_visited)

func _spawn_at(tile_blueprint: DungeonTileSet.TileBlueprint, grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	assert(absi(grid_position.x) <= grid_extents.x)
	assert(absi(grid_position.y) <= grid_extents.y)
	var tile_position: Vector3 = grid_to_world_position(grid_position)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position)
	_structure_spawner.spawn_at(tile_blueprint.profile, tile_transform, tile_blueprint.clockwise_turns, status)

## Calls [param reveal_function] with every tile in sight within [param vision_radius]
func _update_player_vision(from_grid_position: Vector2i, vision_radius: float, reveal_function: Callable, origin_grid_position: Vector2i = from_grid_position) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > vision_radius ** 2.0: return
	var from_tile: Structure = _placed_tiles[from_grid_position]
	assert(from_tile)
	var origin_room: Structure = _placed_tiles[origin_grid_position]
	assert(origin_room)
	var origin_tile_room_type: RoomType = origin_room.profile.room_type
	if origin_tile_room_type and origin_tile_room_type == from_tile.profile.room_type:
		_update_player_vision_in_room(from_grid_position, vision_radius, reveal_function, origin_grid_position)
	for direction: Direction in from_tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(direction)
		var tile: Structure = from_tile
		for radius: int in range(1, ceili(vision_radius) + 1):
			# Sight follows passages only, like the corridors built in _build_corridor_from,
			# so coming back to a cell never reveals tiles that were built later
			if not is_passage(tile.get_grid_position(), direction): break
			var next_tile_grid_position: Vector2i = from_grid_position + direction_vector * radius
			if origin_grid_position.distance_squared_to(next_tile_grid_position) > vision_radius ** 2.0: break
			if not _placed_tiles.has(next_tile_grid_position): break
			tile = _placed_tiles[next_tile_grid_position]
			reveal_function.call(tile)

func _update_player_vision_in_room(from_grid_position: Vector2i, vision_radius: float, reveal_function: Callable, origin_grid_position: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	assert(not already_visited.has(from_grid_position))
	already_visited.append(from_grid_position)
	if origin_grid_position.distance_squared_to(from_grid_position) > vision_radius ** 2.0: return
	var from_tile: Structure = _placed_tiles[from_grid_position]
	assert(from_tile)
	reveal_function.call(from_tile)
	var origin_room: Structure = _placed_tiles[origin_grid_position]
	assert(origin_room)
	var origin_tile_room_type: RoomType = origin_room.profile.room_type
	assert(origin_tile_room_type)
	assert(from_tile.profile.room_type == origin_tile_room_type)
	for connection: Direction in from_tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(connection)
		var room_tile_grid_position: Vector2i = from_grid_position + direction_vector
		var room_tile: Structure = _placed_tiles[room_tile_grid_position]
		assert(room_tile)
		if origin_tile_room_type == room_tile.profile.room_type and not already_visited.has(room_tile_grid_position):
			_update_player_vision_in_room(room_tile_grid_position, vision_radius, reveal_function, origin_grid_position, already_visited)

## Host only: reveals [param tile] right away and discovers its neighbours; peers show it later, after the step of
## [param character] that caused it, or at once if no step did
func _reveal_tile(tile: Structure, character: Character = null) -> void:
	if tile.status >= Structure.Status.REVEALED: return
	_set_status_cause(tile, character)
	tile.reveal()
	_board_change_count += 1
	# Neighbours not built yet are discovered once they are placed, see _on_structure_created
	for connection: Direction in tile.get_connections():
		var neighbour: Structure = _placed_tiles.get(tile.get_grid_position() + direction_to_vector(connection))
		if neighbour: _discover_tile(neighbour, character)

## Host only: discovers [param tile] right away; peers show it later, see [method _reveal_tile]
func _discover_tile(tile: Structure, character: Character = null) -> void:
	if tile.status >= Structure.Status.DISCOVERED: return
	_set_status_cause(tile, character)
	tile.discover()
	_board_change_count += 1

## Set before the status: peers read the cause when the status changes
static func _set_status_cause(tile: Structure, character: Character) -> void:
	tile.status_cause = character.get_path() if character else NodePath()
	tile.status_cause_step = character.step_count if character else 0

func _is_next_to_revealed_tile(tile: Structure) -> bool:
	for connection: Direction in tile.get_connections():
		var neighbour: Structure = _placed_tiles.get(tile.get_grid_position() + direction_to_vector(connection))
		if neighbour and neighbour.status == Structure.Status.REVEALED: return true
	return false

static func _get_distance(from_grid_position: Vector2i, to_grid_position: Vector2i) -> int:
	return absi(from_grid_position.x - to_grid_position.x) + absi(from_grid_position.y - to_grid_position.y)

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
	# Tiles without a model (e.g. in tests) count as unscaled
	var mesh_scale: float = tile.model.get_max_mesh_scale() if tile.model else 1.0
	var connection_position: Vector3 = tile.global_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5 * mesh_scale
	var tile_connection: Structure = _tile_set.tile_connection.create(-1, Transform3D(Basis.IDENTITY, connection_position), connection, Structure.Status.PLACED)
	var tile_connections: Array[Structure] = _tile_connections.get_or_add(tile, [] as Array[Structure])
	assert(not tile_connections.has(tile))
	tile_connections.append(tile_connection)
	add_child(tile_connection)

func _create_connector(tile_position: Vector3, connection: Direction) -> void:
	var connector_position: Vector3 = _get_connector_position(tile_position, connection)
	if _tile_connectors.has(connector_position): return
	var tile_connector: Structure = _tile_set.tile_connector.create(-1, Transform3D(Basis.IDENTITY, connector_position), connection, Structure.Status.PLACED)
	_tile_connectors[connector_position] = tile_connector
	add_child(tile_connector)

func _on_structure_created(structure: Structure) -> void:
	var tile_grid_position: Vector2i = world_to_grid_position(structure.global_position)
	# Registered first: tiles revealed already (loaded, joined) are dressed as they get their level, and look for themselves
	_placed_tiles[tile_grid_position] = structure
	structure.level = self
	for connection: Direction in structure.get_connections():
		_create_connection(structure, connection)
		_create_connector(structure.global_position, connection)
	structure.status_changed.connect(_on_tile_status_changed.bind(structure))
	structure.shown_status_changed.connect(_on_tile_shown_status_changed.bind(structure))
	structure.clockwise_turns_changed.connect(_on_tile_turned.bind(structure).unbind(1))
	if not multiplayer.is_server(): return
	structure.spawn_requested.connect(_on_spawn_requested.bind(structure))
	if _is_next_to_revealed_tile(structure): structure.ready.connect(_discover_tile.bind(structure, _stepping_character), CONNECT_ONE_SHOT)

## Queues showing a tile whose status went up after the step that caused it; on every peer, as clients get the
## status replicated. Statuses no step raised (level build, spawning, loading) show at once.
func _on_tile_status_changed(status: Structure.Status, tile: Structure) -> void:
	if status < Structure.Status.DISCOVERED: return
	var character: Character = get_node_or_null(tile.status_cause) as Character if not tile.status_cause.is_empty() else null
	if not character or tile.status_cause_step == 0:
		tile.shown_status = status
		return
	_queue_tile(tile, character)

func _on_tile_shown_status_changed(shown_status: Structure.Status, tile: Structure) -> void:
	var grid_position: Vector2i = tile.get_grid_position()
	if _placed_things.has(grid_position):
		var thing_on_tile: Thing = _placed_things[grid_position]
		thing_on_tile.status = Thing.structure_status_to_thing_status(shown_status)
	if not shown_status == Structure.Status.REVEALED: return
	await get_tree().create_timer(0.5).timeout
	_show_connections(tile)

## Shows the connections of a revealed [param tile], and the connectors it shares with revealed neighbours
func _show_connections(tile: Structure) -> void:
	for tile_connection: Structure in _tile_connections.get(tile, []): tile_connection.shown_status = Structure.Status.REVEALED
	for connection: Direction in tile.get_connections():
		var direction_vector: Vector2i = direction_to_vector(connection)
		# A turned tile may open into a cell that is not built yet
		var neighbour: Structure = _placed_tiles.get(tile.get_grid_position() + direction_vector)
		if not neighbour or not neighbour.shown_status == Structure.Status.REVEALED: continue
		var tile_connector: Structure = _tile_connectors[_get_connector_position(tile.global_position, connection)]
		tile_connector.shown_status = Structure.Status.REVEALED

## Every peer: rebuilds the connections of a turned [param tile] and the connectors on its sides
func _on_tile_turned(tile: Structure) -> void:
	for tile_connection: Structure in _tile_connections.get(tile, []): tile_connection.queue_free()
	_tile_connections.erase(tile)
	var connections: Array[Direction] = tile.get_connections()
	for connection: Direction in connections: _create_connection(tile, connection)
	var grid_position: Vector2i = tile.get_grid_position()
	for direction: Direction in Direction.values():
		var neighbour: Structure = _placed_tiles.get(grid_position + direction_to_vector(direction))
		var needed: bool = connections.has(direction) or (neighbour != null and neighbour.get_connections().has(get_opposite(direction)))
		var connector_position: Vector3 = _get_connector_position(tile.global_position, direction)
		if needed: _create_connector(tile.global_position, direction)
		elif _tile_connectors.has(connector_position):
			_tile_connectors[connector_position].queue_free()
			_tile_connectors.erase(connector_position)
	if tile.shown_status == Structure.Status.REVEALED: _show_connections(tile)
	for neighbour: Structure in _get_surrounding_tiles(grid_position):
		if neighbour.shown_status == Structure.Status.REVEALED: _show_connections(neighbour)

func _get_connector_position(tile_position: Vector3, connection: Direction) -> Vector3:
	var direction_vector: Vector2i = direction_to_vector(connection)
	return tile_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5

func _on_thing_created(thing: Thing) -> void:
	var thing_grid_position: Vector2i = world_to_grid_position(thing.global_position)
	_placed_things[thing_grid_position] = thing

func _on_agent_created(agent: Agent) -> void:
	_register_character(agent.character)

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	var character: Character = player_ghost.character
	_register_character(character)
	if not multiplayer.is_server(): return
	character.entered_grid_cell.connect(_on_player_moved.bind(character))

func _register_character(character: Character) -> void:
	character.level = self
	character.figure_entered_grid_cell.connect(_on_figure_entered_grid_cell.bind(character))

func _on_player_moved(character_grid_position: Vector2i, character: Character) -> void:
	var entered_tile: Structure = _placed_tiles[character_grid_position]
	assert(entered_tile)
	var board_change_count_before: int = _board_change_count
	# Tiles placed while building are discovered with this step too, see _on_structure_created
	_stepping_character = character
	_build_dungeon_from(character_grid_position)
	_update_player_vision(character_grid_position, character.profile.vision, _reveal_tile.bind(character))
	_update_player_vision(character_grid_position, character.profile.dark_vision, _discover_tile.bind(character))
	_stepping_character = null
	if _board_change_count != board_change_count_before: board_changed.emit(character)

## Visual feedback on every peer: reveals start shortly after the figure crosses into a cell
func _on_figure_entered_grid_cell(_cell: Vector2i, character: Character) -> void:
	if not _reveal_queues.has(character): return
	_remaining_tile_reveal_delays[character] = character.profile.move_animation.duration * 0.1
	_remaining_tile_discover_delays[character] = character.profile.move_animation.duration * 0.1

func _on_spawn_requested(profile_to_spawn: Profile, spawn_for: Structure) -> void:
	if profile_to_spawn is StructureProfile:
		_structure_spawner.spawn_at(profile_to_spawn as StructureProfile, spawn_for.transform, spawn_for.clockwise_turns, spawn_for.status)
	elif profile_to_spawn is ThingProfile:
		_thing_spawner.spawn_at(profile_to_spawn as ThingProfile, spawn_for.transform, Thing.structure_status_to_thing_status(spawn_for.status))
	#elif profile_to_spawn is CharacterProfile: _agent_spawner.spawn_at(profile_to_spawn as CharacterProfile, spawn_for.transform)
	else: push_error("Cannot spawn profile: %profile_to_spawn - Not implemented!" % profile_to_spawn)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _wall_tile: warnings.append("Missing wall tile StructureProfile.")
	if not _structure_spawner: warnings.append("Missing StructureSpawner reference.")
	if not _thing_spawner: warnings.append("Missing ThingSpawner reference.")
	if not _agent_spawner: warnings.append("Missing AgentSpawner reference.")
	return warnings
