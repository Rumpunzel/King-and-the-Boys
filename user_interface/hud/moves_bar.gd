@tool
class_name MovesBar
extends MarginContainer
## A character's moves this turn as one bar in the character's colour, filling up as moves are used: moves used for
## good in full colour, moves that could still be undone paler, moves left empty. Full once every move is used.
## Two stacked progress bars, the upper one without background, and ticks on top dividing the bar into one segment per move.

@export var character: Character:
	set(new_character):
		if is_instance_valid(character):
			character.movement_points_changed.disconnect(_on_moves_changed)
			character.undo_steps_changed.disconnect(_on_moves_changed)
		character = new_character
		if not character or Engine.is_editor_hint(): return
		character.movement_points_changed.connect(_on_moves_changed)
		character.undo_steps_changed.connect(_on_moves_changed)
		_update()

## Opacity of moves that could still be undone
@export_range(0.0, 1.0) var undoable_alpha: float = 0.4
## The ticks between two moves
@export var tick_color: Color = Color(0.0, 0.0, 0.0, 0.6):
	set(new_tick_color):
		tick_color = new_tick_color
		if _ticks: _ticks.queue_redraw()
@export_range(0.0, 8.0) var tick_width: float = 2.0:
	set(new_tick_width):
		tick_width = new_tick_width
		if _ticks: _ticks.queue_redraw()
## How far ticks reach above and below the bar, so they stay visible on a thin one
@export_range(0.0, 16.0) var tick_overhang: float = 3.0:
	set(new_tick_overhang):
		tick_overhang = new_tick_overhang
		if _ticks: _ticks.queue_redraw()

@export_group("Configuration")
@export var _used_bar: ProgressBar
@export var _undoable_bar: ProgressBar
## Drawn on by [method _draw_ticks]
@export var _ticks: Control

var _color: Color = Color.TRANSPARENT

func _ready() -> void:
	if _ticks: _ticks.draw.connect(_draw_ticks)
	if character: _update()

func _update() -> void:
	if not is_node_ready() or not is_instance_valid(character): return
	var speed: int = character.profile.speed
	var moves_used: int = speed - maxi(character.movement_points, 0)
	for bar: ProgressBar in [_used_bar, _undoable_bar]: bar.max_value = speed
	_used_bar.value = moves_used - character.undo_steps
	_undoable_bar.value = moves_used
	_ticks.queue_redraw()
	if character.profile.color != _color:
		_color = character.profile.color
		_set_fill_color(_used_bar, _color)
		_set_fill_color(_undoable_bar, Color(_color, _color.a * undoable_alpha))

## A line between every two moves, across the bar and a little beyond
func _draw_ticks() -> void:
	var moves: int = int(_used_bar.max_value)
	var bar: Rect2 = Rect2(_used_bar.position - _ticks.position, _used_bar.size)
	for move: int in range(1, moves):
		var x: float = bar.position.x + bar.size.x * move / moves
		_ticks.draw_line(Vector2(x, bar.position.y - tick_overhang), Vector2(x, bar.end.y + tick_overhang), tick_color, tick_width)

## Keeps the theme's fill style, only in another colour
static func _set_fill_color(bar: ProgressBar, color: Color) -> void:
	var fill: StyleBox = bar.get_theme_stylebox(&"fill")
	var colored_fill: StyleBoxFlat = fill.duplicate() if fill is StyleBoxFlat else StyleBoxFlat.new()
	colored_fill.bg_color = color
	bar.add_theme_stylebox_override(&"fill", colored_fill)

func _on_moves_changed(_value: int) -> void:
	_update()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _used_bar: warnings.append("Missing used moves ProgressBar reference.")
	if not _undoable_bar: warnings.append("Missing undoable ProgressBar reference.")
	if not _ticks: warnings.append("Missing ticks Control reference.")
	return warnings
