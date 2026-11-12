@tool
@icon("uid://njrkm86tpthg")
class_name AddStatModifier
extends StatModifier
## Adds [member amount] to the stat, e.g. a torch lighting one more cell around its bearer

@export var amount: float = 1.0:
	set(new_amount):
		amount = new_amount
		changed.emit()

func apply(value: float) -> float: return value + amount
