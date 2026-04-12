class_name TileConnectionRestriction
extends ConnectionRestriction

@export var _tile_profiles: Array[StructureProfile]

func _can_connect(profile: StructureProfile) -> bool:
	return _tile_profiles.has(profile)
