extends Node3D
## A lantern that is lit or not, e.g. the rogue's on the belt (see [ToggleLightAbility]): lit, its glass glows and a flame burns
## in it; its light shines from above the character, not from the lantern

@export var lit: bool = true:
	set(new_lit):
		lit = new_lit
		if is_node_ready(): _show()

@export_group("Configuration")
@export var _glass: MeshInstance3D
@export var _lit_glass: Material
@export var _flame: Node3D

func _ready() -> void:
	_show()

func _show() -> void:
	_glass.material_override = _lit_glass if lit else null
	_flame.visible = lit
