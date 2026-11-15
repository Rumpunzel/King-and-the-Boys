@icon("uid://bfpmyljmhdkos")
class_name LevelSight
extends RefCounted
## What can be seen on a [Level]'s board, by the rule heroes see by: straight along passages and across whole rooms, never through
## a wall. Only answers questions; the level reveals and discovers what they name (see [method Level.update_sight])

var _level: Level

func _init(level: Level) -> void:
	_level = level

## Calls [param see_tile] with every tile in sight from [param from] within [param vision], always with the tile on [param from]
## (a character sees the tile it stands on, even without vision); [param origin] is where the looking starts, for rooms
func see(from: Vector2i, vision: float, see_tile: Callable, origin: Vector2i = from) -> void:
	if origin.distance_squared_to(from) > vision ** 2.0: return
	var from_tile: Structure = _level.get_placed_tile(from)
	assert(from_tile)
	# The passages below only reach the tiles they lead to (rooms see this one again, harmlessly)
	see_tile.call(from_tile)
	var origin_room_type: RoomType = _level.get_placed_tile(origin).profile.room_type
	if origin_room_type and origin_room_type == from_tile.profile.room_type: _see_in_room(from, vision, see_tile, origin)
	for direction: Level.Direction in from_tile.get_connections():
		var direction_vector: Vector2i = Level.direction_to_vector(direction)
		var tile: Structure = from_tile
		for radius: int in range(1, ceili(vision) + 1):
			# Sight follows passages only, like the corridors the level builds, so coming back to a cell never shows tiles that were
			# built later
			if not _level.is_passage(tile.get_grid_position(), direction): break
			var next_cell: Vector2i = from + direction_vector * radius
			if origin.distance_squared_to(next_cell) > vision ** 2.0: break
			tile = _level.get_placed_tile(next_cell)
			if not tile: break
			see_tile.call(tile)

## @returns the cells in sight from [param from] within [param vision] (as keys), [param from] itself among them. The rule is
## symmetric, but what each figure sees by is not: heroes by their vision, which lights widen, monsters by their perception
func get_cells_in_sight(from: Vector2i, vision: float) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {}
	see(from, vision, func(tile: Structure) -> void: seen[tile.get_grid_position()] = true)
	return seen

## The first step from [param from] along passages towards the nearest of [param targets] in sight from there within
## [param vision]; targets on [param from] itself are not looked for
## @returns its [enum Level.Direction], or [code]-1[/code] if none is in sight
func get_step_towards_in_sight(from: Vector2i, targets: Array[Vector2i], vision: float) -> int:
	var in_sight: Dictionary[Vector2i, bool] = get_cells_in_sight(from, vision)
	var seen: Array[Vector2i] = []
	for target: Vector2i in targets:
		if target != from and in_sight.has(target): seen.append(target)
	if seen.is_empty(): return -1
	# Breadth first from the cells one step away, each knowing the step it started with
	var first_steps: Dictionary[Vector2i, int] = {from: -1}
	var frontier: Array[Vector2i] = []
	for direction: Level.Direction in Level.Direction.values():
		if not _level.is_passage(from, direction): continue
		var neighbour: Vector2i = from + Level.direction_to_vector(direction)
		first_steps[neighbour] = direction
		frontier.append(neighbour)
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			if seen.has(cell): return first_steps[cell]
			for direction: Level.Direction in Level.Direction.values():
				var neighbour: Vector2i = cell + Level.direction_to_vector(direction)
				if first_steps.has(neighbour) or not _level.is_passage(cell, direction): continue
				first_steps[neighbour] = first_steps[cell]
				next_frontier.append(neighbour)
		frontier = next_frontier
	return -1

## @returns the cells that show from afar from [param from] within [param reach]: the cells lit by a wall light (see
## [method Structure.get_lit_cells]) that sight from there reaches, never one around a corner
func get_beacon_cells(from: Vector2i, reach: float) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = get_cells_in_sight(from, reach)
	var lit: Array[Vector2i] = []
	for cell: Vector2i in seen:
		for lit_cell: Vector2i in _level.get_placed_tile(cell).get_lit_cells():
			if seen.has(lit_cell) and not lit.has(lit_cell): lit.append(lit_cell)
	return lit

func _see_in_room(from: Vector2i, vision: float, see_tile: Callable, origin: Vector2i, already_visited: Array[Vector2i] = []) -> void:
	assert(not already_visited.has(from))
	already_visited.append(from)
	if origin.distance_squared_to(from) > vision ** 2.0: return
	var from_tile: Structure = _level.get_placed_tile(from)
	assert(from_tile)
	see_tile.call(from_tile)
	var room_type: RoomType = _level.get_placed_tile(origin).profile.room_type
	assert(room_type and from_tile.profile.room_type == room_type)
	for connection: Level.Direction in from_tile.get_connections():
		var room_cell: Vector2i = from + Level.direction_to_vector(connection)
		var room_tile: Structure = _level.get_placed_tile(room_cell)
		# An exit may lead into a cell the dungeon has not grown into yet: a room tile placed beside a corridor joins a room built
		# before it, its own exits unbuilt
		if not room_tile: continue
		if room_type == room_tile.profile.room_type and not already_visited.has(room_cell): _see_in_room(room_cell, vision, see_tile, origin, already_visited)
