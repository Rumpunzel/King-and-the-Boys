@tool
extends EditorInspectorPlugin

## Replaces the starting equipment fields of [CharacterProfile]s with a type dropdown and carousels per slot, see [EquipmentSlotProperty],
## and the pools of [ModelConfigurationRandom]s with thumbnails to switch on and off, see [BodyPoolsProperty]

func _can_handle(object: Object) -> bool:
	return object is CharacterProfile or object is ModelConfigurationRandom

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if object is ModelConfigurationRandom:
		if name == "mesh_pools":
			add_property_editor(name, BodyPoolsProperty.new(), false, "Body Parts")
			return true
		# Edited by the pools' checkboxes
		return name == "randomized_parts"
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		if CharacterProfile.get_slot_property(slot) != name: continue
		add_property_editor(name, EquipmentSlotProperty.new(slot))
		return true
	return false
