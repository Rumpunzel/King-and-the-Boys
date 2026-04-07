@tool
@icon("uid://bgjmcb04v358t")
class_name MainMenu
extends Control

@export_group("Configuration")
@export var _default_level: PackedScene
@export var _loading_screen_scene: PackedScene = preload("uid://dmweuj7kxaxov")

var _loading_screen: CanvasLayer

func start_new_game() -> void:
	assert(multiplayer.is_server())
	get_tree().change_scene_to_file("res://engine/game.tscn")
	print_debug("Starting new game...")

func load_game() -> Error:
	assert(multiplayer.is_server())
	print_debug("Loading game...")
	return Error.OK#error

func _on_new_game_pressed() -> void:
	start_new_game()

func _on_load_pressed() -> void:
	load_game()

func _on_quit_confirmation_dialog_confirmed() -> void:
	Client.quit_game()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _default_level: warnings.append("Missing default level scene.")
	if not _loading_screen_scene: warnings.append("Missing loading screen scene.")
	return warnings
