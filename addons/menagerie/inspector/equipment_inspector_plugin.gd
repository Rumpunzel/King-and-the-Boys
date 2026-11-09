@tool
extends EditorInspectorPlugin

## Replaces the starting equipment fields of [CharacterProfile]s with a type dropdown and carousels per slot, see [EquipmentSlotProperty]

func _can_handle(object: Object) -> bool:
	return object is CharacterProfile

func _parse_property(_object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	for slot: EquipmentLook.Slot in EquipmentLook.Slot.values():
		if CharacterProfile.get_slot_property(slot) != name: continue
		add_property_editor(name, EquipmentSlotProperty.new(slot))
		return true
	return false
