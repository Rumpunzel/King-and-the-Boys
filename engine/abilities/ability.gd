@tool
class_name Ability
extends Resource
## Something a [Character] can do besides stepping, listed by its [member CharacterProfile.abilities].
## Subclasses own the rules; the [TurnManager] checks the turn's limits and runs them on the host.
## Passives ([constant Targeting.NONE]) only describe a trait whose effect lives in the profile's stats.

## Stored by number in ability files: only append
enum Targeting {
	## A passive: never used
	NONE,
	## The cell the character stands on
	OWN_TILE,
}

@export var name: String:
	set(new_value):
		name = new_value
		changed.emit()
@export_multiline var description: String:
	set(new_value):
		description = new_value
		changed.emit()
@export var icon: Texture2D:
	set(new_value):
		icon = new_value
		changed.emit()

@export var targeting: Targeting = Targeting.OWN_TILE:
	set(new_value):
		targeting = new_value
		changed.emit()
## Movement points a use costs, see [method get_cost]
@export_range(0, 10) var cost: int = 1:
	set(new_value):
		cost = new_value
		changed.emit()
## Uses per turn; [code]0[/code] for no limit
@export_range(0, 10) var uses_per_turn: int = 0:
	set(new_value):
		uses_per_turn = new_value
		changed.emit()
## Uses per game; [code]<0[/code] for no limit, see [method get_charges_left]
@export var charges: int = -1:
	set(new_value):
		charges = new_value
		changed.emit()
## The ability stays active over several requests until it is confirmed or cancelled (e.g. a lifted tile)
@export var held: bool = false:
	set(new_value):
		held = new_value
		changed.emit()

func is_passive() -> bool: return targeting == Targeting.NONE

## @returns the uses left to [param character] this game; [code]<0[/code] if it has no limit
func get_charges_left(character: Character) -> int:
	if charges < 0: return -1
	var used: int = character.ability_uses.get(ResourceId.of(self), 0)
	return maxi(charges - used, 0)

## Host only; @returns the cells [param character] could target now
func get_targets(character: Character, _level: Level) -> Array[Vector2i]:
	match targeting:
		Targeting.OWN_TILE: return [character.grid_cell]
	return []

## @returns the movement points using the ability on [param _target] with [param _argument] costs
func get_cost(_character: Character, _target: Vector2i, _argument: int) -> int:
	return cost

## Host only; the ability's own rules, the turn's limits are checked by the [TurnManager]
func can_use(character: Character, target: Vector2i, _argument: int, level: Level) -> bool:
	return not is_passive() and get_targets(character, level).has(target)

## Host only: applies the ability; called after [method can_use] allowed it.
## A [member held] ability ends here: [method begin] and [method adjust] came first.
## @returns what it changed, so it can be undone
func use(character: Character, target: Vector2i, argument: int, _level: Level) -> AbilityStep:
	assert(not is_passive(), "%s is passive" % name)
	return AbilityStep.new(self, character, get_cost(character, target, argument))

## Host only, [member held] abilities: whether [param character] may start using the ability on [param target]
func can_begin(character: Character, target: Vector2i, level: Level) -> bool:
	return not is_passive() and get_targets(character, level).has(target)

## Host only, [member held] abilities: starts using the ability; costs nothing until [method use]
func begin(_character: Character, _target: Vector2i, _level: Level) -> void:
	pass

## Host only, [member held] abilities: the player changed their choice; the [TurnManager] checked they can pay for it
func adjust(_character: Character, _target: Vector2i, _argument: int, _level: Level) -> void:
	pass

## Host only, [member held] abilities: takes back [method begin] and [method adjust], e.g. on a pass or the turn's end
func cancel(_character: Character, _target: Vector2i, _level: Level) -> void:
	pass

func _to_string() -> String:
	return "[Ability %s]" % name
