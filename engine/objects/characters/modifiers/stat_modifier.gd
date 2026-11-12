@tool
@abstract
@icon("uid://njrkm86tpthg")
class_name StatModifier
extends Resource
## Changes one of a character's stats (e.g. its vision) while what holds the modifier applies, e.g. a lit torch (see
## [LightSource]). Each subclass is one way of changing it (adding, multiplying, ...); lists apply in order

## @returns [param value] changed by this modifier
@abstract func apply(value: float) -> float

## @returns [param value] changed by every modifier of [param modifiers], in order
static func apply_all(modifiers: Array[StatModifier], value: float) -> float:
	for modifier: StatModifier in modifiers:
		if modifier: value = modifier.apply(value)
	return value
