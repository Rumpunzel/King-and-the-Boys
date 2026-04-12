class_name RoomTypeConnectionRestriction
extends ConnectionRestriction

@export var _room_types: Array[RoomType]

func _can_connect(profile: StructureProfile) -> bool:
	return _room_types.has(profile.room_type)
