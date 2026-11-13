@tool
@icon("uid://c01xwaih2ao4p")
@abstract
class_name BoardObject
extends Node3D
## A piece of the board: a [Character], a [Structure] (a tile) or a [Thing]. Each keeps its own typed profile and hands it
## out through [method get_profile]; the base shows the profile's model and names it.

signal profile_changed

## Which of the profile's model variations it shows; [code]<0[/code] for a random one
@export var variation: int = -1:
	set(new_variation):
		if new_variation == variation: return
		variation = new_variation
		var profile: Profile = get_profile()
		if not profile or not model: return
		model = profile.create_model(variation)

var model: Model:
	set(new_model):
		if model:
			remove_child(model)
			model.queue_free()
		model = new_model
		if not model: return
		add_child(model, true)
		_on_model_added()

## @returns the profile it was created from, typed by each kind of piece
@abstract func get_profile() -> Profile

func get_portrait() -> Texture:
	if model and model.portrait_override: return model.portrait_override
	return get_profile().portrait

func get_heads_up_anchor() -> Vector3:
	return position + get_profile().heads_up_display_offset

## Shows the new profile; each subclass's profile setter calls it. With [param roll_variation], a new variation is rolled
## even if one was set, else only if none was (e.g. a character keeps the one of its spawn data)
func _show_profile(roll_variation: bool) -> void:
	var profile: Profile = get_profile()
	if not profile:
		assert(Engine.is_editor_hint())
		model = null
		profile_changed.emit()
		return
	if roll_variation or variation < 0: variation = profile.get_random_variation()
	model = profile.create_model(variation)
	profile_changed.emit()
	add_to_group(profile.get_group_name())

## Called whenever a new model was added, e.g. for a character to dress it
func _on_model_added() -> void:
	pass
