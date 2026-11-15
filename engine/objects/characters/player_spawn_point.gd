@tool
@icon("uid://duke3cveuxxso")
class_name PlayerSpawnPoint
extends Marker3D

const PLAYER_SPAWN_POINTS: StringName = "PlayerSpawnPoints"

func _enter_tree() -> void:
	add_to_group(PLAYER_SPAWN_POINTS)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
