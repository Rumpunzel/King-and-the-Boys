@abstract
class_name ConnectionRestriction
extends Resource

@export var _invert: bool = false

func can_connect(own_profile: StructureProfile, other_profile: StructureProfile) -> bool:
	var result: bool = _can_connect(own_profile, other_profile)
	return result if not _invert else not result

@abstract func _can_connect(own_profile: StructureProfile, other_profile: StructureProfile) -> bool
