class_name TileConnectionRestriction
extends ConnectionRestriction

@export var _tile_profiles: Array[StructureProfile]
@export var _include_self: bool = true

func _can_connect(own_profile: StructureProfile, other_profile: StructureProfile) -> bool:
	return (_include_self and own_profile == other_profile) or _tile_profiles.has(other_profile)
