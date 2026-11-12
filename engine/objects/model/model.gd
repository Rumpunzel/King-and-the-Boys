@tool
@icon("uid://cpbv0myc0qfxb")
class_name Model
extends Node3D

## Blends between the model's own animations, in seconds
const BODY_BLEND: float = 0.15
## The library on the [AnimationPlayer] holding the animation files played on this model, each added as it first plays
const BODY_LIBRARY: StringName = &"body"

@export var portrait_override: Texture

@export_group("Configuration")
@export var _animation_tree: AnimationTree
## Plays the model's own animations, e.g. a jump while it hops (see [ModelAnimation]); its autoplay animation is the idle it goes
## back to. Unset, the model uses its child named AnimationPlayer, if any
@export var _animation_player: AnimationPlayer

## What the model rests in when nothing else plays, e.g. a character's idles (see [member CharacterProfile.idle_animations]);
## without any, its [AnimationPlayer]'s autoplay
var idle_animations: BodyAnimations:
	set(new_idle_animations):
		idle_animations = new_idle_animations
		if is_inside_tree() and not _is_resting_elsewhere(): _rest()

## The material [method apply_material_override] put on every mesh, e.g. an editor ghost; models painting their meshes leave it be
var applied_material_override: Material

var _body_tween: Tween
## The editor's stand-ins for method keys (see [method _call_method_keys]), stopped along with the animations
var _method_tweens: Array[Tween] = []
## Weapons were put away for an animation that draws them (see [method _stow_before_drawing]); cleared once it does
var _draw_pending: bool = false
## Rests the model in these instead of its idles, e.g. while its player has passed, see [method rest_in]
var _resting: BodyAnimations
## Which of the rest animations plays
var _rest_index: int = -1

static func gather_all_geometry_instances_on(node: Node) -> Array[MeshInstance3D]:
	var geometry_instances: Array[MeshInstance3D] = [ ]
	for child: Node in node.get_children():
		if child is MeshInstance3D: geometry_instances.append(child)
		geometry_instances.append_array(gather_all_geometry_instances_on(child))
	return geometry_instances

func play_animation(normalized_velocity: Vector3, _is_on_floor: bool) -> void:
	if not _animation_tree: return
	var playback: AnimationNodeStateMachinePlayback = _animation_tree["parameters/playback"]
	assert(playback)
	if normalized_velocity:
		playback.travel("Walk")
		_animation_tree.set("parameters/Walk/blend_position", normalized_velocity.length_squared())
	else:
		playback.travel("Idle")

## Plays [param model_animation] on this model, with the model's own animations it names
func play_model_animation(model_animation: ModelAnimation) -> Tween:
	assert(model_animation)
	_play_body_animations(model_animation, false)
	return model_animation.animate(self)

## Plays on from where the model is, see [method ModelAnimation.continue_animation]; in the air it stays in its pose, and lands anew
func continue_model_animation(model_animation: ModelAnimation) -> Tween:
	assert(model_animation)
	_play_body_animations(model_animation, true)
	return model_animation.continue_animation(self)

## The [AnimationPlayer] playing the model's own animations, or [code]null[/code] for models without (or driven by an [AnimationTree])
func get_animation_player() -> AnimationPlayer:
	if _animation_tree and _animation_tree.active: return null
	if _animation_player: return _animation_player
	return get_node_or_null(^"AnimationPlayer") as AnimationPlayer

func _ready() -> void:
	# In the editor only models given idles rest (e.g. in Menagerie), so the scene of a bare body keeps its pose
	if not Engine.is_editor_hint() or (idle_animations and not idle_animations.get_animations().is_empty()): _rest()

func _play_body_animations(model_animation: ModelAnimation, continuing: bool) -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player or not model_animation.has_body_animations(): return
	# Redirected with nothing to land in: the animation under way (e.g. a roll) plays on
	if continuing and not model_animation.body_landing and not model_animation.body_follow_up: return
	_interrupt_body()
	# A figure about to draw its weapons (e.g. spawning, then drawing a sword) has them put away first
	if not continuing: _stow_before_drawing([model_animation.body_animation, model_animation.body_landing, model_animation.body_follow_up])
	_body_tween = create_tween()
	var blend: float = model_animation.body_blend
	var speed: float = model_animation.body_speed
	var landing_speed: float = model_animation.body_landing_speed if model_animation.body_landing_speed > 0.0 else speed
	var follow_up_speed: float = model_animation.body_follow_up_speed if model_animation.body_follow_up_speed > 0.0 else speed
	# Time since the animation started, so the landing keeps to its time however long the start waits
	var elapsed: float = 0.0
	var rest: float = 0.0
	if not continuing and model_animation.body_animation:
		var delay: float = model_animation.duration * model_animation.body_delay
		if delay > 0.0: _body_tween.tween_interval(delay)
		_body_tween.tween_callback(_play_body.bind(model_animation.body_animation, blend, speed, model_animation.body_start))
		elapsed = delay
		rest = maxf(model_animation.body_animation.length - model_animation.body_start, 0.0) / speed
	if model_animation.body_landing:
		_body_tween.tween_interval(maxf(model_animation.duration * model_animation.body_landing_time - elapsed, 0.0))
		_body_tween.tween_callback(_play_body.bind(model_animation.body_landing, blend, landing_speed, 0.0))
		rest = model_animation.body_landing.length / landing_speed
	if model_animation.body_follow_up:
		_body_tween.tween_interval(maxf(rest - blend, 0.0))
		_body_tween.tween_callback(_play_body.bind(model_animation.body_follow_up, blend, follow_up_speed, 0.0))
		rest = model_animation.body_follow_up.length / follow_up_speed
	_body_tween.tween_interval(maxf(rest - blend, 0.0))
	_body_tween.tween_callback(_rest)

## The name [param animation] plays under on the model's [AnimationPlayer]; animation files are added to [constant BODY_LIBRARY]
## as they are first played, so any file plays on any body sharing the bone names
func get_animation_name(animation: Animation) -> StringName:
	var player: AnimationPlayer = get_animation_player()
	if not player or not animation: return &""
	if not player.has_animation_library(BODY_LIBRARY): player.add_animation_library(BODY_LIBRARY, AnimationLibrary.new())
	var library: AnimationLibrary = player.get_animation_library(BODY_LIBRARY)
	var key: StringName = get_animation_key(animation)
	if not library.has_animation(key): library.add_animation(key, animation)
	return StringName("%s/%s" % [BODY_LIBRARY, key])

## A name for [param animation] in [constant BODY_LIBRARY], unique per file: copies of one animation may share a file name
static func get_animation_key(animation: Animation) -> StringName:
	if animation.resource_path.is_empty(): return StringName("animation_%d" % animation.get_instance_id())
	return StringName("%s_%x" % [animation.resource_path.get_file().get_basename().validate_node_name(), hash(animation.resource_path) & 0xffffff])

## Whether the model plays [param animation] right now
func is_playing(animation: Animation) -> bool:
	var player: AnimationPlayer = get_animation_player()
	return player != null and animation != null and player.current_animation == get_animation_name(animation)

## Plays [param animation] from [param start] seconds into it
func _play_body(animation: Animation, blend: float, speed: float, start: float) -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player or not animation: return
	var animation_name: StringName = get_animation_name(animation)
	# Playing the animation that plays already carries on to its end (and then stands still) instead of starting over, e.g. when a
	# rest set lists one animation twice to pick it more often
	var again: bool = player.current_animation == animation_name
	player.play(animation_name, blend, speed)
	if start > 0.0 or again: player.seek(start, true)
	# The editor calls no method keys (e.g. stowing a sword halfway through sheathing it); Menagerie's preview still shows them
	if Engine.is_editor_hint(): _call_method_keys(animation, speed, start)

## Whether [param animation] has a method key calling [param method], e.g. drawing weapons
static func calls_method(animation: Animation, method: StringName) -> bool:
	if not animation: return false
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD: continue
		for key: int in animation.track_get_key_count(track):
			if animation.method_track_get_name(track, key) == method: return true
	return false

func _stow_before_drawing(animations: Array[Animation]) -> void:
	if not has_method(&"stow_weapons"): return
	for animation: Animation in animations:
		if calls_method(animation, &"draw_weapons"):
			call(&"stow_weapons")
			_draw_pending = true
			return

## Stops the body animations under way; weapons put away for a draw that now never comes are drawn at once
func _interrupt_body() -> void:
	if _body_tween: _body_tween.kill()
	for tween: Tween in _method_tweens:
		if tween.is_valid(): tween.kill()
	_method_tweens.clear()
	if _draw_pending:
		_draw_pending = false
		call(&"draw_weapons")

func _call_method_keys(animation: Animation, speed: float, start: float) -> void:
	var player: AnimationPlayer = get_animation_player()
	var root: Node = player.get_node_or_null(player.root_node)
	if not root: return
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD: continue
		var target: Node = root.get_node_or_null(animation.track_get_path(track))
		if not target: continue
		for key: int in animation.track_get_key_count(track):
			var time: float = animation.track_get_key_time(track, key)
			if time < start: continue
			var method: Callable = Callable(target, animation.method_track_get_name(track, key)).bindv(animation.method_track_get_params(track, key))
			var tween: Tween = create_tween()
			tween.tween_callback(method).set_delay((time - start) / speed)
			_method_tweens.append(tween)

## Plays [param animation] once, then the model rests again; just rests without one
func play_body_animation(animation: Animation) -> void:
	var animations: Array[Animation] = []
	if animation: animations.append(animation)
	play_body_animations(animations)

## Plays [param animations] once each, one after another, then the model rests again
func play_body_animations(animations: Array[Animation]) -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player: return
	_interrupt_body()
	_body_tween = create_tween()
	_stow_before_drawing(animations)
	for animation: Animation in animations:
		_body_tween.tween_callback(_play_body.bind(animation, BODY_BLEND, 1.0, 0.0))
		_body_tween.tween_interval(maxf(animation.length - BODY_BLEND, 0.0))
	_body_tween.tween_callback(_rest)

## Rests the model in [param resting] (e.g. sitting, while its player has passed), through the exit of what it rested in and
## the entry of [param resting] (e.g. sitting down); [code]null[/code] rests it in its idles again. Without
## [param transitions] it just rests there (e.g. a model rebuilt while its player has passed)
func rest_in(resting: BodyAnimations, transitions: bool = true) -> void:
	var leaving: BodyAnimations = _resting
	_resting = resting
	var through: Array[Animation] = []
	if transitions and leaving != resting:
		if leaving and leaving.exit: through.append(leaving.exit)
		if resting and resting.entry: through.append(resting.entry)
	play_body_animations(through)

## What the model rests in: what [method rest_in] chose, else its idles; [code]null[/code] for its autoplay
func get_rest_animations() -> BodyAnimations:
	if _is_resting_elsewhere(): return _resting
	if idle_animations and not idle_animations.get_animations().is_empty(): return idle_animations
	return null

## The animation the model rests in right now, or [code]null[/code] while it rests in its autoplay
func get_rest_animation() -> Animation:
	var resting: BodyAnimations = get_rest_animations()
	if not resting: return null
	var animations: Array[Animation] = resting.get_animations()
	return animations[_rest_index] if _rest_index >= 0 and _rest_index < animations.size() else null

func _is_resting_elsewhere() -> bool:
	return _resting != null and not _resting.get_animations().is_empty()

## Comes to rest: the first of the rest animations, which play on cycle by cycle in their order
func _rest() -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player: return
	var resting: BodyAnimations = get_rest_animations()
	if not resting:
		_rest_index = -1
		if player.has_animation(player.autoplay): player.play(player.autoplay, BODY_BLEND)
		return
	_rest_index = resting.get_first(resting.get_animations().size())
	_play_rest(resting)

func _play_rest(resting: BodyAnimations) -> void:
	var animations: Array[Animation] = resting.get_animations()
	var animation: Animation = animations[_rest_index]
	_play_body(animation, BODY_BLEND, 1.0, 0.0)
	var next: int = resting.get_next(_rest_index, animations.size())
	# One to keep: a looping animation loops by itself, any other plays again each cycle
	if next < 0:
		if animation.loop_mode != Animation.LOOP_NONE: return
		next = _rest_index
	if _body_tween: _body_tween.kill()
	_body_tween = create_tween()
	_body_tween.tween_interval(maxf(animation.length - BODY_BLEND, 0.05))
	_body_tween.tween_callback(_play_next_rest.bind(resting, next))

func _play_next_rest(resting: BodyAnimations, next: int) -> void:
	# Something else came to rest in the meantime
	if resting != get_rest_animations(): return
	_rest_index = next
	_play_rest(resting)

func apply_material_override(material: Material) -> void:
	assert(material)
	applied_material_override = material
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		mesh.material_override = material

func remove_material_override(material: Material) -> void:
	assert(material)
	if applied_material_override == material: applied_material_override = null
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		if mesh.material_override == material: mesh.material_override = null

func apply_material_overlay(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		mesh.material_overlay = material

func remove_material_overlay(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		if mesh.material_override == material: mesh.material_override = null

func get_mesh_scales() -> Array[Vector3]:
	var scales: Array[Vector3] = []
	scales.assign(gather_all_geometry_instances_on(self).map(func(mesh: MeshInstance3D) -> Vector3: return mesh.scale))
	return scales

func get_max_mesh_scale() -> float:
	return get_mesh_scales().reduce(func(max_mesh_scale: float, mesh_scale: Vector3) -> float: return max(max_mesh_scale, mesh_scale.x, mesh_scale.y, mesh_scale.z), 0.0)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _animation_tree: warnings.append("Missing AnimationTree reference.")
	return warnings
