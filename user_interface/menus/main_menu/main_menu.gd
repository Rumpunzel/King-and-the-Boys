@tool
@icon("uid://bgjmcb04v358t")
class_name MainMenu
extends Menu

@export_file("*.tscn") var _background_scene_path: String

@export_group("Configuration")
@export_file("*.tscn") var _lobby_scene_path: String

func _ready() -> void:
	Client.stop_game()
	SceneManager.preload_scene(_lobby_scene_path)
	if not _background_scene_path.is_empty(): Panorama.set_background(_background_scene_path)

func start_new_game() -> void:
	assert(multiplayer.is_server())
	close_menu()
	await fully_closed
	SceneManager.transition_to_scene(_lobby_scene_path)
	print_debug("Starting new game...")

func load_game() -> Error:
	assert(multiplayer.is_server())
	close_menu()
	print_debug("Loading game...")
	return Error.OK#error

func _on_start_pressed() -> void:
	start_new_game()

func _on_load_pressed() -> void:
	load_game()

func _on_quit_confirmation_dialog_confirmed() -> void:
	Client.quit_game()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _lobby_scene_path.is_empty(): warnings.append("Missing lobby scene path.")
	return warnings
