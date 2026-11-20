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
## Host only: [param character] was put on this level (see [method add_character])
signal character_added(character: Character)
## Host only: [member monsters_enabled] changed
signal monsters_toggled
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
## How far towards a grid corner (on both axes) a thing on it keeps figures from standing (see [Formation])
const _CORNER_SPOT_REACH: float = 0.5
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

## Whether newly placed tiles may hold monsters at all (scenes and tests that are not about monsters turn it off)
@export var spawns_monsters: bool = true
## What may wait on a newly placed tile (e.g. a skeleton); set in the scene, like [member _wall_tile]
@export var _monsters: SpawnTable
## Chance of a newly placed corridor tile to hold a monster
@export_range(0.0, 1.0) var _monster_chance: float = 0.08
## Chance of a newly placed room tile to hold a monster
@export_range(0.0, 1.0) var _room_monster_chance: float = 0.15
## How far along passages a hero sees a lit tile beyond its own sight (see [member Structure.light]), in cells
@export var beacon_reach: float = 6.0

## How tiles move while lifted, e.g. by the Mystic turning one; set in the scene, as its particles are assets. Without one, tiles
## lift with [TileLiftAnimation]'s defaults and no particles
@export var tile_lift_animation: TileLiftAnimation

@export var _reveals_per_second: float = 16.0
@export var _discovers_per_second: float = 2.0

@export_group("Configuration")
@export var _structure_spawner: StructureSpawner
@export var _thing_spawner: ThingSpawner
@export var _agent_spawner: AgentSpawner

## Host only, for debugging: monsters off are taken off the board (not visible, replicated), so they neither show, act, block
## nor hold a spot; spawning goes on, and turning them on again brings every one back where it stood. Not saved
var monsters_enabled: bool = true:
	set(new_monsters_enabled):
		assert(multiplayer.is_server())
		monsters_enabled = new_monsters_enabled
		for node: Node in _agent_spawner.get_children():
			var agent: Agent = node as Agent
			if agent and not agent.is_queued_for_deletion(): agent.character.visible = monsters_enabled
		monsters_toggled.emit()

## Host only: whether [method build_level] ran, see [signal built]
var is_built: bool = false
## Host only: the dice the dungeon is generated with. Seeded, it builds the same dungeon again for the same order of
## exploration (e.g. in tests); its state is not saved yet, so a loaded game grows on differently.
var generation_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Host only: cells where no tile kept every neighbour's connection restrictions, so the one keeping the most was
## placed (e.g. a treasure dead end wanting empty space where the dungeon grew later); for tests and debugging
var restriction_fallbacks: Dictionary[Vector2i, bool] = {}

var _placed_tiles: Dictionary[Vector2i, Structure]
# Answers what can be seen on the board; the level reveals and discovers what it names
var _sight: LevelSight = LevelSight.new(self)
## Bridges over the gaps between tiles opening to each other, by the middle of the gap (see [method _get_gap_position]); each
## peer lays its own, as they are only for show
var _bridges: Dictionary[Vector3, Model]
## Cells whose tile just turned: what the turn brought into sight waits there a moment, see
## [member TileLiftAnimation.reveal_delay]
## {cell: how many turns hold it}, so a second turn soon after the first is waited for too
var _reveals_held_on: Dictionary[Vector2i, int] = {}

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
var _formations: LevelFormations = LevelFormations.new(self)

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
	return turn_direction(direction, 2)

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
	var pick: DungeonTileSet.Pick = _tile_set.pick_tile(grid_position, _get_surrounding_tiles(grid_position), _get_crowded_directions(grid_position), generation_random)
	assert(pick.blueprint)
	if not pick.suits_all: restriction_fallbacks[grid_position] = true
	_spawn_at(pick.blueprint, grid_position, status)

## Host only: spawns a monster of [param profile] (a random model variation) on the tile nearest [param cell] with room for it,
## that cell's if it has (see [method get_nearest_room_position]), facing [param facing]; peers get it through the [AgentSpawner]
func spawn_monster(profile: CharacterProfile, cell: Vector2i, facing: Direction = Direction.DOWN, random: RandomNumberGenerator = null) -> void:
	assert(multiplayer.is_server())
	assert(profile.group == CharacterProfile.Groups.MONSTERS)
	if not _placed_tiles.has(cell):
		push_warning("No tile on %s for a %s" % [cell, profile.name])
		return
	var spot_position: Vector3 = get_nearest_room_position(cell, profile.group)
	if spot_position == Vector3.INF:
		push_warning("No room for a %s near %s" % [profile.name, cell])
		return
	var spawn_transform: Transform3D = Transform3D(Basis(Vector3.UP, Character.facing_to_rotation(facing)), spot_position)
	_agent_spawner.spawn_agent(profile.create_character_data(profile.get_random_variation(random), spawn_transform))

## Every peer: a monster shows only on a tile this peer has revealed; it holds its spot either way
func _update_shown(character: Character) -> void:
	if character.profile.group != CharacterProfile.Groups.MONSTERS: return
	var tile: Structure = _placed_tiles.get(character.grid_cell)
	character.shown = tile != null and tile.shown_status == Structure.Status.REVEALED

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

## The first step from [param from] along passages towards the nearest of [param targets] in sight within [param vision], e.g. a
## monster coming for the heroes it notices (see [method LevelSight.get_step_towards_in_sight])
## @returns its [enum Direction], or [code]-1[/code] if none is in sight
func get_step_towards_in_sight(from: Vector2i, targets: Array[Vector2i], vision: float) -> int:
	return _sight.get_step_towards_in_sight(from, targets, vision)

## The first step from [param from] along passages towards [param target], however far, e.g. a monster going to look where it
## last noticed a hero (see [method LevelSight.get_step_towards])
## @returns its [enum Direction], or [code]-1[/code] if it stands there or can not get there
func get_step_towards(from: Vector2i, target: Vector2i) -> int:
	if from == target: return -1
	return _sight.get_step_towards(from, [target])

## @returns the number of steps along passages from [param from] to every placed cell at most [param max_length] steps away
## ([param from] itself 0), e.g. which noticed hero is nearest to a monster (see [method LevelSight.get_path_lengths])
func get_path_lengths(from: Vector2i, max_length: int) -> Dictionary[Vector2i, int]:
	return _sight.get_path_lengths(from, max_length)

## @returns the cells in sight from [param from] within [param vision] (as keys), by the rule heroes see by (straight along
## passages, across whole rooms); see [method LevelSight.get_cells_in_sight]
func get_cells_in_sight(from: Vector2i, vision: float) -> Dictionary[Vector2i, bool]:
	return _sight.get_cells_in_sight(from, vision)

## The cells a piece on [param grid_position] reaches, e.g. to take control of what stands there: its own and the next ones
## along passages, where it could step
func get_cells_in_reach(grid_position: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [grid_position]
	for direction: Direction in Direction.values():
		if is_passage(grid_position, direction): cells.append(grid_position + direction_to_vector(direction))
	return cells

## The cells [param piece] stands on: a character's [member Character.grid_cell], a tile's cells, all four cells around
## a thing on a grid corner (e.g. a centrepiece), else the cell under it
func get_cells_of(piece: BoardObject) -> Array[Vector2i]:
	if piece is Character: return [(piece as Character).grid_cell]
	if piece is Structure: return (piece as Structure).get_grid_cells()
	var corner: Variant = _corner_things.find_key(piece)
	if corner == null: return [world_to_grid_position(piece.global_position)]
	var corner_cell: Vector2i = corner
	var cells: Array[Vector2i] = []
	for offset: Vector2i in CELL_CORNERS: cells.append(corner_cell - offset)
	return cells

func get_spot_position(grid_position: Vector2i, spot: Vector2) -> Vector3:
	return grid_to_world_position(grid_position) + Vector3(spot.x, 0.0, spot.y)

## A position on [param grid_position] if it has room for one more of [param group] (see [method has_room]), else on the
## nearest revealed tile along passages that has (tiles the party has seen; unexplored ones would build dungeon away from it),
## ignoring [param except]: where a character goes once its tile is full. [code]Vector3.INF[/code] if no tile reached has room.
func get_nearest_room_position(grid_position: Vector2i, group: CharacterProfile.Groups, except: Character = null) -> Vector3:
	var cells: Array[Vector2i] = [grid_position]
	var reached: Dictionary[Vector2i, bool] = {grid_position: true}
	var next: int = 0
	while next < cells.size():
		var cell: Vector2i = cells[next]
		next += 1
		if has_room(cell, group, except): return grid_to_world_position(cell)
		var tile: Structure = get_placed_tile(cell)
		if not tile: continue
		for direction: Direction in tile.get_connections():
			var neighbour: Vector2i = cell + direction_to_vector(direction)
			var neighbour_tile: Structure = get_placed_tile(neighbour)
			# Passages only (the edge of what is built may lead nowhere yet), into revealed tiles
			if reached.has(neighbour) or not neighbour_tile or neighbour_tile.status < Structure.Status.REVEALED: continue
			if not neighbour_tile.has_connection_to(cell): continue
			reached[neighbour] = true
			cells.append(neighbour)
	return Vector3.INF

## @returns whether a figure of [param group] may stand on [param grid_position], ignoring [param except]: a placed tile with
## fewer than [constant Formation.MAX_PER_SIDE] of that side on it, standing or not
func has_room(grid_position: Vector2i, group: CharacterProfile.Groups, except: Character = null) -> bool:
	if not _placed_tiles.has(grid_position): return false
	var count: int = 0
	for character: Character in get_figures_on(grid_position, except):
		if character.profile.group == group: count += 1
	return count < Formation.MAX_PER_SIDE

## @returns the lead of [param group]'s side on [param grid_position]: its first standing figure by
## [member CharacterProfile.block_priority], in turn order among equals, who blocks and is blocked, and stands in front of its
## side's [Formation]; [code]null[/code] if none stands there
func get_lead(grid_position: Vector2i, group: CharacterProfile.Groups) -> Character:
	for character: Character in Formation.by_priority(get_figures_on(grid_position)):
		if character.profile.group == group and character.posture == Character.Posture.STANDING: return character
	return null

## @returns the figures on the board on [param grid_position] (not those taken off it, see [member Character.visible]), but
## [param except], in turn order
func get_figures_on(grid_position: Vector2i, except: Character = null) -> Array[Character]:
	var figures: Array[Character] = []
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if character == except or not character.visible or character.level != self or character.grid_cell != grid_position: continue
		if not character.is_queued_for_deletion(): figures.append(character)
	return figures

## Host only: the edge (a [enum Direction]) the side of [param group] holds on [param grid_position], which its figures line up
## towards and are pushed out over (see [LevelFormations]); [code]-1[/code] if none of it stands there
func get_side_edge(grid_position: Vector2i, group: CharacterProfile.Groups) -> int:
	assert(multiplayer.is_server())
	return _formations.get_side_edge(grid_position, group)

## @returns the spots on [param grid_position] taken by what stands there: a thing (e.g. a chest) in the middle, a thing on a
## corner (e.g. a centrepiece) towards it
func get_blocked_spots(grid_position: Vector2i) -> Array[Vector2]:
	var blocked: Array[Vector2] = []
	if _placed_things.has(grid_position): blocked.append(Vector2.ZERO)
	for corner: Vector2i in CELL_CORNERS:
		if _corner_things.has(grid_position + corner): blocked.append(_get_corner_spot(corner))
	return blocked

## @returns the spot towards the grid corner [param corner] (one of [constant CELL_CORNERS]) of a tile
static func _get_corner_spot(corner: Vector2i) -> Vector2:
	return (Vector2(corner) * 2.0 - Vector2.ONE) * _CORNER_SPOT_REACH

## Host only: turns [param tile] by [param clockwise_turns] quarter turns with the pieces on it, then builds and looks
## along its new passages as a step of [param character] would: the heroes' sight is updated from where they stand.
## Emits [signal board_changed] for [param character] if that discovered or revealed tiles.
func rotate_tile(tile: Structure, clockwise_turns: int, character: Character) -> void:
	assert(multiplayer.is_server())
	var grid_position: Vector2i = tile.get_grid_position()
	assert(_placed_tiles.get(grid_position) == tile)
	# The pieces turn with it, and the edges their sides hold; then they keep clear of what does not turn (e.g. a centrepiece on a
	# corner)
	for piece: Character in get_figures_on(grid_position):
		piece.place_on_grid(grid_position, turn_spot(piece.tile_spot, clockwise_turns), turn_direction(piece.facing, clockwise_turns))
	_formations.turn_edges(grid_position, clockwise_turns)
	_formations.arrange(grid_position)
	# The thing on it turns with it, on every peer, see _on_tile_turned
	tile.clockwise_turns = posmod(tile.clockwise_turns + clockwise_turns, Direction.size())
	tile_rotated.emit(tile, character)
	var board_change_count_before: int = _board_change_count
	_stepping_character = character
	_build_dungeon_from(grid_position)
	_update_heroes_sight(character)
	_stepping_character = null
	if _board_change_count != board_change_count_before: board_changed.emit(character)

func _build_outer_wall() -> void:
	for y: int in range(-grid_extents.y, grid_extents.y + 1):
		for x: int in range(-grid_extents.x, grid_extents.x + 1):
			if absi(y) != grid_extents.y and absi(x) != grid_extents.x: continue
			var wall_roation: int = 1 if absi(y) == grid_extents.y else 0
			var wall_position: Vector2i = Vector2i(x, y)
			_spawn_at(DungeonTileSet.TileBlueprint.new(_wall_tile, wall_roation), wall_position)
			var wall: Structure = _placed_tiles[wall_position]
			wall.reveal()

## The cell of the level's only [PlayerSpawnPoint], where the starting tile lies
func _get_starting_cell() -> Vector2i:
	var all_player_spawn_points: Array[Node] = get_tree().get_nodes_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS)
	assert(all_player_spawn_points.size() == 1)
	var player_spawn_point: PlayerSpawnPoint = all_player_spawn_points.front()
	assert(player_spawn_point)
	return world_to_grid_position(player_spawn_point.global_position)

func _place_starting_tile() -> Vector2i:
	assert(_starting_tile)
	var starting_tile_blueprint: DungeonTileSet.TileBlueprint = DungeonTileSet.TileBlueprint.new(_starting_tile, 0)
	var starting_grid_position: Vector2i = _get_starting_cell()
	_spawn_at(starting_tile_blueprint, starting_grid_position)
	var starting_tile: Structure = _placed_tiles[starting_grid_position]
	assert(starting_tile)
	_reveal_tile(starting_tile)
	return starting_grid_position

func _build_dungeon_from(origin_grid_position: Vector2i) -> void:
	var tile: Structure = _placed_tiles[origin_grid_position]
	assert(tile)
	var placed_before: Dictionary[Vector2i, Structure] = _placed_tiles.duplicate()
	var already_visited: Array[Vector2i] = [origin_grid_position]
	if tile.profile.room_type: _build_room_from(origin_grid_position, tile.profile.room_type, already_visited)
	for direction: Direction in tile.get_connections(): _build_corridor_from(origin_grid_position, direction, already_visited)
	# After the rooms are furnished, so the centrepieces are decided first
	var placed_now: Array[Vector2i] = []
	for cell: Vector2i in _placed_tiles:
		if not placed_before.has(cell): placed_now.append(cell)
	_populate(placed_now)

## Host only: each tile the dungeon grew by (the [param cells] a build placed) may hold a monster, rolled once as it is placed;
## a loaded tile never is. The roll is seeded by the level's seed and the cell, so the same seed places the same monsters.
## None near the start
func _populate(cells: Array[Vector2i]) -> void:
	if not spawns_monsters or not _monsters or cells.is_empty(): return
	var starting_cell: Vector2i = _get_starting_cell()
	for cell: Vector2i in cells:
		var tile: Structure = _placed_tiles.get(cell)
		if not tile or _get_distance(cell, starting_cell) <= 1: continue
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash([generation_random.seed, cell, &"monster"])
		if random.randf() >= (_room_monster_chance if tile.profile.room_type else _monster_chance): continue
		var profile: CharacterProfile = _monsters.get_spawn(random) as CharacterProfile
		if profile: spawn_monster(profile, cell, (random.randi() % Direction.size()) as Direction, random)

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
			_spawn_whole(neighbour_position, already_visited)
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
		_spawn_whole(grid_position, already_visited, room_type)
		_spread_room_from(grid_position, room_type, already_visited)

## Places a tile on [param grid_position] (see [method spawn_at]). A new tile of a room other than [param spreading] (the one being
## built) is built out with its whole room, so no room waits half built, its exits leading nowhere, until a hero steps in
func _spawn_whole(grid_position: Vector2i, already_visited: Array[Vector2i], spreading: RoomType = null) -> void:
	var is_new: bool = not _placed_tiles.has(grid_position)
	spawn_at(grid_position)
	var room_type: RoomType = _placed_tiles[grid_position].profile.room_type
	if is_new and room_type and room_type != spreading: _build_room_from(grid_position, room_type, already_visited)

## Host only: now and then a centrepiece in the middle of the room around [param grid_position], which must be built whole. Rooms are
## built again on every step, so the roll is seeded by the room, and a corner holding a thing already is left alone
func _furnish_room(grid_position: Vector2i) -> void:
	if not _room_centrepieces or _furnished_cells.has(grid_position): return
	var cells: Array[Vector2i] = get_room_cells(grid_position)
	var found: Variant = get_centrepiece_corner(cells)
	# Decided already: a room that grew (a tile of its type placed beside it joins it) was as it was first built; and none where no
	# corner suits one, or a thing stands there
	if cells.any(func(cell: Vector2i) -> bool: return _furnished_cells.has(cell)) or found == null or _corner_things.has(found):
		_remember_furnished(cells)
		return
	var corner: Vector2i = found
	# A figure (e.g. in a save from before rooms had centrepieces) may stand on a spot it would take on one of its tiles: later
	if _is_corner_spot_taken(corner): return
	_remember_furnished(cells)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(cells.min()) ^ hash(&"centrepiece")
	if random.randf() >= _room_centrepiece_chance: return
	var profile: ThingProfile = _room_centrepieces.get_spawn() as ThingProfile
	if not profile: return
	var turn: Basis = Basis(Vector3.UP, PI * 0.5 * (random.randi() % 4))
	# Unrevealed: every peer shows it with its own view of the four tiles, see _on_thing_created
	_thing_spawner.spawn_at(profile, Transform3D(turn, get_corner_world_position(corner)), Thing.Status.PLACED)

## @returns whether a figure stands where a thing on [param corner] would stand on one of its four tiles (the spot towards it,
## see [method get_blocked_spots])
func _is_corner_spot_taken(corner: Vector2i) -> bool:
	for offset: Vector2i in CELL_CORNERS:
		var cell: Vector2i = corner - offset
		for character: Character in get_figures_on(cell):
			if character.tile_spot.distance_to(_get_corner_spot(offset)) < _CORNER_SPOT_REACH: return true
	return false

## Rooms are built again on every step; their centrepiece is decided once
func _remember_furnished(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells: _furnished_cells[cell] = true

func _spawn_at(tile_blueprint: DungeonTileSet.TileBlueprint, grid_position: Vector2i, status: Structure.Status = Structure.Status.PLACED) -> void:
	assert(absi(grid_position.x) <= grid_extents.x)
	assert(absi(grid_position.y) <= grid_extents.y)
	var tile_position: Vector3 = grid_to_world_position(grid_position)
	var tile_transform: Transform3D = Transform3D(Basis.IDENTITY, tile_position)
	var decorations: TileDecorations = tile_blueprint.profile.decorations
	var light: TileLight = decorations.roll_light(tile_blueprint.profile, generation_random.seed, grid_position) if decorations else null
	_structure_spawner.spawn_at(tile_blueprint.profile, tile_transform, tile_blueprint.clockwise_turns, status, light, is_dusty(tile_blueprint.profile, grid_position))

## Host only: whether dust lies over a tile of [param profile] placed on [param cell]. A room is dusty or not as a whole: a room tile
## beside a placed tile of its room type (which it connects to, see [method Structure.get_connections]) takes that tile's dust, so
## a room keeps it as it grows (one joining two rooms takes the first one's); the first tile of a room rolls it (see
## [method TileDecorations.roll_dust])
func is_dusty(profile: StructureProfile, cell: Vector2i) -> bool:
	if not profile.room_type or not profile.decorations: return false
	for direction_vector: Vector2i in DIRECTION_VECTORS:
		var neighbour: Structure = _placed_tiles.get(cell + direction_vector)
		if neighbour and neighbour.profile.room_type == profile.room_type: return neighbour.dusty
	return profile.decorations.roll_dust(generation_random.seed, cell)

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

## The sides of [param grid_position] leading into an empty cell that a placed tile turns its back on (a closed side, not
## the outer wall's) and none opens into: a passage there would grow the dungeon into the gap beside that tile, see
## [member DungeonTileSet.crowding_weight]. Tiles count by their shape, even while lifted (their passages are closed then)
func _get_crowded_directions(grid_position: Vector2i) -> Array[Direction]:
	var crowded: Array[Direction] = []
	for direction: Direction in Direction.values():
		var cell: Vector2i = grid_position + direction_to_vector(direction)
		if _placed_tiles.has(cell): continue
		var backed_onto: bool = false
		var opened_into: bool = false
		for neighbour_direction: Direction in Direction.values():
			var neighbour: Structure = _placed_tiles.get(cell + direction_to_vector(neighbour_direction))
			if not neighbour or neighbour.profile == _wall_tile: continue
			if neighbour.get_connections().has(get_opposite(neighbour_direction)): opened_into = true
			else: backed_onto = true
		if backed_onto and not opened_into: crowded.append(direction)
	return crowded

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
	structure.clockwise_turns_changed.connect(_on_tile_turned.bind(structure))
	structure.lift_changed.connect(_on_tile_lift_changed.bind(structure))
	structure.landed.connect(_on_tile_landed.bind(structure))
	# Removed (e.g. by loading a save), it leaves the registries with its connections, like things do
	structure.tree_exiting.connect(_forget_tile.bind(structure), CONNECT_ONE_SHOT)
	tile_placed.emit(structure)
	# A monster replicated before its tile shows once the tile does
	_update_shown_on(tile_grid_position)
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
	_update_shown_on(grid_position)
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
## Every peer: the thing on a turned tile turns with it (its transform is only sent as it spawns, like a character's), see
## [method rotate_tile]
func _on_tile_turned(previous_clockwise_turns: int, tile: Structure) -> void:
	if _placed_tiles.get(tile.get_grid_position()) != tile: return
	var thing: Thing = _placed_things.get(tile.get_grid_position())
	if thing: thing.rotate_y(-(tile.clockwise_turns - previous_clockwise_turns) * PI * 0.5)
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
	_reveals_held_on[grid_position] = _reveals_held_on.get(grid_position, 0) + 1
	create_tween().tween_callback(_release_reveals_on.bind(grid_position)).set_delay(TileLiftAnimation.of(self).reveal_delay)

func _release_reveals_on(grid_position: Vector2i) -> void:
	var holds: int = _reveals_held_on.get(grid_position, 0) - 1
	if holds > 0: _reveals_held_on[grid_position] = holds
	else: _reveals_held_on.erase(grid_position)

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
		var method: Callable = handler[1]
		var bound_handler: Callable = method.bind(tile)
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
	add_character(agent.character)
	# Spawned while monsters are off: off with them, until they are turned on
	if multiplayer.is_server() and not monsters_enabled: agent.character.visible = false

func _on_player_controller_created(player_controller: PlayerController) -> void:
	var character: Character = player_controller.character
	add_character(character)
	if multiplayer.is_server(): follow_sight_of(character)

## Puts [param character] on this level: it reveals what it should and, on the host, its tile lays out its figures (see
## [LevelFormations]). The spawners call it for every character they create
func add_character(character: Character) -> void:
	character.level = self
	character.entered_grid_cell.connect(_update_shown.bind(character).unbind(1))
	character.figure_entered_grid_cell.connect(_on_figure_entered_grid_cell.bind(character))
	if not multiplayer.is_server(): return
	character.exited_grid_cell.connect(_formations.on_character_exited.bind(character))
	character.entered_grid_cell.connect(_formations.on_character_entered.bind(character))
	character.posture_changed.connect(_formations.on_character_changed.bind(character))
	character.visibility_changed.connect(_formations.on_character_changed.bind(character))
	character.tree_exiting.connect(_formations.on_character_leaving.bind(character))
	character_added.emit(character)

func _update_shown_on(grid_position: Vector2i) -> void:
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if character.level == self and character.grid_cell == grid_position: _update_shown(character)

## Host only: what the hero [param character] sees comes into sight as it steps and as the lights it carries change (a torch
## equipped, a lantern lit; see [method Character.get_vision])
func follow_sight_of(character: Character) -> void:
	character.entered_grid_cell.connect(_on_player_moved.bind(character))
	character.light_sources_changed.connect(_on_player_lights_changed.bind(character))

func _on_player_lights_changed(character: Character) -> void:
	# As on a turned tile: a hero hidden while it controls something else sees nothing
	if not character.is_node_ready() or not character.visible or character.profile.group != CharacterProfile.Groups.HEROES: return
	if _placed_tiles.has(character.grid_cell): update_sight(character, character.grid_cell)

func _on_player_moved(character_grid_position: Vector2i, character: Character) -> void:
	assert(_placed_tiles[character_grid_position])
	update_sight(character, character_grid_position)

## Host only: what [param character] sees from [param from_cell] comes into sight, the dungeon growing
## there first, e.g. after a step or as a light it carries is lit (see [method Character.get_vision])
func update_sight(character: Character, from_cell: Vector2i) -> void:
	var board_change_count_before: int = _board_change_count
	# Tiles placed while building are discovered with this step too, see _on_structure_created
	_stepping_character = character
	_build_dungeon_from(from_cell)
	_see_from(from_cell, character, character)
	# What the step placed (a lit tile) may change what the others see too
	_update_heroes_sight(character, character)
	_stepping_character = null
	if _board_change_count != board_change_count_before: board_changed.emit(character)

## What every hero on the board sees from where it stands comes into sight, [param character] causing it; [param skip] has seen
## already. A hero hidden while it controls something else sees nothing
func _update_heroes_sight(character: Character, skip: Character = null) -> void:
	for hero: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if hero == skip or not hero.visible or hero.level != self or hero.profile.group != CharacterProfile.Groups.HEROES: continue
		if hero.is_node_ready() and _placed_tiles.has(hero.grid_cell): _see_from(hero.grid_cell, hero, character)

## What [param hero] sees from [param from_cell] comes into sight: it reveals by its vision, discovers by its darkvision and sees
## lit tiles from afar; [param character] caused it
func _see_from(from_cell: Vector2i, hero: Character, character: Character) -> void:
	_sight.see(from_cell, hero.get_vision(), _reveal_tile.bind(character))
	_sight.see(from_cell, hero.get_dark_vision(), _discover_tile.bind(character))
	_reveal_beacons(from_cell, character)

## Lit tiles show from afar: every cell a wall light lights that sight from [param from_cell] reaches along passages within
## [member beacon_reach] is revealed, never one around a corner (see [method LevelSight.get_beacon_cells]); [param character]
## caused it, as for any reveal
func _reveal_beacons(from_cell: Vector2i, character: Character) -> void:
	for cell: Vector2i in _sight.get_beacon_cells(from_cell, beacon_reach): _reveal_tile(_placed_tiles[cell], character)

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
