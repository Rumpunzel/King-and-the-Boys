@icon("uid://bbd6uslekkp8l")
class_name InvestigationMark
extends MeshInstance3D
## Marks the cell a monster goes to look at ([constant Agent.Awareness.INVESTIGATING], [member Agent.awareness_target]) on its
## floor, on every peer, while this peer shows the monster: the tile highlight's brackets in the monsters' colour. Only shows what
## the host decided (see [MonsterSenses]).

const _SHADER: Shader = preload("uid://ccbkajwstv6dd")  # engine/turns/tile_highlight.gdshader

## Height above the tile's origin, so it shows on the floor
@export var height: float = 0.04
## Size relative to a grid cell
@export_range(0.1, 1.0) var size_ratio: float = 0.8
@export var color: Color = Color(1.0, 0.84, 0.36)

@export_group("Configuration")
@export var _agent: Agent

func _ready() -> void:
	top_level = true
	hide()
	if Engine.is_editor_hint(): return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _SHADER
	material.set_shader_parameter(&"color", color)
	material_override = material

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _agent: return
	var character: Character = _agent.character
	var level: Level = character.level
	visible = level != null and _agent.awareness == Agent.Awareness.INVESTIGATING and character.visible and character.shown
	if not visible: return
	if not mesh:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2.ONE * level.grid_size * size_ratio
		mesh = plane
	global_position = level.grid_to_world_position(_agent.awareness_target) + Vector3.UP * height

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _agent: warnings.append("Missing Agent reference.")
	return warnings
