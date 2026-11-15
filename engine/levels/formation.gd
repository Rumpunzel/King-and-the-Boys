@icon("uid://bfpmyljmhdkos")
class_name Formation
extends RefCounted
## Where the figures of one side stand on a tile (see [method Level.has_room]): up to [constant MAX_PER_SIDE] each. Alone or
## among allies they gather in the middle; facing enemies, each side lines up towards the edge it holds, its lead in front,
## nose to nose with the other side's, the others just behind. Spots are offsets from the tile's center, as
## [member Character.tile_spot]; only answers questions, the level places the figures.

const MAX_PER_SIDE: int = 3
## How far the leads stand from the middle, facing each other, and the others behind them, apart from each other
const _LEAD_REACH: float = 0.3
const _BACK_REACH: float = 0.7
const _BACK_SPREAD: float = 0.45
## Allies alone on a tile, apart from each other
const _GATHER_SPREAD: float = 0.4
## How close a figure may come to what stands on the tile (a chest in the middle, a centrepiece in a corner), and how far out
## from the middle any figure stands at most
const _CLEARANCE: float = 0.5
const _MAX_REACH: float = 0.75

## @returns the way from the middle towards the side holding [param own_edge] (a [enum Level.Direction]), facing the side
## holding [param other_edge] ([code]-1[/code] for none): straight out over its edge, or, with the other side on a
## neighbouring edge, across the tile between the two
static func get_axis(own_edge: Level.Direction, other_edge: int) -> Vector2:
	var own: Vector2 = Vector2(Level.direction_to_vector(own_edge))
	if other_edge < 0 or other_edge == Level.get_opposite(own_edge): return own
	return (own - Vector2(Level.direction_to_vector(other_edge as Level.Direction))).normalized()

## @returns the spots for [param count] figures of one side, the lead's first, towards [param axis] (see [method get_axis]) if
## the side faces enemies ([param facing_enemies]), else gathered in the middle; clear of [param blocked] spots
static func get_spots(count: int, axis: Vector2, facing_enemies: bool, blocked: Array[Vector2]) -> Array[Vector2]:
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var spots: Array[Vector2] = []
	if facing_enemies:
		spots = [axis * _LEAD_REACH, axis * _BACK_REACH + across * _BACK_SPREAD, axis * _BACK_REACH - across * _BACK_SPREAD]
	else:
		match count:
			1: spots = [Vector2.ZERO]
			2: spots = [across * _GATHER_SPREAD, -across * _GATHER_SPREAD]
			_: spots = [-axis * _LEAD_REACH, axis * _LEAD_REACH + across * _BACK_SPREAD, axis * _LEAD_REACH - across * _BACK_SPREAD]
	spots.resize(mini(count, spots.size()))
	var clear: Array[Vector2] = []
	for spot: Vector2 in spots: clear.append(_keep_clear(spot, axis, blocked))
	return clear

## @returns [param spot] moved away from every [param blocked] spot it comes too close to (along [param axis] from one right on
## it), and back onto the tile
static func _keep_clear(spot: Vector2, axis: Vector2, blocked: Array[Vector2]) -> Vector2:
	var moved: Vector2 = spot
	for blocked_spot: Vector2 in blocked:
		var away: Vector2 = moved - blocked_spot
		if away.length() >= _CLEARANCE: continue
		moved = blocked_spot + (away.normalized() if away.length() > 0.01 else axis) * _CLEARANCE
	return moved.clamp(-Vector2.ONE * _MAX_REACH, Vector2.ONE * _MAX_REACH)

## @returns the spot of [param spots] nearest [param spot]
static func get_nearest(spot: Vector2, spots: Array[Vector2]) -> Vector2:
	var nearest: Vector2 = spots.front()
	for other: Vector2 in spots:
		if other.distance_squared_to(spot) < nearest.distance_squared_to(spot): nearest = other
	return nearest

## @returns the edge (a [enum Level.Direction]) nearest [param spot], [code]-1[/code] for one in the middle
static func get_edge_towards(spot: Vector2) -> int:
	if spot.length() < 0.15: return -1
	if absf(spot.x) > absf(spot.y): return Level.Direction.RIGHT if spot.x > 0.0 else Level.Direction.LEFT
	return Level.Direction.DOWN if spot.y > 0.0 else Level.Direction.UP
