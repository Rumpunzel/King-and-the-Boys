@abstract
class_name ConnectionRestriction
extends Resource

@export var _invert: bool = false

func can_connect(profile: StructureProfile) -> bool:
	var result: bool = _can_connect(profile)
	return result if not _invert else not result

@abstract func _can_connect(profile: StructureProfile) -> bool
