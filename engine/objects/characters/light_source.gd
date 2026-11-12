@tool
@icon("uid://dcdlmxnu8p5h7")
class_name LightSource
extends Resource
## A light a character carries, e.g. a torch in hand (a mesh naming it in its [constant META]) or a lit lantern (see
## [ToggleLightAbility]). It shines from above the character, replacing the character's own light (see
## [code]character_light.gd[/code]), and widens what the character sees (see [method Character.get_vision])

## Meta of a mesh naming the [LightSource] it is, e.g. the torch's
const META: StringName = &"light_source"

@export var color: Color = Color(1.0, 0.62, 0.3):
	set(new_color):
		color = new_color
		changed.emit()
@export var energy: float = 4.0:
	set(new_energy):
		energy = new_energy
		changed.emit()
## How far the light reaches, in metres
@export var light_range: float = 10.0:
	set(new_light_range):
		light_range = new_light_range
		changed.emit()
## Change the bearer's [member CharacterProfile.vision] while the light shines
@export var vision_modifiers: Array[StatModifier]:
	set(new_vision_modifiers):
		vision_modifiers = new_vision_modifiers
		changed.emit()
## Change the bearer's [member CharacterProfile.dark_vision] while the light shines
@export var dark_vision_modifiers: Array[StatModifier]:
	set(new_dark_vision_modifiers):
		dark_vision_modifiers = new_dark_vision_modifiers
		changed.emit()

## @returns the [LightSource] [param mesh] is, or [code]null[/code]
static func of_mesh(mesh: Mesh) -> LightSource:
	return mesh.get_meta(META) as LightSource if mesh and mesh.has_meta(META) else null
