@tool
@icon("uid://bgjmcb04v358t")
class_name MainMenu
extends Menu

@export_file("*.tscn", "*.scn") var _background_scene_path: String

@export_group("Configuration")
@export_file("*.tscn") var _lobby_host_scene_path: String
@export_file("*.tscn") var _lobby_connecting_scene_path: String

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.joining_multiplayer.connect(_on_joining_multiplayer)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	Client.stop_game()
	if not _background_scene_path.is_empty(): Panorama.set_background(_background_scene_path)

func open_lobby() -> void:
	assert(multiplayer.is_server())
	close_menu()
	print_debug("Opening lobby...")
	await fully_closed
	SceneManager.transition_to_scene(_lobby_host_scene_path, false)

func connect_to_lobby() -> void:
	close_menu()
	print_debug("Connecting to lobby...")
	await fully_closed
	if not get_tree().current_scene == self: return
	SceneManager.transition_to_scene(_lobby_connecting_scene_path, false)

func load_game() -> Error:
	assert(multiplayer.is_server())
	close_menu()
	print_debug("Loading game...")
	return Error.OK#error

func _on_start_pressed() -> void:
	open_lobby()

func _on_load_pressed() -> void:
	load_game()

func _on_quit_confirmation_dialog_confirmed() -> void:
	Client.quit_game()

func _on_joining_multiplayer() -> void:
	connect_to_lobby()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _lobby_host_scene_path.is_empty(): warnings.append("Missing lobby host scene path.")
	if _lobby_connecting_scene_path.is_empty(): warnings.append("Missing lobby connecting scene path.")
	return warnings
