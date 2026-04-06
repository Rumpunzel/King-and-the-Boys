@tool
extends Node3D

func _on_model_preview_visibility_changed() -> void:
	visible = owner.is_visible_in_tree()
