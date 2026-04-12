class_name ConnectionRestrictionUnion
extends ConnectionRestriction

@export var _restrictions: Array[ConnectionRestriction]

func _can_connect(profile: StructureProfile) -> bool:
	return _restrictions.all(func(restriction: ConnectionRestriction) -> bool: return restriction.can_connect(profile))
