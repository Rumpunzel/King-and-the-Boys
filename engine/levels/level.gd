@tool
@icon("uid://bfpmyljmhdkos")
class_name Level
extends Node3D

## Emitted on the host when a [Character] entering a cell or turning a tile discovered or revealed tiles
signal board_changed(character: Character)
## Emitted on the host when [param character] turned [param tile], see [method rotate_tile]
signal tile_rotated(tile: Structure, character: Character)
## Host only: [method build_level] placed the starting tiles, see [member is_built]
signal built
## Every peer: a tile was placed (spawned, loaded or replicated)
signal tile_placed(tile: Structure)

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

const DIRECTION_VECTORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## The corners of a cell, as offsets from its grid position to the corner's index (see [member _corner_things])
const CELL_CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
## Meta of a bridge that is shown or dropping in
const _SHOWN: StringName = &"shown"

@export var grid_size: float = 2.0
@export var grid_extents: Vector2i = Vector2i(13, 13)

@export var _starting_tile: StructureProfile
## Set in the scene rather than preloaded, so this script compiles without the tile's textures and meshes
@export var _wall_tile: StructureProfile
@export var _tile_set: DungeonTileSet

## What may stand in the middle of a room (e.g. a sarcophagus), on the grid corner nearest its centre; set in the scene, like
## [member _wall_tile]
@export var _room_centrepieces: SpawnTable
## Chance of a room big enough (2x2 cells) to get a centrepiece
@export_range(0.0, 1.0) var _room_centrepiece_chance: float = 0.75

## How tiles move while lifted, e.g. by the Mystic turning one; set in the scene, as its particles are assets. Without one, tiles
## lift with [TileLiftAnimation]'s defaults and no particles
@export var tile_lift_animation: TileLiftAnimation

@export var _reveals_per_second: float = 16.0
@export var _discovers_per_second: float = 2.0

@export_group("Configuration")
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner

## Host only: whether [method build_level] ran, see [signal built]
var is_built: bool = false
## Host only: the dice the dungeon is generated with. Seeded, it builds the same dungeon again for the same order of
## exploration (e.g. in tests); its state is not saved yet, so a loaded game grows on differently.
var generation_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Host only: cells where no tile kept every neighbour's connection restrictions, so the one keeping the most was
## placed (e.g. a treasure dead end wanting empty space where the dungeon grew later); for tests and debugging
var restriction_fallbacks: Dictionary[Vector2i, bool] = {}

var _placed_tiles: Dictionary[Vector2i, Structure]
## Bridges over the gaps between tiles opening to each other, by the middle of the gap (see [method _get_gap_position]); each
## peer lays its own, as they are only for show
var _bridges: Dictionary[Vector3, Model]
## Cells whose tile just turned: what the turn brought into sight waits there a moment, see
## [member TileLiftAnimation.reveal_delay]
var _reveals_held_on: Dictionary[Vector2i, bool] = {}

var _placed_things: Dictionary[Vector2i, Thing]
## Things standing on a grid corner between four cells (e.g. room centrepieces), by the corner's index: corner [code]c[/code] lies
## between the cells [code]c - (1, 1)[/code] and [code]c[/code]
var _corner_things: Dictionary[Vector2i, Thing]
## Cells of rooms whose centrepiece was decided, see [method _furnish_room]
var _furnished_cells: Dictionary[Vector2i, bool]

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

## @returns [code]true[/code] once this peer has the steps that raised [param tiles] and the figure entered its cell, and no
## tile just set down holds the reveals there
func _has_figure_caught_up(character: Character, tiles: Array) -> bool:
	if not character.visible or not character.level: return true
	if _reveals_held_on.has(character.grid_cell): return false
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
	is_built = true
	built.emit()
	#_structure_spawner.spawn_all_from_spawn_spoints()
	#_thing_spawner.spawn_all_from_spawn_spoints()
	#_agent_spawner.spawn_all_from_spawn_spoints()

func spawn_at(grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	# Placed already, e.g. the outer wall a turned tile now opens towards
	if _placed_tiles.has(grid_position):
		var placed_tile: Structure = _placed_tiles[grid_position]
		assert(placed_tile)
		if status >= placed_tile.status: placed_tile.status = status
		return
	assert(absi(grid_position.x) < grid_extents.x)
	assert(absi(grid_position.y) < grid_extents.y)
	var pick: DungeonTileSet.Pick = _tile_set.pick_tile(grid_position, _get_surrounding_tiles(grid_position), generation_random)
	assert(pick.blueprint)
	if not pick.suits_all: restriction_fallbacks[grid_position] = true
	_spawn_at(pick.blueprint, grid_position, status)

func spawn_at_all(grid_positions: Array[Vector2i], status: Structure.Status) -> void:
	for grid_position: Vector2i in grid_positions: spawn_at(grid_position, status)

func get_placed_tile(grid_position: Vector2i) -> Structure: return _placed_tiles.get(grid_position)
func get_placed_thing(grid_position: Vector2i) -> Thing: return _placed_things.get(grid_position)
func get_placed_tiles() -> Array[Structure]: return _placed_tiles.values()

## Every room of placed tiles, each as its cells (see [method get_room_cells]); each room once
func get_rooms() -> Array[Array]:
	var rooms: Array[Array] = []
	var in_room: Dictionary[Vector2i, bool] = {}
	for grid_position: Vector2i in _placed_tiles:
		if in_room.has(grid_position): continue
		var cells: Array[Vector2i] = get_room_cells(grid_position)
		if cells.is_empty(): continue
		for cell: Vector2i in cells: in_room[cell] = true
		rooms.append(cells)
	return rooms

## @returns the thing on [param grid_position], or else one on a corner of it
func get_thing_near(grid_position: Vector2i) -> Thing:
	if _placed_things.has(grid_position): return _placed_things[grid_position]
	for corner: Vector2i in CELL_CORNERS:
		if _corner_things.has(grid_position + corner): return _corner_things[grid_position + corner]
	return null

## The cells of the room [param grid_position] belongs to: the placed tiles of its room type reached through connections; empty
## outside rooms
func get_room_cells(grid_position: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var tile: Structure = get_placed_tile(grid_position)
	if not tile or not tile.profile.room_type: return cells
	var room_type: RoomType = tile.profile.room_type
	var open: Array[Vector2i] = [grid_position]
	cells.append(grid_position)
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for connection: Direction in _placed_tiles[cell].get_connections():
			var neighbour_position: Vector2i = cell + direction_to_vector(connection)
			var neighbour: Structure = get_placed_tile(neighbour_position)
			if not neighbour or neighbour.profile.room_type != room_type or cells.has(neighbour_position): continue
			cells.append(neighbour_position)
			open.append(neighbour_position)
	return cells

## Whether every connection of the room's [param cells] leads to a placed tile. Rooms are built whole, so a room is only incomplete
## while its tiles still arrive (loading, joining)
func is_room_complete(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		for connection: Direction in _placed_tiles[cell].get_connections():
			if not _placed_tiles.has(cell + direction_to_vector(connection)): return false
	return true

## The grid corner where a room's centrepiece stands: the one nearest the room's centre among those with all four cells in the room
## and no pillar (corners with even indices, see [TileDecorations]); [code]null[/code] if there is none, e.g. in rooms narrower than 2 cells
static func get_centrepiece_corner(cells: Array[Vector2i]) -> Variant:
	if cells.is_empty(): return null
	var centre: Vector2 = Vector2.ZERO
	for cell: Vector2i in cells: centre += Vector2(cell)
	centre /= cells.size()
	var best: Vector2i = Vector2i.ZERO
	var best_distance: float = INF
	for cell: Vector2i in cells:
		var corner: Vector2i = cell + Vector2i.ONE
		if posmod(corner.x, 2) == 0 and posmod(corner.y, 2) == 0: continue
		if not CELL_CORNERS.all(func(offset: Vector2i) -> bool: return cells.has(corner - offset)): continue
		var distance: float = (Vector2(corner) - Vector2.ONE * 0.5).distance_squared_to(centre)
		# Ties go to the smallest corner, so every peer picks alike
		if distance < best_distance - 0.0001 or (is_equal_approx(distance, best_distance) and corner < best):
			best = corner
			best_distance = distance
	if best_distance == INF: return null
	return best

## Where the grid corner [param corner] lies (see [member _corner_things])
func get_corner_world_position(corner: Vector2i) -> Vector3:
	return grid_to_world_position(corner) - Vector3(1.0, 0.0, 1.0) * grid_size * 0.5

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

## The first free spot on [param grid_position], else on the nearest revealed tile along passages (tiles the
## party has seen; unexplored ones would build dungeon away from it), as a world position, ignoring [param except]:
## where a character goes once its tile is full. [code]Vector3.INF[/code] if no tile reached has room.
func get_nearest_free_spot_position(grid_position: Vector2i, except: Character = null) -> Vector3:
	var cells: Array[Vector2i] = [grid_position]
	var reached: Dictionary[Vector2i, bool] = {grid_position: true}
	var next: int = 0
	while next < cells.size():
		var cell: Vector2i = cells[next]
		next += 1
		var free_spots: Array[Vector2] = get_free_spots(cell, except)
		if not free_spots.is_empty():
			var spot: Vector2 = free_spots.front()
			return get_spot_position(cell, spot)
		var tile: Structure = get_placed_tile(cell)
		for direction: Direction in tile.get_connections():
			var neighbour: Vector2i = cell + direction_to_vector(direction)
			var neighbour_tile: Structure = get_placed_tile(neighbour)
			# Passages only (the edge of what is built may lead nowhere yet), into revealed tiles
			if reached.has(neighbour) or not neighbour_tile or neighbour_tile.status < Structure.Status.REVEALED: continue
			if not neighbour_tile.has_connection_to(cell): continue
			reached[neighbour] = true
			cells.append(neighbour)
	return Vector3.INF

## Spots follow the tile's order of preference: the center first, then the corners.
## Things (e.g. chests) hold the first spot; pieces keep their spot when others leave.
## @returns the free spots on [param grid_position], ignoring [param except]; empty if the tile is full
func get_free_spots(grid_position: Vector2i, except: Character = null) -> Array[Vector2]:
	var tile: Structure = get_placed_tile(grid_position)
	assert(tile)
	var free_spots: Array[Vector2] = tile.profile.get_tile_spots()
	if _placed_things.has(grid_position): free_spots.pop_front()
	# A thing on a corner takes the spot towards it
	for corner: Vector2i in CELL_CORNERS:
		if _corner_things.has(grid_position + corner): free_spots.erase(get_spot_towards(free_spots, Vector2(corner) * 2.0 - Vector2.ONE))
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
	# Each piece takes the free spot nearest to where the turn carries it: none on a spot a thing holds (e.g. a centrepiece on a
	# corner, which does not turn with the tile), nor two on one
	var pieces: Array[Character] = []
	for piece: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if piece.visible and piece.grid_cell == grid_position: pieces.append(piece)
	var open_spots: Array[Vector2] = get_free_spots(grid_position)
	for piece: Character in pieces: open_spots.append(piece.tile_spot)
	for piece: Character in pieces:
		var turned_spot: Vector2 = _get_nearest_spot(turn_spot(piece.tile_spot, clockwise_turns), open_spots)
		open_spots.erase(turned_spot)
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

## The spot of [param spots] furthest out towards [param direction] (e.g. a corner), or [code]Vector2.INF[/code] if none lies that way
static func get_spot_towards(spots: Array[Vector2], direction: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_reach: float = 0.0
	for spot: Vector2 in spots:
		var reach: float = spot.dot(direction.normalized())
		if reach > best_reach:
			best = spot
			best_reach = reach
	return best

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
			if connection == direction or connection == get_opposite(direction): continue
			var neighbour_direction: Vector2i = direction_to_vector(connection)
			var neighbour_position: Vector2i = grid_position + neighbour_direction
			spawn_at(neighbour_position)
		# On only where the next tile opens back: a turned tile may face a closed side (or the outer wall)
		var next_tile: Structure = _placed_tiles.get(grid_position + relative_direction)
		if next_tile and not next_tile.has_connection(get_opposite(direction)): break
		index += 1

func _build_room_from(origin_grid_position: Vector2i, room_type: RoomType, already_visited: Array[Vector2i]) -> void:
	_spread_room_from(origin_grid_position, room_type, already_visited)
	_furnish_room(origin_grid_position)

func _spread_room_from(origin_grid_position: Vector2i, room_type: RoomType, already_visited: Array[Vector2i]) -> void:
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
		_spread_room_from(grid_position, room_type, already_visited)

## Host only: now and then a centrepiece in the middle of the room around [param grid_position], which must be built whole. Rooms are
## built again on every step, so the roll is seeded by the room, and a corner holding a thing already is left alone
func _furnish_room(grid_position: Vector2i) -> void:
	if not _room_centrepieces or _furnished_cells.has(grid_position): return
	var cells: Array[Vector2i] = get_room_cells(grid_position)
	var found: Variant = get_centrepiece_corner(cells)
	if found == null:
		_remember_furnished(cells)
		return
	var corner: Vector2i = found
	if _corner_things.has(corner):
		_remember_furnished(cells)
		return
	# A figure on one of the corner's tiles (e.g. in a save from before rooms had centrepieces) may stand where it would go: later
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if CELL_CORNERS.has(corner - character.grid_cell): return
	_remember_furnished(cells)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(cells.min()) ^ hash(&"centrepiece")
	if random.randf() >= _room_centrepiece_chance: return
	var profile: ThingProfile = _room_centrepieces.get_spawn() as ThingProfile
	if not profile: return
	var turn: Basis = Basis(Vector3.UP, PI * 0.5 * (random.randi() % 4))
	# Unrevealed: every peer shows it with its own view of the four tiles, see _on_thing_created
	_thing_spawner.spawn_at(profile, Transform3D(turn, get_corner_world_position(corner)), Thing.Status.PLACED)

## Rooms are built again on every step; their centrepiece is decided once
func _remember_furnished(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells: _furnished_cells[cell] = true

func _spawn_at(tile_blueprint: DungeonTileSet.TileBlueprint, grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	assert(absi(grid_position.x) <= grid_extents.x)
	assert(absi(grid_position.y) <= grid_extents.y)
	var tile_position: Vector3 = grid_to_world_position(grid_position)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position)
	_structure_spawner.spawn_at(tile_blueprint.profile, tile_transform, tile_blueprint.clockwise_turns, status)

## Calls [param reveal_function] with every tile in sight within [param vision_radius], always with the tile at
## [param from_grid_position] (a character sees the tile it stands on, even without vision)
func _update_player_vision(from_grid_position: Vector2i, vision_radius: float, reveal_function: Callable, origin_grid_position: Vector2i = from_grid_position) -> void:
	if origin_grid_position.distance_squared_to(from_grid_position) > vision_radius ** 2.0: return
	var from_tile: Structure = _placed_tiles[from_grid_position]
	assert(from_tile)
	# The passages below only reach the tiles they lead to (rooms reveal this one again, harmlessly)
	reveal_function.call(from_tile)
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
	# Neighbours not built yet are discovered once they are placed, see _on_structure_created. Only across passages, like
	# sight: not through an opening a turned tile now has towards a closed side
	for connection: Direction in tile.get_connections():
		if not is_passage(tile.get_grid_position(), connection): continue
		_discover_tile(_placed_tiles[tile.get_grid_position() + direction_to_vector(connection)], character)

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
		if not is_passage(tile.get_grid_position(), connection): continue
		if _placed_tiles[tile.get_grid_position() + direction_to_vector(connection)].status == Structure.Status.REVEALED: return true
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

## The middle of the gap between a tile on [param tile_position] and its neighbour towards [param direction]
func _get_gap_position(tile_position: Vector3, direction: Direction) -> Vector3:
	var direction_vector: Vector2i = direction_to_vector(direction)
	return tile_position + Vector3(direction_vector.x, 0.0, direction_vector.y) * grid_size * 0.5

func _on_structure_created(structure: Structure) -> void:
	var tile_grid_position: Vector2i = world_to_grid_position(structure.global_position)
	# Registered first: tiles revealed already (loaded, joined) are dressed as they get their level, and look for themselves
	_placed_tiles[tile_grid_position] = structure
	structure.level = self
	_update_gaps_of(structure)
	structure.status_changed.connect(_on_tile_status_changed.bind(structure))
	structure.shown_status_changed.connect(_on_tile_shown_status_changed.bind(structure))
	structure.clockwise_turns_changed.connect(_on_tile_turned.bind(structure).unbind(1))
	structure.lift_changed.connect(_on_tile_lift_changed.bind(structure))
	structure.landed.connect(_on_tile_landed.bind(structure))
	# Removed (e.g. by loading a save), it leaves the registries with its connections, like things do
	structure.tree_exiting.connect(_forget_tile.bind(structure), CONNECT_ONE_SHOT)
	tile_placed.emit(structure)
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
	# A thing on a corner shows as soon as one of its four cells does
	var thing_status: Thing.Status = Thing.structure_status_to_thing_status(shown_status)
	for corner: Vector2i in CELL_CORNERS:
		var corner_thing: Thing = _corner_things.get(grid_position + corner)
		if corner_thing and thing_status > corner_thing.status: corner_thing.status = thing_status
	if not shown_status == Structure.Status.REVEALED: return
	# A tween bound to the level, not a timer awaited: it goes with the level (e.g. leaving the game, a test ending)
	# instead of resuming on a freed one, which crashed Godot at exit. It pauses with the game, so the board does
	# not change while paused. Bound to the cell, not the tile: the tile may be gone by then (e.g. a save loaded).
	create_tween().tween_callback(_show_bridges_at.bind(grid_position)).set_delay(0.5)

## Drops in the bridges between the revealed tile on [param grid_position] and its revealed neighbours, as far as it is still
## placed
func _show_bridges_at(grid_position: Vector2i) -> void:
	var tile: Structure = _placed_tiles.get(grid_position)
	if not tile: return
	for direction: Direction in Direction.values(): _show_bridge(tile, direction)

## Drops in the bridge between [param tile] and its neighbour towards [param direction] once both are revealed; it drops in once
func _show_bridge(tile: Structure, direction: Direction) -> void:
	var bridge: Model = _bridges.get(_get_gap_position(tile.global_position, direction))
	if not bridge or bridge.has_meta(_SHOWN) or tile.shown_status != Structure.Status.REVEALED: return
	var neighbour: Structure = _placed_tiles.get(tile.get_grid_position() + direction_to_vector(direction))
	if not neighbour or neighbour.shown_status != Structure.Status.REVEALED: return
	bridge.set_meta(_SHOWN, true)
	tile.profile.decorations.drop_props([bridge] as Array[Model])

## Every peer: a turned [param tile] gets new bridges, once it rests on the board again (see [method _on_tile_landed]); what
## the turn brings into sight waits a moment, as the tile drops or spins into place
func _on_tile_turned(tile: Structure) -> void:
	if _placed_tiles.get(tile.get_grid_position()) != tile: return
	_hold_reveals_on(tile.get_grid_position())
	if tile.is_settled(): _update_gaps_of(tile)

## Every peer: no bridge leads onto a lifted [param tile] until it has landed
func _on_tile_lift_changed(tile: Structure) -> void:
	if tile.is_lifted(): _update_gaps_of(tile)

func _on_tile_landed(tile: Structure) -> void:
	_update_gaps_of(tile)

## What a turn brings into sight shows a moment after the tile turned (as it is set down, its drop starting), see
## [member TileLiftAnimation.reveal_delay]. A tween bound to the level, so it pauses with the game.
func _hold_reveals_on(grid_position: Vector2i) -> void:
	_reveals_held_on[grid_position] = true
	create_tween().tween_callback(_release_reveals_on.bind(grid_position)).set_delay(TileLiftAnimation.of(self).reveal_delay)

func _release_reveals_on(grid_position: Vector2i) -> void:
	_reveals_held_on.erase(grid_position)

## Lays or takes up the bridges on the four sides of [param tile] as they are needed now; bridges that stay are left alone,
## so they do not drop in again, and those between other tiles are not touched
func _update_gaps_of(tile: Structure) -> void:
	if _placed_tiles.get(tile.get_grid_position()) != tile: return
	for direction: Direction in Direction.values():
		var gap: Vector3 = _get_gap_position(tile.global_position, direction)
		var needed: bool = _needs_bridge(tile, direction)
		var bridge: Model = _bridges.get(gap)
		if bridge and not needed:
			_bridges.erase(gap)
			bridge.free()
		elif needed and not bridge:
			_lay_bridge(tile, direction)
			_show_bridge(tile, direction)

## Whether a bridge belongs between [param tile] and its neighbour towards [param direction]: both rest on the board and open
## to each other, and they are not one room (whose tiles always connect)
func _needs_bridge(tile: Structure, direction: Direction) -> bool:
	if not tile.profile.decorations or not tile.is_settled() or not tile.get_connections().has(direction): return false
	var neighbour: Structure = _placed_tiles.get(tile.get_grid_position() + direction_to_vector(direction))
	if not neighbour or not neighbour.is_settled() or not neighbour.get_connections().has(get_opposite(direction)): return false
	return tile.profile.room_type == null or neighbour.profile.room_type != tile.profile.room_type

## A bridge (see [member TileDecorations.bridges]) over the gap between [param tile] and its neighbour in [param direction],
## hidden until both are revealed
func _lay_bridge(tile: Structure, direction: Direction) -> void:
	var bridge: Model = tile.profile.decorations.create_bridge(tile.get_grid_position(), direction)
	if not bridge: return
	var gap: Vector3 = _get_gap_position(tile.global_position, direction)
	bridge.position = gap
	bridge.visible = false
	_bridges[gap] = bridge
	add_child(bridge)

func _on_thing_created(thing: Thing) -> void:
	var on_grid: Vector2 = Vector2(thing.global_position.x, thing.global_position.z) / grid_size
	var on_corner: bool = is_equal_approx(fposmod(on_grid.x, 1.0), 0.5) and is_equal_approx(fposmod(on_grid.y, 1.0), 0.5)
	if on_corner:
		var corner: Vector2i = Vector2i(roundi(on_grid.x + 0.5), roundi(on_grid.y + 0.5))
		_corner_things[corner] = thing
		for offset: Vector2i in CELL_CORNERS:
			var tile: Structure = get_placed_tile(corner - offset)
			var status: Thing.Status = Thing.structure_status_to_thing_status(tile.shown_status) if tile else Thing.Status.PLACED
			if status > thing.status: thing.status = status
	else: _placed_things[world_to_grid_position(thing.global_position)] = thing
	# Removed (e.g. by loading a save), it leaves the registries, so nothing looks for it any more
	thing.tree_exiting.connect(_forget_thing.bind(thing), CONNECT_ONE_SHOT)

## Drops a tile leaving the level from its registries, with the bridges on its sides
func _forget_tile(tile: Structure) -> void:
	var grid_position: Vector2i = world_to_grid_position(tile.global_position)
	if _placed_tiles.get(grid_position) == tile: _placed_tiles.erase(grid_position)
	_furnished_cells.erase(grid_position)
	restriction_fallbacks.erase(grid_position)
	# Until it is freed it may still change: nothing here follows it any more
	for handler: Array in [[tile.status_changed, _on_tile_status_changed], [tile.shown_status_changed, _on_tile_shown_status_changed], [tile.spawn_requested, _on_spawn_requested]]:
		var tile_signal: Signal = handler[0]
		var bound_handler: Callable = (handler[1] as Callable).bind(tile)
		if tile_signal.is_connected(bound_handler): tile_signal.disconnect(bound_handler)
	for queues: Dictionary in [_reveal_queues, _discover_queues]:
		for queue: Array in queues.values(): queue.erase(tile)
	# A bridge needs both sides
	for direction: Direction in Direction.values():
		var gap: Vector3 = _get_gap_position(tile.global_position, direction)
		var bridge: Model = _bridges.get(gap)
		_bridges.erase(gap)
		if is_instance_valid(bridge): bridge.queue_free()

func _forget_thing(thing: Thing) -> void:
	for registry: Dictionary in [_placed_things, _corner_things]:
		for key: Variant in registry.keys():
			if registry[key] == thing: registry.erase(key)

func _on_agent_created(agent: Agent) -> void:
	_register_character(agent.character)

func _on_player_controller_created(player_controller: PlayerController) -> void:
	var character: Character = player_controller.character
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

## Visual feedback on every peer: reveals start shortly after the figure crosses into a cell, as its move animation says
## (see [member ModelAnimation.reveal_delay])
func _on_figure_entered_grid_cell(_cell: Vector2i, character: Character) -> void:
	if not _reveal_queues.has(character): return
	var move_animation: ModelAnimation = character.profile.move_animation
	_remaining_tile_reveal_delays[character] = move_animation.duration * move_animation.reveal_delay
	_remaining_tile_discover_delays[character] = move_animation.duration * move_animation.reveal_delay

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
