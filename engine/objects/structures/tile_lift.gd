class_name TileLift
extends Node
## Every peer: shows a [Structure]'s replicated lift (see [member Structure.lifted_by]) on its model. The model rises with
## the figures on the tile, wobbles a little while it hangs in the air, spins to [member Structure.lift_turns] and drops back
## with a bounce when set down. The structure itself turns at once when [member Structure.clockwise_turns] changes, so
## rules and collision stay exact; only its model catches up, and figures ride along until it landed.

## Emitted when the model is back on the board, at rest
signal landed

const _HEIGHT: float = 0.6
const _RISE_DURATION: float = 0.4
const _SPIN_DURATION: float = 0.35
const _DROP_DURATION: float = 0.5
## Most the hanging tile tips over, in degrees
const _WOBBLE_DEGREES: float = 2.5
## Radians per second of the slower of the two wobble axes
const _WOBBLE_SPEED: float = 2.3

var _structure: Structure
# Model offsets: height, turn in quarter turns clockwise on top of the structure's, wobble strength (0 to 1)
var _height: float = 0.0
var _turns: float = 0.0
var _wobble: float = 0.0
var _time: float = 0.0
var _height_tween: Tween
var _spin_tween: Tween
var _carried: Array[Character] = []

func _init(structure: Structure) -> void:
	_structure = structure
	name = "TileLift"

func _ready() -> void:
	set_process(false)

## @returns [code]true[/code] while the model is not at rest on the board
func is_busy() -> bool:
	return is_processing()

## Follows the structure's lift: rises and carries the figures on it, spins to the lifted turns, or drops when set down
func update() -> void:
	set_process(true)
	if _structure.is_lifted() and _carried.is_empty() and not _is_rising(): _rise()
	elif not _structure.is_lifted() and _height > 0.0: _drop()
	_spin_to(_structure.lift_turns if _structure.is_lifted() else 0)

## The structure turned at once: the model keeps its look and catches up
func on_turned(previous_clockwise_turns: int) -> void:
	set_process(true)
	_turns -= posmod(_structure.clockwise_turns - previous_clockwise_turns, Level.Direction.size())
	_spin_to(_structure.lift_turns if _structure.is_lifted() else 0)

func _process(delta: float) -> void:
	var model: Model = _structure.model
	if not model: return
	_time += delta
	var tip: float = deg_to_rad(_WOBBLE_DEGREES) * _wobble
	model.position.y = _height
	model.rotation = Vector3(tip * sin(_time * _WOBBLE_SPEED), -_turns * PI * 0.5, tip * sin(_time * _WOBBLE_SPEED * 1.37 + 1.0))
	if _is_at_rest(): _land()

func _rise() -> void:
	_carry_figures()
	if _height_tween: _height_tween.kill()
	_height_tween = create_tween().set_parallel()
	_height_tween.tween_property(self, "_height", _HEIGHT, _RISE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(self, "_wobble", 1.0, _RISE_DURATION * 2.0)

func _drop() -> void:
	if _height_tween: _height_tween.kill()
	_height_tween = create_tween().set_parallel()
	# Lands once it faces its new way, so figures step off where their spots are
	_height_tween.tween_property(self, "_height", 0.0, _DROP_DURATION).set_delay(_SPIN_DURATION * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(self, "_wobble", 0.0, _DROP_DURATION * 0.5)

## Spins the shorter way to [param target_turns], or the same turn a full circle away
func _spin_to(target_turns: int) -> void:
	var nearest_target: float = target_turns + Level.Direction.size() * roundf((_turns - target_turns) / Level.Direction.size())
	if is_equal_approx(nearest_target, _turns): return
	if _spin_tween: _spin_tween.kill()
	_spin_tween = create_tween()
	_spin_tween.tween_property(self, "_turns", nearest_target, _SPIN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _carry_figures() -> void:
	var model: Model = _structure.model
	if not model: return
	var grid_position: Vector2i = _structure.get_grid_position()
	for character: Character in get_tree().get_nodes_in_group(Character.GROUP):
		if not character.visible or character.grid_cell != grid_position: continue
		character.carry_on(model)
		_carried.append(character)

func _is_rising() -> bool:
	return _height_tween != null and _height_tween.is_running() and _structure.is_lifted()

func _is_at_rest() -> bool:
	if _structure.is_lifted(): return false
	for tween: Tween in [_height_tween, _spin_tween]: if tween and tween.is_running(): return false
	return true

func _land() -> void:
	set_process(false)
	_height = 0.0
	_wobble = 0.0
	_turns = 0.0
	var model: Model = _structure.model
	if model:
		model.position.y = 0.0
		model.rotation = Vector3.ZERO
	for character: Character in _carried: if is_instance_valid(character): character.carry_on(null)
	_carried.clear()
	landed.emit()
