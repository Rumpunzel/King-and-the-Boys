@tool
extends Node

## Renders thumbnails of a body part's meshes as they look on a plain body of their scene, framed on its head, from the front and a
## little to the side. One per frame; cached by scene, part and mesh

const SIZE: Vector2i = Vector2i(112, 112)
## How much the view shows, in metres: the head with some hair around it
const VIEW: float = 0.5

## {key: [String] -> [Texture2D]}
static var _cache: Dictionary[String, Texture2D] = {}

var _queue: Array[Dictionary] = []
var _is_rendering: bool = false
var _viewport: SubViewport
var _camera: Camera3D
var _models: Dictionary[String, ModularModel] = {}

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	# Opaque: the skin's texture carries no alpha, so on a transparent background it would vanish
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.17, 0.18, 0.21)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	_viewport.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 30, 0)
	_viewport.add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_viewport.add_child(_camera)

static func get_key(scene: PackedScene, part: int, mesh_path: String) -> String:
	return "%s|%d|%s" % [scene.resource_path, part, mesh_path]

## Calls [param callback] with the thumbnail of [param part] showing [param mesh_path] (none if empty) on [param scene]'s body
func request(scene: PackedScene, part: int, mesh_path: String, callback: Callable) -> void:
	var key: String = get_key(scene, part, mesh_path)
	if _cache.has(key):
		callback.call(_cache[key])
		return
	_queue.append({"scene": scene, "part": part, "mesh_path": mesh_path, "callback": callback})
	# One queue at a time: renders share the one viewport
	if _is_rendering: return
	_is_rendering = true
	_render_queue.call_deferred()

## Renders on where it stopped when it left the tree (e.g. as the inspector rebuilt)
func _enter_tree() -> void:
	if not _queue.is_empty() and not _is_rendering and _viewport:
		_is_rendering = true
		_render_queue.call_deferred()

func _render_queue() -> void:
	if not is_inside_tree():
		_stop_rendering()
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The viewport draws its first frames before the camera and skeleton settle
	for warm_up: int in 3: await RenderingServer.frame_post_draw
	if not is_inside_tree():
		_stop_rendering()
		return
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var scene: PackedScene = job["scene"]
		var part: int = job["part"]
		var mesh_path: String = job["mesh_path"]
		var callback: Callable = job["callback"]
		var key: String = get_key(scene, part, mesh_path)
		if not _cache.has(key):
			var is_new_body: bool = not _models.has(scene.resource_path)
			var model: ModularModel = _show(scene, part, mesh_path)
			# Let bone attachments follow their bones before framing
			await get_tree().process_frame
			if not is_inside_tree():
				_stop_rendering(job)
				return
			_frame(model)
			# The first frames may still show the last thumbnail; a new body takes a few to settle, then is framed again
			for drawn: int in 6 if is_new_body else 2: await RenderingServer.frame_post_draw
			if is_new_body:
				_frame(model)
				for drawn: int in 2: await RenderingServer.frame_post_draw
			if not is_inside_tree():
				_stop_rendering(job)
				return
			_cache[key] = ImageTexture.create_from_image(_viewport.get_texture().get_image())
		if callback.is_valid(): callback.call(_cache[key])
	_stop_rendering()

## Stops rendering until requested again or back in the tree; [param unfinished] is rendered first then
func _stop_rendering(unfinished: Dictionary = {}) -> void:
	if not unfinished.is_empty(): _queue.push_front(unfinished)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_is_rendering = false

## Shows [param scene]'s body plain, with [param part] showing [param mesh_path]; other bodies are hidden
func _show(scene: PackedScene, part: int, mesh_path: String) -> ModularModel:
	if not _models.has(scene.resource_path):
		var instance: ModularModel = scene.instantiate() as ModularModel
		_viewport.add_child(instance)
		# Skinned meshes keep their bounds in their own space: close up, the view would cull them although they are in sight
		for mesh_instance: MeshInstance3D in Model.gather_all_geometry_instances_on(instance): mesh_instance.extra_cull_margin = 16384.0
		_models[scene.resource_path] = instance
	for path: String in _models: _models[path].visible = path == scene.resource_path
	var model: ModularModel = _models[scene.resource_path]
	model.reset()
	model.get_part(part).apply_mesh(load(mesh_path) as ArrayMesh if not mesh_path.is_empty() else null)
	return model

## Every body part sits on the head (hair, beards, faces); skinned meshes keep their bounds in their own space, so the view is the head's
func _frame(model: ModularModel) -> void:
	_camera.size = VIEW * model.scale.y
	var target: Vector3 = _get_head_position(model)
	_camera.look_at_from_position(target + Vector3(sin(deg_to_rad(25.0)), 0.15, cos(deg_to_rad(25.0))) * 3.0, target)

## A little above the head bone, for parts showing none
static func _get_head_position(model: ModularModel) -> Vector3:
	var skeleton: Skeleton3D = model.find_child("GeneralSkeleton") as Skeleton3D
	var bone: int = skeleton.find_bone("Head") if skeleton else -1
	if bone < 0: return model.global_position + Vector3.UP * 1.6
	return skeleton.global_transform * skeleton.get_bone_global_rest(bone).origin + Vector3.UP * 0.08
