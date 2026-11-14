extends Node
## Measures how crowded generated dungeons are, to compare generator changes: builds the real dungeon over many seeds,
## explores each until it grows no more and prints, per seed and on average, its tiles, how many pairs of neighbouring
## tiles touch without a passage (walls back to back, the crowding), those per tile, and its dead ends. Runs headless:
## [code]<godot> --headless --path . res://tools/dungeon_stats/dungeon_stats.tscn -- --seeds=40[/code];
## [code]--crowding=0.2[/code] tries another [member DungeonTileSet.crowding_weight] than the dungeon's, [code]--map[/code]
## draws each dungeon (thin lines corridors, thick ones rooms)

## data/levels/level.tscn, the real dungeon
const LEVEL: String = "uid://bmwhs3lwb74ue"
## Rounds of building on from every tile at most; a dungeon stops growing long before
const MAX_ROUNDS: int = 30
## A tile drawn by its passages (up 1, right 2, down 4, left 8), corridors thin, rooms thick
const CORRIDOR_SHAPES: String = " ╵╶└╷│┌├╴┘─┴┐┤┬┼"
const ROOM_SHAPES: String = "▪╹╺┗╻┃┏┣╸┛━┻┓┫┳╋"

func _ready() -> void:
	var seeds: int = int(_get_argument("seeds", "40"))
	var totals: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	print("seed  tiles  contacts  per tile  dead ends")
	for generation_seed: int in seeds:
		var level: Level = (load(LEVEL) as PackedScene).instantiate()
		level.spawns_monsters = false
		var crowding: String = _get_argument("crowding", "")
		if crowding: (level.get(&"_tile_set") as DungeonTileSet).crowding_weight = crowding.to_float()
		level.generation_random.seed = generation_seed
		add_child(level)
		level.build_level()
		_explore(level)
		var row: PackedFloat64Array = _measure(level)
		print("%4d  %5d  %8d  %8.2f  %9d" % [generation_seed, row[0], row[1], row[2], row[3]])
		for index: int in row.size(): totals[index] += row[index]
		if OS.get_cmdline_user_args().has("--map"): _draw_map(level)
		remove_child(level)
		level.queue_free()
		await get_tree().process_frame
	print("mean  %5.1f  %8.1f  %8.2f  %9.1f" % [totals[0] / seeds, totals[1] / seeds, totals[2] / seeds, totals[3] / seeds])
	get_tree().quit()

## Builds on from every tile, as characters exploring everything would, until no tile is added
func _explore(level: Level) -> void:
	for _round: int in MAX_ROUNDS:
		var before: int = level.get_placed_tiles().size()
		for tile: Structure in level.get_placed_tiles():
			if _is_wall(level, tile.get_grid_position()) or tile.get_connections().is_empty(): continue
			level.call("_build_dungeon_from", tile.get_grid_position())
		if level.get_placed_tiles().size() == before: return

## @returns tiles, contacts (neighbouring tiles without a passage, each pair once), contacts per tile, dead ends
func _measure(level: Level) -> PackedFloat64Array:
	var tiles: int = 0
	var contacts: int = 0
	var dead_ends: int = 0
	for tile: Structure in level.get_placed_tiles():
		var cell: Vector2i = tile.get_grid_position()
		if _is_wall(level, cell): continue
		tiles += 1
		if tile.get_connections().size() == 1: dead_ends += 1
		# Right and down only, so each pair counts once
		for direction: Level.Direction in [Level.Direction.RIGHT, Level.Direction.DOWN]:
			var neighbour_cell: Vector2i = cell + Level.direction_to_vector(direction)
			if _is_wall(level, neighbour_cell) or not level.get_placed_tile(neighbour_cell): continue
			if not tile.has_connection(direction): contacts += 1
	return [tiles, contacts, float(contacts) / maxi(tiles, 1), dead_ends]

func _draw_map(level: Level) -> void:
	var extents: Vector2i = level.grid_extents
	for y: int in range(-extents.y, extents.y + 1):
		var line: String = ""
		for x: int in range(-extents.x, extents.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var tile: Structure = level.get_placed_tile(cell)
			if _is_wall(level, cell): line += "#"
			elif not tile: line += "·"
			else:
				var shape: int = 0
				for direction: Level.Direction in Level.Direction.values():
					if tile.has_connection(direction): shape |= 1 << direction
				line += (ROOM_SHAPES if tile.profile.room_type else CORRIDOR_SHAPES)[shape]
		print(line)

func _is_wall(level: Level, cell: Vector2i) -> bool:
	return absi(cell.x) == level.grid_extents.x or absi(cell.y) == level.grid_extents.y

## The value of [code]--<argument_name>=<value>[/code] after [code]--[/code] on the command line, or [param default]
func _get_argument(argument_name: String, default: String) -> String:
	var prefix: String = "--%s=" % argument_name
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return default
