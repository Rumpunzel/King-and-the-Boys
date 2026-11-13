extends Node
## Measures rendering on a fully explored, fully revealed dungeon with the real assets: draw calls, objects, primitives and
## CPU/GPU frame times, from a player's view and from above the whole map, with lights, shadows, particles, props, fog and
## the tilt-shift switched off one at a time to see what each costs. Run windowed (rendering is off headless):
## [code]<godot> --path . res://tools/benchmarks/render_benchmark.tscn[/code]. Prints a table and quits.

const LEVEL: String = "res://data/levels/level.tscn"
const GENERATION_SEED: int = 7
## Frames to settle after a change (shaders compile, tweens end), then frames to average over
const SETTLE_FRAMES: int = 90
const SAMPLE_FRAMES: int = 240
## Seconds for every tile's reveal and its props' drops to finish
const DRESSING_SECONDS: float = 20.0
## The player's camera, see player_controller.tscn
const PLAYER_CAMERA_OFFSET: Vector3 = Vector3(0.0, 20.0, 16.0)
const PLAYER_CAMERA_FOV: float = 37.8493

var _level: Level
var _camera: Camera3D
var _rows: PackedStringArray = []

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_level = (load(LEVEL) as PackedScene).instantiate()
	_level.generation_random.seed = GENERATION_SEED
	add_child(_level)
	_level.build_level()
	_explore_everything()
	_reveal_everything()
	_camera = Camera3D.new()
	_camera.fov = PLAYER_CAMERA_FOV
	add_child(_camera)
	_camera.make_current()
	print("Dressing %d tiles..." % _level.get_placed_tiles().size())
	await get_tree().create_timer(DRESSING_SECONDS).timeout
	_print_scene_counts()
	await _measure_views()
	print("\n".join(_rows))
	get_tree().quit()

## Builds on from every tile until the dungeon fills its extents
func _explore_everything() -> void:
	var tile_count: int = -1
	while tile_count != _level.get_placed_tiles().size():
		tile_count = _level.get_placed_tiles().size()
		for tile: Structure in _level.get_placed_tiles():
			if tile.get_connections().is_empty(): continue
			_level.call("_build_dungeon_from", tile.get_grid_position())

func _reveal_everything() -> void:
	for tile: Structure in _level.get_placed_tiles(): tile.reveal()

func _measure_views() -> void:
	var start: Vector3 = (get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position
	var extents: Vector2 = Vector2(_level.grid_extents) * _level.grid_size
	var views: Dictionary[String, Transform3D] = {
		"player at start": _looking_at(start + PLAYER_CAMERA_OFFSET, start),
		"whole map": _looking_at(Vector3(0.0, maxf(extents.x, extents.y) * 2.6, maxf(extents.x, extents.y) * 1.2), Vector3.ZERO),
	}
	_rows.append("| View | Switched off | Draw calls | Objects | Primitives | CPU ms | GPU ms | FPS |")
	_rows.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
	for view: String in views:
		_camera.global_transform = views[view]
		for variant: String in ["nothing", "shadows", "lights", "particles", "props", "fog", "tilt-shift", "all of these"]:
			var restore: Callable = _switch_off(variant)
			_rows.append(await _measure(view, variant))
			restore.call()

static func _looking_at(from: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)

## @returns what puts it back
func _switch_off(variant: String) -> Callable:
	var undo: Array[Callable] = []
	if variant in ["shadows", "all of these"]:
		for light: Light3D in _find(_level, "Light3D"):
			if not light.shadow_enabled: continue
			light.shadow_enabled = false
			undo.append(light.set.bind(&"shadow_enabled", true))
	if variant in ["lights", "all of these"]:
		for light: Light3D in _find(_level, "Light3D"):
			if light is DirectionalLight3D or not light.visible: continue
			light.visible = false
			undo.append(light.set.bind(&"visible", true))
	if variant in ["particles", "all of these"]:
		for particles: Node3D in _find(_level, "GPUParticles3D") + _find(_level, "CPUParticles3D"):
			if not particles.visible: continue
			particles.visible = false
			undo.append(particles.set.bind(&"visible", true))
	if variant in ["props", "all of these"]:
		for tile: Structure in _level.get_placed_tiles():
			var decorations: Node3D = tile.model.get_node_or_null(NodePath(TileDecorations.NODE_NAME)) if tile.model else null
			if not decorations or not decorations.visible: continue
			decorations.visible = false
			undo.append(decorations.set.bind(&"visible", true))
	var environment: Environment = _get_environment()
	if environment and variant in ["fog", "all of these"]:
		var fog: bool = environment.fog_enabled
		var volumetric_fog: bool = environment.volumetric_fog_enabled
		environment.fog_enabled = false
		environment.volumetric_fog_enabled = false
		undo.append(environment.set.bind(&"fog_enabled", fog))
		undo.append(environment.set.bind(&"volumetric_fog_enabled", volumetric_fog))
	var world_environment: WorldEnvironment = _get_world_environment()
	if world_environment and world_environment.compositor and variant in ["tilt-shift", "all of these"]:
		var compositor: Compositor = world_environment.compositor
		world_environment.compositor = null
		undo.append(world_environment.set.bind(&"compositor", compositor))
	return func() -> void:
		for step: Callable in undo: step.call()

func _measure(view: String, variant: String) -> String:
	for _frame: int in SETTLE_FRAMES: await get_tree().process_frame
	var viewport: RID = get_viewport().get_viewport_rid()
	var draw_calls: float = 0.0
	var objects: float = 0.0
	var primitives: float = 0.0
	var cpu: float = 0.0
	var gpu: float = 0.0
	var started: int = Time.get_ticks_usec()
	for _frame: int in SAMPLE_FRAMES:
		await get_tree().process_frame
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	var fps: float = SAMPLE_FRAMES / ((Time.get_ticks_usec() - started) / 1000000.0)
	var row: String = "| %s | %s | %d | %d | %d | %.2f | %.2f | %.0f |" % [view, variant, draw_calls / SAMPLE_FRAMES, objects / SAMPLE_FRAMES,
		primitives / SAMPLE_FRAMES, cpu / SAMPLE_FRAMES, gpu / SAMPLE_FRAMES, fps]
	print(row)
	return row

func _print_scene_counts() -> void:
	var meshes: Array[Node] = _find(_level, "MeshInstance3D")
	var unique_meshes: Dictionary[Mesh, bool] = {}
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh: unique_meshes[mesh_instance.mesh] = true
	var lights: Array[Node] = _find(_level, "Light3D")
	var shadowed: int = lights.filter(func(light: Light3D) -> bool: return light.shadow_enabled).size()
	var particles: int = _find(_level, "GPUParticles3D").size() + _find(_level, "CPUParticles3D").size()
	print("%s (%s), window %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(), get_viewport().get_visible_rect().size])
	print("Tiles %d, mesh instances %d (%d distinct meshes), lights %d (%d with shadows), particle systems %d, nodes %d" % [
		_level.get_placed_tiles().size(), meshes.size(), unique_meshes.size(), lights.size(), shadowed, particles,
		_count_nodes(_level)])

func _get_world_environment() -> WorldEnvironment:
	var found: Array[Node] = _find(_level, "WorldEnvironment")
	return found[0] as WorldEnvironment if not found.is_empty() else null

func _get_environment() -> Environment:
	var world_environment: WorldEnvironment = _get_world_environment()
	return world_environment.environment if world_environment else null

static func _find(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)

static func _count_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children(): count += _count_nodes(child)
	return count
