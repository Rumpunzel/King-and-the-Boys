extends Node
## Takes the same screenshots after every look change, to compare lighting side by side: plays the game offline on a seeded
## dungeon, walks each hero the same path and saves a shot after every step, in colour and in greyscale (does the board still
## read without colour?). Run windowed (rendering is off headless):
## [code]<godot> --path . res://tools/look_shots/look_shots.tscn[/code]. Shots go to [code]reports/look_shots/<label>/[/code],
## the label set by [code]-- --label=<name>[/code] (default: the time). Same seed and path build the same dungeon, so shots
## of two runs line up. [code]-- --fovs=25,38,50[/code] shoots every step once per field of view (vertical, degrees), the
## camera moved along its view so the figure's surroundings fill the frame alike.

## engine/game.tscn, played offline
const GAME: String = "uid://ciy6s8n2reyy2"
const OUTPUT: String = "res://reports/look_shots"

## Seeds the dungeon and every other roll (bodies, flicker)
@export var generation_seed: int = 7
## Heroes walked one after another: with and without carried lights
@export var heroes: Array[CharacterProfile] = []
## Steps each hero takes; refused steps (no passage) only turn the figure and still get their shot
@export var path: Array[Level.Direction] = []
## Seconds after a step before its shot: tiles lift, land and get dressed, figures settle
@export var settle_seconds: float = 4.0
## Seconds before the first shot: the start is built and dressed
@export var start_seconds: float = 8.0
## Physics frames the camera gets to take a new field of view and distance before its shot (it is interpolated between them)
@export var refocus_frames: int = 3

var _output: String
## Fields of view to shoot each step with; empty: the camera's own only
var _fovs: PackedFloat32Array = []

func _ready() -> void:
	_output = "%s/%s" % [OUTPUT, _get_argument("label", Time.get_datetime_string_from_system().replace(":", "-"))]
	for fov: String in _get_argument("fovs", "").split(",", false): _fovs.append(fov.to_float())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	# Keeps the editor from importing every shot
	FileAccess.open("%s/.gdignore" % OUTPUT, FileAccess.WRITE)
	Panorama.clear_background()
	Client.start_game()
	await get_tree().process_frame
	for hero: CharacterProfile in heroes: await _walk(hero)
	print("Shots saved to %s" % ProjectSettings.globalize_path(_output))
	get_tree().quit()

func _walk(hero: CharacterProfile) -> void:
	seed(generation_seed)
	Lobby.get_local_player().character = hero
	var game: Game = (load(GAME) as PackedScene).instantiate()
	(game.get_node(^"Level") as Level).generation_random.seed = generation_seed
	(game.get_node(^"UserInterface") as CanvasLayer).visible = false
	add_child(game)
	var spawner: PlayerControllerSpawner = game.get_node(^"PlayerControllerSpawner")
	game.setup_game()
	while spawner.get_child_count() == 0: await get_tree().process_frame
	var player_controller: PlayerController = spawner.get_child(0)
	var character: Character = player_controller.character
	var turn_manager: TurnManager = TurnManager.get_instance(get_tree())
	var name_prefix: String = hero.resource_path.get_file().get_basename()
	await get_tree().create_timer(start_seconds).timeout
	await _shoot_views(player_controller, "%s_00" % name_prefix)
	for step: int in path.size():
		if character.movement_points <= 0: turn_manager.request_pass(true)
		turn_manager.request_move(character.get_path(), path[step])
		await get_tree().create_timer(settle_seconds).timeout
		await _shoot_views(player_controller, "%s_%02d" % [name_prefix, step + 1])
	spawner.stop_synching_players()
	remove_child(game)
	game.queue_free()
	await get_tree().process_frame

## Shoots once, or once per field of view: the camera's distance to the figure (its follow offset) scales with the view's
## width, so the ground around the figure spans the frame alike, and is put back after
func _shoot_views(player_controller: PlayerController, file_name: String) -> void:
	if _fovs.is_empty():
		await _shoot(file_name)
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var follow: Node3D = player_controller.get_node(^"DefaultCamera")
	var own_fov: float = camera.fov
	var own_offset: Vector3 = follow.get(&"follow_offset")
	for fov: float in _fovs:
		camera.fov = fov
		follow.set(&"follow_offset", own_offset * tan(deg_to_rad(own_fov) * 0.5) / tan(deg_to_rad(fov) * 0.5))
		for _frame: int in refocus_frames: await get_tree().physics_frame
		await _shoot("%s_fov%02d" % [file_name, roundi(fov)])
	camera.fov = own_fov
	follow.set(&"follow_offset", own_offset)

func _shoot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_output, file_name])
	image.convert(Image.FORMAT_L8)
	image.save_png("%s/%s_grey.png" % [_output, file_name])

## The value of [code]--<argument_name>=<value>[/code] after [code]--[/code] on the command line, or [param default]
func _get_argument(argument_name: String, default: String) -> String:
	var prefix: String = "--%s=" % argument_name
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return default
