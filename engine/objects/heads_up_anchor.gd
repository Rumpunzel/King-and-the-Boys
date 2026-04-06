@tool
@icon("uid://duyge1d76pols")
class_name HeadsUpAnchor
extends Marker3D

const HEADS_UP_ANCHOR_SCENE: PackedScene = preload("uid://cpmcbnpcemt61")
const HUD_PLACEHOLDER_SCENE: PackedScene = preload("uid://c3ggesrya61ic")

@export var _root_node: Node3D
## If false, display placeholder gizmo only when the scene is opened
@export var _global_placeholder: bool = false

var _hud_placeholder: Sprite3D

func _enter_tree() -> void:
	var parent: Node = get_parent()
	if not _root_node and parent is Node3D:
		_root_node = parent
	if not Engine.is_editor_hint(): return
	if _hud_placeholder:
		remove_child(_hud_placeholder)
		_hud_placeholder.queue_free()
		_hud_placeholder = null
	if not _global_placeholder and EditorInterface.get_edited_scene_root() != _root_node: return
	_hud_placeholder = HUD_PLACEHOLDER_SCENE.instantiate()
	add_child(_hud_placeholder, false, Node.INTERNAL_MODE_FRONT)

static func create(offset: Vector3) -> HeadsUpAnchor:
	var new_heads_up_anchor: HeadsUpAnchor = HEADS_UP_ANCHOR_SCENE.instantiate()
	new_heads_up_anchor.position = offset
	return new_heads_up_anchor

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _root_node: warnings.append("Missing root node reference.")
	return warnings
