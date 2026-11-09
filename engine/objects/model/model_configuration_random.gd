@tool
class_name ModelConfigurationRandom
extends ModelConfiguration

## Every part [method configure] touches, either by randomizing or by resetting it
const BODY_PARTS: Array[ModularCharacter.Part] = [
	ModularCharacter.Part.HEAD,
	ModularCharacter.Part.HAIR,
	ModularCharacter.Part.EYEBROW,
	ModularCharacter.Part.EARS,
	ModularCharacter.Part.FACIAL_HAIR,
]

@export_group("Body Parts")
@export var _randomize_ears: bool
@export var _randomize_head: bool
@export_group("Hair")
@export var _randomize_eyebrow: bool
@export var _randomize_facial_hair: bool
@export var _randomize_hair: bool

func configure(model: ModularCharacter) -> void:
	if _randomize_head: model.head.random_mesh()
	if _randomize_hair: model.hair.random_mesh()
	if _randomize_eyebrow: model.eyebrow.random_mesh()
	if _randomize_ears: model.ears.random_mesh()
	else: model.ears.reset_mesh()
	if _randomize_facial_hair: model.facial_hair.random_mesh()
	else: model.facial_hair.reset_mesh()

## Randomizes [param model] and returns the result as mesh [ResourceId]s, so peers can apply the exact same look
## @returns {Part: [enum ModularCharacter.Part] -> mesh ID: [String]}, an empty ID meaning no mesh
func roll(model: ModularCharacter) -> Dictionary:
	configure(model)
	var body: Dictionary = {}
	for part: ModularCharacter.Part in BODY_PARTS:
		var body_part: ModularBodyPart = model.get_part(part)
		body[part] = ResourceId.of(body_part.mesh)
	return body
