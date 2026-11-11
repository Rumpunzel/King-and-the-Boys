@icon("uid://ojcxbpp8xolq")
class_name LevelDebug
extends Node

## Debug drawings over the level, redrawn every frame while shown: an outline around every room (in its room type's colour, with
## its size and its centrepiece corner), each tile's connection restrictions (see [method Structure.draw_debug]) and the tiles' labels
## with their name and grid position.
## The [constant ACTION] toggles them (F3); only on this peer, nothing is synced

const ACTION: StringName = &"toggle_debug_drawings"
## How far outlines stay inside a room's edge, as a fraction of a tile, so neighbouring rooms' outlines keep apart
const OUTLINE_INSET: float = 0.06
## How high the drawings float above the floor
const HEIGHT: float = 0.06

@export var shown: bool = false:
	set(new_shown):
		shown = new_shown
		# The tiles' labels too, so either every debug mark shows or none
		Structure.debug_labels_shown = shown
		if is_inside_tree(): get_tree().call_group(Structure.GROUP, &"show_debug_label", shown)

@export_group("Configuration")
@export var _level: Level

func _ready() -> void:
	# The labels' state outlives a level (e.g. after leaving a game with the drawings shown)
	shown = shown

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION): return
	shown = not shown
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not shown or not _level: return
	for room: Array[Vector2i] in _level.get_rooms(): _draw_room(room)
	for tile: Structure in _level.get_placed_tiles():
		if tile.shown_status == Structure.Status.REVEALED: tile.draw_debug()

## The room's outline: every edge of its cells that does not lead to another of its cells, a little inside
func _draw_room(cells: Array[Vector2i]) -> void:
	var tile: Structure = _level.get_placed_tile(cells[0])
	# Lightened, so dark room colours still show on the floor
	var color: Color = (tile.profile.room_type.color if tile.profile.room_type else Color.WHEAT).lightened(0.55)
	var half: float = _level.grid_size * (0.5 - OUTLINE_INSET)
	for cell: Vector2i in cells:
		var center: Vector3 = _level.grid_to_world_position(cell) + Vector3.UP * HEIGHT
		for direction: Level.Direction in Level.Direction.values():
			var outward: Vector2i = Level.direction_to_vector(direction)
			if cells.has(cell + outward): continue
			var along: Vector2i = Vector2i(-outward.y, outward.x)
			var normal: Vector3 = Vector3(outward.x, 0.0, outward.y)
			var middle: Vector3 = center + normal * half
			var start: float = _reach(cells, cell, outward, -along)
			var end: float = _reach(cells, cell, outward, along)
			DebugDraw3D.draw_line(middle - Vector3(along.x, 0.0, along.y) * start, middle + Vector3(along.x, 0.0, along.y) * end, color)
	var label: String = "%s (%d)" % [tile.profile.room_type.name if tile.profile.room_type else "Room", cells.size()]
	var centre: Vector3 = Vector3.ZERO
	for cell: Vector2i in cells: centre += _level.grid_to_world_position(cell)
	DebugDraw3D.draw_text(centre / cells.size() + Vector3.UP * 0.4, label, 48, color)
	var corner: Variant = Level.get_centrepiece_corner(cells)
	if corner != null: DebugDraw3D.draw_sphere(_level.get_corner_world_position(corner as Vector2i) + Vector3.UP * HEIGHT, 0.2, color)

## How far an outline edge of [param cell] facing [param outward] reaches towards [param side]: to the inset at an outer corner, on to
## the next cell along a straight edge, and a little past it at an inner corner, so the outline closes
func _reach(cells: Array[Vector2i], cell: Vector2i, outward: Vector2i, side: Vector2i) -> float:
	if not cells.has(cell + side): return _level.grid_size * (0.5 - OUTLINE_INSET)
	if cells.has(cell + side + outward): return _level.grid_size * (0.5 + OUTLINE_INSET)
	return _level.grid_size * 0.5
