class_name GridCell
extends RefCounted

const DEFAULT_TRAVEL_COST: float = 1.0

static func get_default() -> GridCell:
	return GroundCell.new()
