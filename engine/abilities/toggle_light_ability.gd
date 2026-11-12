@tool
@icon("uid://bfyuiyaua5vyl")
class_name ToggleLightAbility
extends Ability
## Turns a light the character carries on or off, e.g. the rogue's belt lantern. Lit, it shines from above the character
## and widens its sight (see [member light_source]); lighting it brings what it shows into sight at once.
## Whether it is lit is replicated by [member Character.toggled_ability_ids], which holds the abilities differing from how
## they start ([member lit_at_start])

class ToggleStep extends AbilityStep:
	func undo(_level: Level) -> void:
		(ability as ToggleLightAbility).toggle(character)

## The light shining while lit
@export var light_source: LightSource:
	set(new_light_source):
		light_source = new_light_source
		changed.emit()
@export var lit_at_start: bool = true:
	set(new_lit_at_start):
		lit_at_start = new_lit_at_start
		changed.emit()

@export_group("Prop")
## What the model shows, e.g. the lantern on the belt; a [code]lit[/code] property on its root follows the light
@export var prop: PackedScene:
	set(new_prop):
		prop = new_prop
		changed.emit()
## The bone it hangs from
@export var bone: StringName = &"Hips":
	set(new_bone):
		bone = new_bone
		changed.emit()
## Where it hangs, relative to the bone
@export var prop_transform: Transform3D = Transform3D.IDENTITY:
	set(new_prop_transform):
		prop_transform = new_prop_transform
		changed.emit()

func _init() -> void:
	cost = 0

func is_lit(character: Character) -> bool:
	return character.toggled_ability_ids.has(ResourceId.of(self)) != lit_at_start

func get_light_source(character: Character) -> LightSource:
	return light_source if is_lit(character) else null

func use(character: Character, target: Vector2i, argument: int, level: Level) -> AbilityStep:
	toggle(character)
	# What the light shows comes into sight now; a lit lantern that revealed tiles can not be put out by undo
	if is_lit(character): level.update_sight(character, character.grid_cell)
	return ToggleStep.new(self, character, get_cost(character, target, argument))

## Host only: lights the light or puts it out
func toggle(character: Character) -> void:
	var ability_id: String = ResourceId.of(self)
	var toggled: PackedStringArray = character.toggled_ability_ids.duplicate()
	if toggled.has(ability_id): toggled.remove_at(toggled.find(ability_id))
	else: toggled.append(ability_id)
	character.toggled_ability_ids = toggled

func show_on(character: Character) -> void:
	if not prop: return
	var skeleton: Skeleton3D = character.model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D if character.model else null
	if not skeleton: return
	var holder_name: String = "%s_%s" % [name.to_pascal_case(), bone]
	var holder: BoneAttachment3D = skeleton.get_node_or_null(holder_name) as BoneAttachment3D
	if not holder:
		holder = BoneAttachment3D.new()
		holder.name = holder_name
		skeleton.add_child(holder)
		holder.bone_name = bone
		var shown: Node3D = prop.instantiate() as Node3D
		shown.transform = prop_transform
		holder.add_child(shown)
	for shown: Node in holder.get_children(): shown.set(&"lit", is_lit(character))
