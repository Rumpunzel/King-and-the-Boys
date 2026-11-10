@tool
extends EditorScript

## Copies animations out of the imported (read-only) Quaternius library into an editable library file, so they can be adjusted.
## Open this script, list the animations below, and run it: Script editor > File > Run (Ctrl+Shift+X). Then add the library to the
## body's AnimationPlayer (Animation > Manage Animations > Load Library) and name the copies by "Adjusted/<name>" in model
## animations and profiles. Animations the library holds already are left alone, so your edits are never overwritten

## Animations to copy, and the names to give the copies; an empty name keeps the original's
const ANIMATIONS: Dictionary[String, String] = {
	"BackFlip": "",
}
const SOURCE: String = "res://assets/quaternius_animations/AnimationLibrary_Godot.glb"
const TARGET: String = "res://data/characters/animations/adjusted_animations.tres"

func _run() -> void:
	var source: AnimationLibrary = load(SOURCE)
	var target: AnimationLibrary = load(TARGET) if ResourceLoader.exists(TARGET) else AnimationLibrary.new()
	for animation_name: String in ANIMATIONS:
		var copy_name: String = ANIMATIONS[animation_name] if not ANIMATIONS[animation_name].is_empty() else animation_name
		if not source.has_animation(animation_name):
			push_error("%s has no animation %s" % [SOURCE, animation_name])
			continue
		if target.has_animation(copy_name):
			print("%s is in the library already; kept" % copy_name)
			continue
		target.add_animation(copy_name, source.get_animation(animation_name).duplicate(true) as Animation)
		print("Copied %s as %s" % [animation_name, copy_name])
	DirAccess.make_dir_recursive_absolute(TARGET.get_base_dir())
	var error: Error = ResourceSaver.save(target, TARGET)
	if error != OK: push_error("Could not save %s: %s" % [TARGET, error_string(error)])
	else: print("Saved %s" % TARGET)
	EditorInterface.get_resource_filesystem().scan()
