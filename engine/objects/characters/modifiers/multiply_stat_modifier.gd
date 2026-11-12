@tool
@icon("uid://njrkm86tpthg")
class_name MultiplyStatModifier
extends StatModifier
## Multiplies the stat by [member factor]

@export var factor: float = 1.0:
	set(new_factor):
		factor = new_factor
		changed.emit()

func apply(value: float) -> float: return value * factor
