class_name TileLift
extends Node
## Every peer: shows a [Structure]'s replicated lift (see [member Structure.lifted_by]) on its model. The model rises with
## the figures on the tile, wobbles a little while it hangs in the air, spins to [member Structure.lift_turns] and drops back
## with a bounce when set down. The structure itself turns at once when [member Structure.clockwise_turns] changes, so
## rules and collision stay exact; only its model catches up, and figures ride along until it landed.

## Emitted when the model is back on the board, at rest
signal landed

## Used where the level has none
static var _default_animation: TileLiftAnimation = TileLiftAnimation.new()

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
	if _has_nothing_to_show(): return
	set_process(true)
	if _structure.is_lifted() and _carried.is_empty() and not _is_rising(): _rise()
	elif not _structure.is_lifted() and _height > 0.0: _drop()
	_spin_to(_structure.lift_turns if _structure.is_lifted() else 0)

## The structure turned at once: the model keeps its look and catches up
func on_turned(previous_clockwise_turns: int) -> void:
	if _has_nothing_to_show(): return
	set_process(true)
	_turns -= posmod(_structure.clockwise_turns - previous_clockwise_turns, Level.Direction.size())
	_spin_to(_structure.lift_turns if _structure.is_lifted() else 0)
	# Not a frame facing the new way before the model is held back
	_show()

func _process(delta: float) -> void:
	_time += delta
	_show()
	if _is_at_rest(): _land()

## Puts the model where the lift has it now
func _show() -> void:
	var model: Model = _structure.model
	if not model: return
	var animation: TileLiftAnimation = _get_animation()
	var tip: float = deg_to_rad(animation.wobble_degrees) * _wobble
	var wobble_speed: float = animation.wobble_speed
	model.position.y = _height
	model.rotation = Vector3(tip * sin(_time * wobble_speed), -_turns * PI * 0.5, tip * sin(_time * wobble_speed * 1.37 + 1.0))

## Without a model (e.g. in tests) nothing moves: the tile lands at once whenever it lies on the board
func _has_nothing_to_show() -> bool:
	if _structure.model: return false
	if not _structure.is_lifted(): _land()
	return true

func _get_animation() -> TileLiftAnimation:
	var level: Level = _structure.level
	return level.tile_lift_animation if level and level.tile_lift_animation else _default_animation

func _rise() -> void:
	var animation: TileLiftAnimation = _get_animation()
	_carry_figures()
	_puff(animation.rise_particles)
	if _height_tween: _height_tween.kill()
	_height_tween = create_tween().set_parallel()
	_height_tween.tween_property(self, "_height", animation.height, animation.rise_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(self, "_wobble", 1.0, animation.rise_duration * 2.0)

func _drop() -> void:
	var animation: TileLiftAnimation = _get_animation()
	if _height_tween: _height_tween.kill()
	_height_tween = create_tween().set_parallel()
	# Lands once it faces its new way, so figures step off where their spots are
	_height_tween.tween_property(self, "_height", 0.0, animation.drop_duration).set_delay(animation.spin_duration * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(self, "_wobble", 0.0, animation.drop_duration * 0.5)
	if animation.landing_particles:
		_height_tween.tween_callback(_puff.bind(animation.landing_particles)).set_delay(animation.spin_duration * 0.5 + animation.drop_duration * animation.landing_time)

## Spins the shorter way to [param target_turns], or the same turn a full circle away. A spin under way stops first, also when
## the model is already there: it may aim at turns from before the structure turned (see [method on_turned])
func _spin_to(target_turns: int) -> void:
	if _spin_tween: _spin_tween.kill()
	var nearest_target: float = target_turns + Level.Direction.size() * roundf((_turns - target_turns) / Level.Direction.size())
	if is_equal_approx(nearest_target, _turns): return
	_spin_tween = create_tween()
	_spin_tween.tween_property(self, "_turns", nearest_target, _get_animation().spin_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Plays [param particles] once on the floor under the tile (on the structure, which stays down while its model rises), then
## frees them
func _puff(particles: PackedScene) -> void:
	if not particles or not _structure.is_inside_tree(): return
	var puff: Node3D = particles.instantiate()
	_structure.add_child(puff)
	var longest: float = 0.0
	var emitters: Array[Node] = puff.find_children("*", "GPUParticles3D", true, false)
	if puff is GPUParticles3D: emitters.append(puff)
	for emitter: GPUParticles3D in emitters:
		emitter.restart()
		longest = maxf(longest, emitter.lifetime / maxf(emitter.speed_scale, 0.01))
	get_tree().create_timer(longest + 0.5).timeout.connect(puff.queue_free)

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
