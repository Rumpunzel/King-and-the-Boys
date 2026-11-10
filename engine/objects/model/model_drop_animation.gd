class_name ModelDropAnimation
extends ModelAnimation

## Falls in from above, speeding up like a heavy piece, and settles with a small rebound, e.g. pillars and arches. Fades in while it
## falls, where its material has the instance uniform [code]fade[/code] (e.g. occludable.gdshader)

const FADE: StringName = &"fade"

@export var _drop_height: float = 10.0
## How far it springs back up after hitting the floor
@export var _rebound_height: float = 0.06
## Part of the fall it takes to fade in fully
@export_range(0.0, 1.0) var _fade_in_part: float = 0.6

func animate(model: Model) -> Tween:
	# At once, not on the tween's first step, so it does not show at rest for a frame
	model.position.y = _drop_height
	var tween: Tween = model.create_tween()
	var fall_duration: float = duration * 0.6
	tween.tween_property(model, "position:y", 0.0, fall_duration).from(_drop_height).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var meshes: Array[MeshInstance3D] = Model.gather_all_geometry_instances_on(model)
	if _fade_in_part > 0.0 and not meshes.is_empty():
		_set_fade(0.0, meshes)
		tween.parallel().tween_method(_set_fade.bind(meshes), 0.0, 1.0, fall_duration * _fade_in_part)
	tween.tween_property(model, "position:y", _rebound_height, duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", 0.0, duration * 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return tween

static func _set_fade(value: float, meshes: Array[MeshInstance3D]) -> void:
	for mesh_instance: MeshInstance3D in meshes:
		if is_instance_valid(mesh_instance): mesh_instance.set_instance_shader_parameter(FADE, value)
