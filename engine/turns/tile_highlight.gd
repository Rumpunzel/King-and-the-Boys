@tool
class_name TileHighlight
extends MeshInstance3D
## Marks the tile the local player's controlled [Character] stands on in the game logic.
## Moves there at once, while the figure may still be walking.

const _SHADER: Shader = preload("res://engine/turns/tile_highlight.gdshader")

## Height above the tile's origin, so it shows on the floor
@export var height: float = 0.05
## Size relative to a grid cell
@export_range(0.1, 1.0) var size_ratio: float = 0.92

@export_group("Configuration")
@export var _state_machine: PlayerStateMachine

var _character: Character:
	set(new_character):
		if _character: _character.entered_grid_cell.disconnect(_on_character_entered_grid_cell)
		_character = new_character
		_character.entered_grid_cell.connect(_on_character_entered_grid_cell)
		_move_to(_character.grid_cell)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	top_level = true
	# Every ghost carries one; only the local player sees theirs
	if not _state_machine.player_ghost.is_multiplayer_authority():
		hide()
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _SHADER
	material_override = material
	_state_machine.controlled_character_changed.connect(_on_controlled_character_changed)
	_character = _state_machine.get_controlled_character()

func _move_to(cell: Vector2i) -> void:
	var level: Level = _character.level
	if not level:
		hide()
		return
	if not mesh:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2.ONE * level.grid_size * size_ratio
		mesh = plane
	global_position = level.grid_to_world_position(cell) + Vector3.UP * height
	show()

func _on_controlled_character_changed(controlled_character: Character) -> void:
	_character = controlled_character

func _on_character_entered_grid_cell(cell: Vector2i) -> void:
	_move_to(cell)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _state_machine: warnings.append("Missing PlayerStateMachine reference.")
	return warnings
