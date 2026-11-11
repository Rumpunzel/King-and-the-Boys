extends RefCounted
## The rules every generated dungeon keeps, for the dungeon generation tests: passages lead both ways, neighbours
## keep their connection restrictions (except where the generator found no tile suiting them all, see
## [member Level.restriction_fallbacks]), tiles stay inside the closed outer wall

## Builds on from every placed tile [param rounds] times, as characters exploring would
static func explore(level: Level, rounds: int) -> void:
	for _round: int in rounds:
		for tile: Structure in level.get_placed_tiles():
			if is_wall(level, tile.get_grid_position()) or tile.get_connections().is_empty(): continue
			level.call("_build_dungeon_from", tile.get_grid_position())

static func is_wall(level: Level, cell: Vector2i) -> bool:
	return absi(cell.x) == level.grid_extents.x or absi(cell.y) == level.grid_extents.y

## @returns every broken rule, each naming [param generation_seed] so the dungeon can be built again
static func find_problems(level: Level, generation_seed: int) -> PackedStringArray:
	var problems: PackedStringArray = []
	var extents: Vector2i = level.grid_extents
	for tile: Structure in level.get_placed_tiles():
		var cell: Vector2i = tile.get_grid_position()
		if absi(cell.x) > extents.x or absi(cell.y) > extents.y: problems.append("Seed %d: a tile at %s outside the extents %s" % [generation_seed, cell, extents])
		if is_wall(level, cell): continue
		for direction: Level.Direction in Level.Direction.values():
			var neighbour: Structure = level.get_placed_tile(cell + Level.direction_to_vector(direction))
			if not neighbour: continue
			var neighbour_cell: Vector2i = neighbour.get_grid_position()
			var leads_there: bool = tile.has_connection(direction)
			if is_wall(level, neighbour_cell):
				if leads_there: problems.append("Seed %d: %s at %s leads into the outer wall" % [generation_seed, tile.profile.name, cell])
				continue
			if leads_there != neighbour.has_connection_to(cell):
				problems.append("Seed %d: %s at %s and %s at %s do not agree on their passage" % [generation_seed, tile.profile.name, cell, neighbour.profile.name, neighbour_cell])
			# Where the generator found no tile suiting every neighbour, it placed one ignoring their restrictions
			var fell_back: bool = level.restriction_fallbacks.has(cell) or level.restriction_fallbacks.has(neighbour_cell)
			if not fell_back and not tile.can_connect_to(neighbour_cell, neighbour.profile):
				problems.append("Seed %d: %s at %s may not stand next to %s at %s" % [generation_seed, tile.profile.name, cell, neighbour.profile.name, neighbour_cell])
	for y: int in range(-extents.y, extents.y + 1):
		for x: int in range(-extents.x, extents.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if is_wall(level, cell) and not level.get_placed_tile(cell): problems.append("Seed %d: the outer wall has a gap at %s" % [generation_seed, cell])
	return problems

## Each cell's tile: its profile and how it is turned
static func describe(level: Level) -> Dictionary[Vector2i, String]:
	var tiles: Dictionary[Vector2i, String] = {}
	for tile: Structure in level.get_placed_tiles(): tiles[tile.get_grid_position()] = "%s %d" % [tile.profile.resource_path, tile.clockwise_turns]
	return tiles
