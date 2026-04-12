class_name RoomTypeConnectionRestriction
extends ConnectionRestriction

@export var _room_types: Array[RoomType]

func _can_connect(_own_profile: StructureProfile, other_profile: StructureProfile) -> bool:
	return _room_types.has(other_profile.room_type)
