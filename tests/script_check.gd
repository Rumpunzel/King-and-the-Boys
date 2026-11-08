extends Node

## Loads every script of the project (not the vendored addons) so each one compiles, then quits; run it like the game:
## [code]godot --headless --path . res://tests/script_check.tscn[/code]. Godot prints SCRIPT ERROR for every script that fails, which CI looks for.
## Needed because the tests and the editor scan only compile the scripts they happen to load.

const VENDORED: Array[String] = [
	"res://addons/debug_draw_3d",
	"res://addons/gdUnit4",
	"res://addons/godot-git-plugin",
	"res://addons/godot-plugin-refresher",
	"res://addons/godotsteam",
	"res://addons/phantom_camera",
	"res://addons/radial_progress",
	"res://addons/toastparty",
]

func _ready() -> void:
	var count: int = _load_scripts("res://")
	print("Script check: loaded %d scripts" % count)
	get_tree().quit()

static func _load_scripts(directory: String) -> int:
	var count: int = 0
	for subdirectory: String in DirAccess.get_directories_at(directory):
		var path: String = directory.path_join(subdirectory)
		if subdirectory.begins_with(".") or VENDORED.has(path): continue
		count += _load_scripts(path)
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() != "gd": continue
		load(directory.path_join(file))
		count += 1
	return count
