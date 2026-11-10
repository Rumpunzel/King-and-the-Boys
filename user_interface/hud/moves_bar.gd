@tool
class_name MovesBar
extends HBoxContainer
## A character's moves this turn as a row of pills, one per move, in the character's colour: moves used for good in full
## colour, moves that could still be undone paler, moves left empty. Pills fill up and drain with a short tween.

enum MoveState { LEFT, UNDOABLE, USED }

@export var character: Character:
	set(new_character):
		if is_instance_valid(character):
			character.movement_points_changed.disconnect(_on_moves_changed)
			character.undo_steps_changed.disconnect(_on_moves_changed)
		character = new_character
		if not character or Engine.is_editor_hint(): return
		character.movement_points_changed.connect(_on_moves_changed)
		character.undo_steps_changed.connect(_on_moves_changed)
		_update(false)

## Opacity of moves that could still be undone
@export_range(0.0, 1.0) var undoable_alpha: float = 0.4
## How long a pill takes to fill up, drain or change its colour
@export_range(0.0, 1.0) var fill_duration: float = 0.25
@export var pill_height: float = 10.0:
	set(new_pill_height):
		pill_height = new_pill_height
		for pill: ProgressBar in _pills: pill.custom_minimum_size.y = pill_height
## The empty pill
@export var pill_background: StyleBox
## The filling, recoloured per pill
@export var pill_fill: StyleBoxFlat

var _pills: Array[ProgressBar] = []
var _states: Array[MoveState] = []
var _tweens: Array[Tween] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		# A preview: two moves used, one undoable, one left
		_build(4)
		for move: int in 4: _show(move, [MoveState.USED, MoveState.USED, MoveState.UNDOABLE, MoveState.LEFT][move] as MoveState, Color.CORNFLOWER_BLUE, false)
		return
	if character: _update(false)

func _update(animate: bool = true) -> void:
	if not is_node_ready() or not is_instance_valid(character): return
	var speed: int = character.profile.speed
	if _pills.size() != speed:
		_build(speed)
		animate = false
	var moves_used: int = speed - maxi(character.movement_points, 0)
	var moves_kept: int = moves_used - character.undo_steps
	for move: int in speed:
		var state: MoveState = MoveState.LEFT
		if move < moves_kept: state = MoveState.USED
		elif move < moves_used: state = MoveState.UNDOABLE
		_show(move, state, character.profile.color, animate)

## One empty pill per move
func _build(moves: int) -> void:
	for pill: ProgressBar in _pills: pill.queue_free()
	_pills.clear()
	_states.clear()
	_tweens.clear()
	for move: int in moves:
		var pill: ProgressBar = ProgressBar.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.custom_minimum_size.y = pill_height
		pill.max_value = 1.0
		pill.step = 0.0
		pill.show_percentage = false
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if pill_background: pill.add_theme_stylebox_override(&"background", pill_background)
		var fill: StyleBoxFlat = pill_fill.duplicate() if pill_fill else StyleBoxFlat.new()
		fill.bg_color = Color.TRANSPARENT
		pill.add_theme_stylebox_override(&"fill", fill)
		add_child(pill)
		_pills.append(pill)
		_states.append(MoveState.LEFT)
		_tweens.append(null)

## Fills or drains a move's pill and gives it the state's colour
func _show(move: int, state: MoveState, color: Color, animate: bool) -> void:
	var pill: ProgressBar = _pills[move]
	var fill: StyleBoxFlat = pill.get_theme_stylebox(&"fill") as StyleBoxFlat
	var target_value: float = 0.0 if state == MoveState.LEFT else 1.0
	# A draining pill keeps its colour until it is empty
	var target_color: Color = fill.bg_color
	if state == MoveState.USED: target_color = color
	elif state == MoveState.UNDOABLE: target_color = Color(color, color.a * undoable_alpha)
	if state == _states[move] and is_equal_approx(pill.value, target_value) and fill.bg_color == target_color: return
	_states[move] = state
	if _tweens[move]: _tweens[move].kill()
	if not animate or fill_duration <= 0.0:
		pill.value = target_value
		fill.bg_color = target_color
		return
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pill, ^"value", target_value, fill_duration)
	tween.tween_property(fill, ^"bg_color", target_color, fill_duration)
	_tweens[move] = tween

func _on_moves_changed(_value: int) -> void:
	_update()
