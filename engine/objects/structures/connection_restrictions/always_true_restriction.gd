@icon("uid://c0635dcx22d3o")
class_name AlwaysTrueRestriction
extends ConnectionRestriction

func _can_connect(_own_profile: StructureProfile, _other_profile: StructureProfile) -> bool:
	return true
