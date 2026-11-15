@icon("uid://bfpmyljmhdkos")
class_name LevelFormations
extends RefCounted
## Lays out the figures on a [Level]'s tiles by their [Formation] whenever who stands on one changes, and keeps the
## edge each side holds on a tile (see [method get_side_edge]), which its figures line up towards and are pushed out over

var _level: Level
## The edge each side holds on a tile, by cell, then by group; the cell a figure left, until it enters the next (see
## [method on_character_entered])
var _side_edges: Dictionary[Vector2i, Dictionary] = {}
var _left_cells: Dictionary[Character, Vector2i] = {}

func _init(level: Level) -> void:
	_level = level

## The edge (a [enum Level.Direction]) the side of [param group] holds on [param grid_position]; [code]-1[/code] if none of it
## stands there
func get_side_edge(grid_position: Vector2i, group: CharacterProfile.Groups) -> int:
	return get_side_edges(grid_position).get(group, -1)

## The edges the sides on [param grid_position] (but [param except]) hold, by group: kept from when the side came onto
## the tile (see [method on_character_entered]), else taken from where its figures stand (e.g. loaded, or spawned there), else
## the one facing the other side's; sides no longer there are forgotten
func get_side_edges(grid_position: Vector2i, except: Character = null) -> Dictionary:
	var edges: Dictionary = _side_edges.get(grid_position, {})
	var spots: Dictionary = {}
	for character: Character in _level.get_figures_on(grid_position, except):
		var group_spots: Array = spots.get_or_add(character.profile.group, [])
		group_spots.append(character.tile_spot)
	for group: Variant in edges.keys(): if not spots.has(group): edges.erase(group)
	for group: Variant in spots.keys():
		if edges.has(group): continue
		var group_spots: Array = spots[group]
		var middle: Vector2 = Vector2.ZERO
		for spot: Vector2 in group_spots: middle += spot
		middle /= float(group_spots.size())
		var other_edge: int = -1
		for other: Variant in edges.keys(): other_edge = edges[other]
		var edge: int = Formation.get_edge_towards(middle)
		if edge < 0 or edge == other_edge: edge = Level.Direction.DOWN if other_edge < 0 else Level.get_opposite(other_edge as Level.Direction)
		edges[group] = edge
	if edges.is_empty(): _side_edges.erase(grid_position)
	else: _side_edges[grid_position] = edges
	return edges

## Lays out the figures on [param grid_position] (but [param except]) by their [Formation]: each side gathered in
## the middle, or, facing the other side, lined up towards the edge it holds, facing the other, the leads in front (see
## [method Level.get_lead]); fallen figures keep their place
func arrange(grid_position: Vector2i, except: Character = null) -> void:
	if not _level.multiplayer.is_server() or not _level.get_placed_tile(grid_position): return
	var edges: Dictionary = get_side_edges(grid_position, except)
	var heroes: Array[Character] = []
	var monsters: Array[Character] = []
	for character: Character in _level.get_figures_on(grid_position, except):
		if character.profile.group == CharacterProfile.Groups.HEROES: heroes.append(character)
		else: monsters.append(character)
	var facing_enemies: bool = not heroes.is_empty() and not monsters.is_empty()
	var blocked: Array[Vector2] = _level.get_blocked_spots(grid_position)
	_arrange_side(grid_position, Formation.by_priority(heroes), edges, facing_enemies, blocked)
	_arrange_side(grid_position, Formation.by_priority(monsters), edges, facing_enemies, blocked)

## Lays out [param side] (in order, the lead first) on [param grid_position] by the [param edges] the sides hold;
## [param facing_enemies] if the other side stands there too, clear of the [param blocked] spots
func _arrange_side(grid_position: Vector2i, side: Array[Character], edges: Dictionary, facing_enemies: bool, blocked: Array[Vector2]) -> void:
	if side.is_empty(): return
	var group: CharacterProfile.Groups = side[0].profile.group
	var own_edge: Level.Direction = edges[group]
	var other_edge: int = -1
	for other: Variant in edges.keys(): if other != group: other_edge = edges[other]
	var spots: Array[Vector2] = Formation.get_spots(side.size(), Formation.get_axis(own_edge, other_edge), facing_enemies, blocked)
	# Fallen figures keep their place, each holding the spot nearest it, unless something stands there now (e.g. a centrepiece
	# the tile turned it onto); the others take the rest, the lead first
	var placing: Array[Character] = []
	var moving_fallen: Array[Character] = []
	for character: Character in side:
		if character.posture == Character.Posture.STANDING: placing.append(character)
		elif not Formation.is_clear(character.tile_spot, blocked): moving_fallen.append(character)
		elif not spots.is_empty(): spots.erase(Formation.get_nearest(character.tile_spot, spots))
	placing.append_array(moving_fallen)
	for index: int in mini(placing.size(), spots.size()):
		var character: Character = placing[index]
		var facing: Level.Direction = Level.get_opposite(own_edge) if facing_enemies and character.posture == Character.Posture.STANDING else character.facing
		if character.tile_spot.is_equal_approx(spots[index]) and character.facing == facing: continue
		character.place_on_grid(grid_position, spots[index], facing)

## A side new to the tile holds the edge [param character] came in over, unless the other side holds that one
## already (then the opposite one); then the tile's figures are laid out again
func on_character_entered(grid_position: Vector2i, character: Character) -> void:
	var from: Variant = _left_cells.get(character)
	_left_cells.erase(character)
	if from != null and character.visible:
		var from_cell: Vector2i = from
		var edges: Dictionary = get_side_edges(grid_position, character)
		if not edges.has(character.profile.group) and absi(from_cell.x - grid_position.x) + absi(from_cell.y - grid_position.y) == 1:
			var edge: Level.Direction = Level.get_direction(grid_position, from_cell)
			for group: Variant in edges.keys(): if edges[group] == edge: edge = Level.get_opposite(edge)
			edges[character.profile.group] = edge
			_side_edges[grid_position] = edges
	arrange(grid_position)

## The figures left behind close up once the strike that moved [param character] landed (see [method _arrange_after])
func on_character_exited(grid_position: Vector2i, character: Character) -> void:
	_left_cells[character] = grid_position
	_arrange_after(grid_position, character)

## The edges their sides hold on [param grid_position] turn with its tile by [param clockwise_turns] quarter turns
func turn_edges(grid_position: Vector2i, clockwise_turns: int) -> void:
	var edges: Dictionary = _side_edges.get(grid_position, {})
	for group: Variant in edges.keys(): edges[group] = Level.turn_direction(edges[group] as Level.Direction, clockwise_turns)

## A figure falling or getting up may hand over or take back the lead; one taken off the board makes room
func on_character_changed(character: Character) -> void:
	_arrange_after(character.grid_cell, character)

## Lays out [param grid_position] once the strike [param character] waits for landed (see [method Character.get_hold]), so no
## figure moves up before the blow that felled or pushed it shows; at once if it waits for none. Where figures stand is for the
## eye only, so the rules need not wait
func _arrange_after(grid_position: Vector2i, character: Character) -> void:
	var hold: float = character.get_hold()
	if hold <= 0.0:
		arrange(grid_position)
		return
	# A tween, not a timer: it goes with the level
	_level.create_tween().tween_interval(hold).finished.connect(arrange.bind(grid_position, null))

## One leaving the level makes room
func on_character_leaving(character: Character) -> void:
	_left_cells.erase(character)
	arrange(character.grid_cell, character)
