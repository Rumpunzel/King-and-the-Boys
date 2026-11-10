@tool
@icon("uid://cpbv0myc0qfxb")
class_name Model
extends Node3D

## Blends between the model's own animations, in seconds
const BODY_BLEND: float = 0.15

@export var portrait_override: Texture
## Moves this model in menu previews (e.g. the lobby), so bodies of other sizes stay framed like a human, e.g. raises the smaller dwarf
@export var preview_offset: Vector3 = Vector3.ZERO

@export_group("Configuration")
@export var _animation_tree: AnimationTree
## Plays the model's own animations, e.g. a jump while it hops (see [ModelAnimation]); its autoplay animation is the idle it goes
## back to. Unset, the model uses its child named AnimationPlayer, if any
@export var _animation_player: AnimationPlayer

var _body_tween: Tween
## Replaces the [AnimationPlayer]'s autoplay as the idle the model goes back to, see [method set_idle_animation]
var _idle_animation: StringName

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

func _play_body_animations(model_animation: ModelAnimation, continuing: bool) -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player or not model_animation.has_body_animations(): return
	if _body_tween: _body_tween.kill()
	_body_tween = create_tween()
	var speed: float = model_animation.body_speed
	var rest: float = 0.0
	if not continuing and player.has_animation(model_animation.body_animation):
		_body_tween.tween_callback(player.play.bind(model_animation.body_animation, BODY_BLEND, speed))
		rest = player.get_animation(model_animation.body_animation).length / speed
	if player.has_animation(model_animation.body_landing):
		_body_tween.tween_interval(model_animation.duration * model_animation.body_landing_time)
		_body_tween.tween_callback(player.play.bind(model_animation.body_landing, BODY_BLEND, speed))
		rest = player.get_animation(model_animation.body_landing).length / speed
	if player.has_animation(model_animation.body_follow_up):
		_body_tween.tween_interval(maxf(rest - BODY_BLEND, 0.0))
		_body_tween.tween_callback(player.play.bind(model_animation.body_follow_up, BODY_BLEND, speed))
		rest = player.get_animation(model_animation.body_follow_up).length / speed
	_body_tween.tween_interval(maxf(rest - BODY_BLEND, 0.0))
	_body_tween.tween_callback(_play_idle)

## Plays the model's own [param animation] once, then its idle; just the idle if it has no such animation
func play_body_animation(animation: StringName) -> void:
	var player: AnimationPlayer = get_animation_player()
	if not player: return
	if _body_tween: _body_tween.kill()
	_body_tween = create_tween()
	if player.has_animation(animation):
		_body_tween.tween_callback(player.play.bind(animation, BODY_BLEND))
		_body_tween.tween_interval(maxf(player.get_animation(animation).length - BODY_BLEND, 0.0))
	_body_tween.tween_callback(_play_idle)

## Makes [param idle] (looping, e.g. sitting) the animation the model rests in, after playing [param through] once (e.g. sitting
## down); an empty [param idle] goes back to the [AnimationPlayer]'s autoplay
func set_idle_animation(idle: StringName, through: StringName = &"") -> void:
	_idle_animation = idle
	play_body_animation(through)

## The animation the model rests in, see [method set_idle_animation]
func get_idle_animation() -> StringName:
	var player: AnimationPlayer = get_animation_player()
	if not player: return &""
	return _idle_animation if player.has_animation(_idle_animation) else player.autoplay

func _play_idle() -> void:
	var player: AnimationPlayer = get_animation_player()
	var idle: StringName = get_idle_animation()
	if player and player.has_animation(idle): player.play(idle, BODY_BLEND)

func apply_material_override(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		mesh.material_override = material

func remove_material_override(material: Material) -> void:
	assert(material)
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
