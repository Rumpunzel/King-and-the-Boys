@icon("uid://ckgyvk04a2ahd")
class_name AlwaysTrueRestriction
extends ConnectionRestriction

func _can_connect(_own_profile: StructureProfile, _other_profile: StructureProfile) -> bool:
	return true
