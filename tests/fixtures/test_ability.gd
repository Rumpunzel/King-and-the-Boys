extends Ability
## Test ability: records what the turn manager calls in the character's metadata.
## A use adds 1 to "effects" (at once, or when the turn ends with [member acts_at_turn_end]); undo takes it back.
## Held: "begun", "argument" and "cancelled" follow begin, adjust and cancel. An argument of -1 is refused.

const EFFECTS: StringName = &"effects"
const BEGUN: StringName = &"begun"
const ARGUMENT: StringName = &"argument"
const CANCELLED: StringName = &"cancelled"

@export var acts_at_turn_end: bool = false

class TestStep extends AbilityStep:
	var resolves_later: bool = false

	func undo(_level: Level) -> void:
		if not resolves_later: TestAbilityMeta.add(character, EFFECTS, -1)

	func acts_at_turn_end() -> bool:
		return resolves_later

	func resolve_at_turn_end(_level: Level) -> void:
		TestAbilityMeta.add(character, EFFECTS, 1)

class TestAbilityMeta:
	static func add(character: Character, key: StringName, amount: int) -> void:
		var value: int = character.get_meta(key, 0)
		character.set_meta(key, value + amount)

func can_use(character: Character, target: Vector2i, argument: int, level: Level) -> bool:
	return argument >= 0 and super(character, target, argument, level)

func use(character: Character, target: Vector2i, argument: int, _level: Level) -> AbilityStep:
	var step: TestStep = TestStep.new(self, character, get_cost(character, target, argument))
	step.resolves_later = acts_at_turn_end
	if not acts_at_turn_end: TestAbilityMeta.add(character, EFFECTS, 1)
	if held: character.set_meta(BEGUN, false)
	return step

func begin(character: Character, _target: Vector2i, _level: Level) -> void:
	character.set_meta(BEGUN, true)

func adjust(character: Character, _target: Vector2i, argument: int, _level: Level) -> void:
	character.set_meta(ARGUMENT, argument)

func cancel(character: Character, _target: Vector2i, _level: Level) -> void:
	character.set_meta(BEGUN, false)
	TestAbilityMeta.add(character, CANCELLED, 1)
