@tool
class_name ModelConfigurationRandom
extends ModelConfiguration

## Rolls a body: every body part (the parts no slot owns, see [method ModularModel.get_body_parts]) named in
## [member randomized_parts] gets a random mesh, the others their default

## Names of the model's parts, e.g. "HAIR" or "FACIAL_HAIR"; parts a body lacks are ignored, so one configuration can serve several
@export var randomized_parts: PackedStringArray = []:
	set(new_value):
		randomized_parts = new_value
		changed.emit()

func configure(model: ModularModel) -> void:
	var part_keys: PackedStringArray = model.get_part_keys()
	for part: int in model.get_body_parts():
		if randomized_parts.has(part_keys[part]): model.get_part(part).random_mesh()
		else: model.get_part(part).reset_mesh()

## Randomizes [param model] and returns the result as mesh [ResourceId]s, so peers can apply the exact same look
## @returns {part: [int] -> mesh ID: [String]}, an empty ID meaning no mesh
func roll(model: ModularModel) -> Dictionary:
	configure(model)
	var body: Dictionary = {}
	for part: int in model.get_body_parts(): body[part] = ResourceId.of(model.get_part(part).mesh)
	return body
