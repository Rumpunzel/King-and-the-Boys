@tool
class_name CharacterEquipment
extends Node

signal equipment_changed

## {Slot: EquipmentProfile.Slot -> EquipmentProfile}
var _equipped: Dictionary[EquipmentProfile.Slot, EquipmentProfile] = {}
var _model: ModularCharacter

## Called whenever the [Character] rebuilds its [Model]; re-applies everything equipped
func apply_to(model: ModularCharacter) -> void:
	_model = model
	if not _model: return
	for equipment_profile: EquipmentProfile in _equipped.values(): _apply(equipment_profile)

func get_equipped(slot: EquipmentProfile.Slot) -> EquipmentProfile: return _equipped.get(slot)
func get_all_equipped() -> Array[EquipmentProfile]: return _equipped.values()

## @returns the equipped item blocking [param slot], or [code]null[/code]
func get_blocker(slot: EquipmentProfile.Slot) -> EquipmentProfile:
	for equipment_profile: EquipmentProfile in _equipped.values():
		if equipment_profile.blocked_slots.has(slot): return equipment_profile
	return null

func can_equip(equipment_profile: EquipmentProfile) -> bool:
	return equipment_profile != null and get_blocker(equipment_profile.slot) == null

## Replaces the item in its slot and empties the slots it blocks
## @returns [code]false[/code] if an equipped item blocks its slot
func equip(equipment_profile: EquipmentProfile) -> bool:
	if not can_equip(equipment_profile): return false
	_remove(equipment_profile.slot)
	for blocked_slot: EquipmentProfile.Slot in equipment_profile.blocked_slots: _remove(blocked_slot)
	_equipped[equipment_profile.slot] = equipment_profile
	if _model: _apply(equipment_profile)
	equipment_changed.emit()
	return true

func unequip(slot: EquipmentProfile.Slot) -> void:
	if not _equipped.has(slot): return
	_remove(slot)
	equipment_changed.emit()

func get_equipped_paths() -> PackedStringArray:
	var equipped_paths: PackedStringArray = []
	for equipment_profile: EquipmentProfile in _equipped.values(): equipped_paths.append(equipment_profile.resource_path)
	return equipped_paths

## Replaces everything equipped with the [EquipmentProfile]s at [param equipped_paths], in order
func set_equipped_paths(equipped_paths: PackedStringArray) -> void:
	unequip_all()
	for equipped_path: String in equipped_paths:
		var equipment_profile: EquipmentProfile = load(equipped_path)
		assert(equipment_profile, "No EquipmentProfile at %s!" % equipped_path)
		if not equip(equipment_profile): push_warning("%s is blocked by %s; skipped!" % [equipped_path, get_blocker(equipment_profile.slot).resource_path])

func unequip_all() -> void:
	if _equipped.is_empty(): return
	for slot: EquipmentProfile.Slot in _equipped.keys(): _remove(slot)
	equipment_changed.emit()

func _apply(equipment_profile: EquipmentProfile) -> void:
	_reset_parts(equipment_profile.get_allowed_parts())
	if equipment_profile.appearance: equipment_profile.appearance.configure(_model)

func _remove(slot: EquipmentProfile.Slot) -> void:
	var equipment_profile: EquipmentProfile = _equipped.get(slot)
	if not equipment_profile: return
	_equipped.erase(slot)
	if _model: _reset_parts(equipment_profile.get_allowed_parts())

func _reset_parts(parts: Array[ModularCharacter.Part]) -> void:
	for part: ModularCharacter.Part in parts: _model.get_part(part).reset_mesh()
