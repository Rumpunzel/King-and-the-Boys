extends Node
## Measures rendering on a fully explored, fully revealed dungeon with the real assets: draw calls, objects, primitives and
## CPU/GPU frame times, from a player's view and from straight above the whole map, with lights, shadows, particles, props,
## fog and the tilt-shift switched off one at a time to see what each costs. Run windowed (rendering is off headless):
## [code]<godot> --path . res://tools/benchmarks/render_benchmark.tscn[/code]. Prints a table and quits.

## data/levels/level.tscn, the real dungeon
const LEVEL: String = "uid://bmwhs3lwb74ue"
## engine/player/player_controller.tscn: where the player's camera and light come from
const PLAYER_CONTROLLER: String = "uid://ckcrpkujohkql"
## Seeds the dungeon and every other roll (model variations, flicker), so runs build the same scene and can be compared
const GENERATION_SEED: int = 7
## Frames to settle after a change (shaders compile, tweens end), then frames to average over
const SETTLE_FRAMES: int = 90
const SAMPLE_FRAMES: int = 240
## Seconds for every tile's reveal and its props' drops to finish
const DRESSING_SECONDS: float = 20.0
const NOT_FOUND: String = " (not found)"

var _level: Level
var _camera: Camera3D
## The player's camera: its offset from the figure and its field of view
var _player_camera_offset: Vector3
var _player_camera_fov: float
var _rows: PackedStringArray = []

func _ready() -> void:
	seed(GENERATION_SEED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# The menus' black placeholder would cover the view and cost a full-screen pass the game does not draw
	Panorama.clear_background()
	_level = (load(LEVEL) as PackedScene).instantiate()
	_level.generation_random.seed = GENERATION_SEED
	add_child(_level)
	_level.build_level()
	_explore_everything()
	_reveal_everything()
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_add_player_light()
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

func _get_start() -> Vector3:
	return (get_tree().get_first_node_in_group(PlayerSpawnPoint.PLAYER_SPAWN_POINTS) as Node3D).global_position

## As the game shows a player at the start: the light above their figure (the only one with shadows) and the architecture
## fading towards it; camera and light read from the player controller scene, which is never added to the tree
func _add_player_light() -> void:
	var player_controller: Node = (load(PLAYER_CONTROLLER) as PackedScene).instantiate()
	var default_camera: Node3D = player_controller.get_node(^"DefaultCamera")
	_player_camera_offset = default_camera.get("follow_offset")
	_player_camera_fov = (player_controller.get_node(^"TopDownCamera") as Camera3D).fov
	var character_light: OmniLight3D = player_controller.get_node(^"Character/CharacterLight")
	var light: OmniLight3D = OmniLight3D.new()
	for property: StringName in [&"light_color", &"light_energy", &"light_size", &"shadow_enabled", &"omni_range"]:
		light.set(property, character_light.get(property))
	light.position = _get_start() + character_light.position
	player_controller.free()
	add_child(light)
	RenderingServer.global_shader_parameter_set(OcclusionTarget.PARAMETER, _get_start())

func _measure_views() -> void:
	var start: Vector3 = _get_start()
	var views: Dictionary[String, Transform3D] = {
		"player at start": Transform3D(Basis.IDENTITY, start + _player_camera_offset).looking_at(start, Vector3.UP),
		"whole map": _above_whole_map(),
	}
	_rows.append("| View | Switched off | Draw calls | Objects | Primitives | CPU ms | GPU ms | FPS |")
	_rows.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
	for view: String in views:
		_camera.global_transform = views[view]
		_camera.fov = _player_camera_fov
		for variant: String in ["nothing", "shadows", "lights", "particles", "props", "fog", "tilt-shift", "all of these"]:
			var restore: Callable = _switch_off(variant)
			var found: bool = restore.is_valid()
			if not found:
				push_error("Nothing to switch off for %s" % variant)
				restore = func() -> void: pass
			_rows.append(await _measure(view, variant if found else variant + NOT_FOUND))
			restore.call()

## Straight down over the map's middle, high enough that the field of view (vertical, the narrower one) spans every cell
## with half a cell to spare
func _above_whole_map() -> Transform3D:
	var half_depth: float = (_level.grid_extents.y + 1.0) * _level.grid_size
	var height: float = half_depth / tan(deg_to_rad(_player_camera_fov) * 0.5)
	return Transform3D(Basis.IDENTITY, Vector3.UP * height).looking_at(Vector3.ZERO, Vector3.FORWARD)

## @returns what puts it back; an invalid Callable if there was nothing to switch off
func _switch_off(variant: String) -> Callable:
	var undo: Array[Callable] = []
	var every: bool = variant == "all of these"
	if variant == "shadows" or every:
		for light: Light3D in _find(self, "Light3D"):
			if not light.shadow_enabled: continue
			light.shadow_enabled = false
			undo.append(light.set.bind(&"shadow_enabled", true))
	if variant == "lights" or every:
		for light: Light3D in _find(self, "Light3D"):
			if light is DirectionalLight3D or not light.visible: continue
			light.visible = false
			undo.append(light.set.bind(&"visible", true))
	if variant == "particles" or every:
		for particles: Node3D in _find(_level, "GPUParticles3D") + _find(_level, "CPUParticles3D"):
			if not particles.visible: continue
			particles.visible = false
			undo.append(particles.set.bind(&"visible", true))
	if variant == "props" or every:
		for tile: Structure in _level.get_placed_tiles():
			var decorations: Node3D = tile.model.get_node_or_null(NodePath(TileDecorations.NODE_NAME)) if tile.model else null
			if not decorations or not decorations.visible: continue
			decorations.visible = false
			undo.append(decorations.set.bind(&"visible", true))
	var world_environment: WorldEnvironment = _get_world_environment()
	var environment: Environment = world_environment.environment if world_environment else null
	if environment and (variant == "fog" or every):
		var fog: bool = environment.fog_enabled
		var volumetric_fog: bool = environment.volumetric_fog_enabled
		environment.fog_enabled = false
		environment.volumetric_fog_enabled = false
		undo.append(environment.set.bind(&"fog_enabled", fog))
		undo.append(environment.set.bind(&"volumetric_fog_enabled", volumetric_fog))
	if world_environment and world_environment.compositor and (variant == "tilt-shift" or every):
		var compositor: Compositor = world_environment.compositor
		world_environment.compositor = null
		undo.append(world_environment.set.bind(&"compositor", compositor))
	if undo.is_empty() and variant != "nothing": return Callable()
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
	var lights: Array[Node] = _find(self, "Light3D")
	var shadowed: int = lights.filter(func(light: Light3D) -> bool: return light.shadow_enabled).size()
	var particles: int = _find(_level, "GPUParticles3D").size() + _find(_level, "CPUParticles3D").size()
	print("%s (%s), window %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(), get_viewport().get_visible_rect().size])
	print("Tiles %d, mesh instances %d (%d distinct meshes), lights %d (%d with shadows), particle systems %d, nodes %d" % [
		_level.get_placed_tiles().size(), meshes.size(), unique_meshes.size(), lights.size(), shadowed, particles,
		_find(_level, "Node").size() + 1])

func _get_world_environment() -> WorldEnvironment:
	var found: Array[Node] = _find(_level, "WorldEnvironment")
	return found[0] as WorldEnvironment if not found.is_empty() else null

static func _find(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)
