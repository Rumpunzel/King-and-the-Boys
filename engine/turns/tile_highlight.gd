@tool
@icon("uid://bbd6uslekkp8l")
class_name TileHighlight
extends MeshInstance3D
## Marks the tile the local player's [Character] stands on in the game logic.
## Moves there at once, while the figure may still be walking.

const _SHADER: Shader = preload("res://engine/turns/tile_highlight.gdshader")

## Height above the tile's origin, so it shows on the floor
@export var height: float = 0.05
## Size relative to a grid cell
@export_range(0.1, 1.0) var size_ratio: float = 0.92

@export_group("Configuration")
@export var _player_controller: PlayerController

func _ready() -> void:
	if Engine.is_editor_hint(): return
	top_level = true
	# Every player controller carries one; only the local player sees theirs
	if not _player_controller.is_multiplayer_authority():
		hide()
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _SHADER
	material_override = material
	_player_controller.character.entered_grid_cell.connect(_move_to)
	_move_to(_player_controller.character.grid_cell)

func _move_to(cell: Vector2i) -> void:
	var level: Level = _player_controller.character.level
	if not level:
		hide()
		return
	if not mesh:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2.ONE * level.grid_size * size_ratio
		mesh = plane
	global_position = level.grid_to_world_position(cell) + Vector3.UP * height
	show()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_controller: warnings.append("Missing PlayerController reference.")
	return warnings
