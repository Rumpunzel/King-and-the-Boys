class_name AbilityStep
extends RefCounted
## Host only: one use of an [Ability], kept on the turn's undo stack. Subclasses record what the use changed.

var ability: Ability
var character: Character
## Movement points the use cost, refunded on undo
var cost: int

func _init(used_ability: Ability, used_by: Character, paid_cost: int) -> void:
	ability = used_ability
	character = used_by
	cost = paid_cost

## Takes back what the use changed on the board; points, uses and charges are refunded by the [TurnManager]
func undo(_level: Level) -> void:
	pass
