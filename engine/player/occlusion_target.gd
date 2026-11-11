@icon("uid://c0agjgxun21hd")
class_name OcclusionTarget
extends Node

## Tells the props' occlusion shader (occludable.gdshader) where the local player's character stands, so architecture between the
## camera and it fades out. Visual only: every peer follows its own player

const PARAMETER: StringName = &"occlusion_target"

## The point the camera must see, above the character's feet
@export var height: float = 1.0

@export_group("Configuration")
@export var _player_controller: PlayerController

func _process(_delta: float) -> void:
	if not _player_controller.player or not _player_controller.player.is_local_player(): return
	var character: Character = _player_controller.character
	if not character: return
	# The model is the figure, which moves ahead of or behind the character's grid cell
	var figure: Node3D = character
	if character.model: figure = character.model
	RenderingServer.global_shader_parameter_set(PARAMETER, figure.global_position + Vector3.UP * height)

