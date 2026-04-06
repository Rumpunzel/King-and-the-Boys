class_name GroundCell
extends GridCell

var travel_cost: float = DEFAULT_TRAVEL_COST
var times_entered: int = 0

func get_travel_cost() -> float:
	return travel_cost * pow(2.0, -times_entered)
