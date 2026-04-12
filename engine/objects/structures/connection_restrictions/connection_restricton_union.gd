class_name ConnectionRestrictionUnion
extends ConnectionRestriction

@export var _restrictions: Array[ConnectionRestriction]

func _can_connect(own_profile: StructureProfile, other_profile: StructureProfile) -> bool:
	return _restrictions.all(func(restriction: ConnectionRestriction) -> bool: return restriction.can_connect(own_profile, other_profile))
