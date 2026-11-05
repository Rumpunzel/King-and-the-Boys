@tool
class_name CharacterEquipment
extends Node

signal equipment_changed

## [ResourceId]s of everything equipped, replicated by the server through the EquipmentSynchronizer; setting it re-equips everything
var equipped_ids: PackedStringArray:
	get: return get_equipped_ids()
	set(new_equipped_ids): set_equipped_ids(new_equipped_ids)

## {Slot: EquipmentProfile.Slot -> EquipmentProfile}
var _equipped: Dictionary[EquipmentProfile.Slot, EquipmentProfile] = {}
var _model: ModularCharacter

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	# A [PlayerGhost] hands its whole subtree to its player, but equipment stays server authoritative
	set_multiplayer_authority(MultiplayerPeer.TARGET_PEER_SERVER)

## Asks the server to equip; the result reaches every peer through [member equipped_ids]
func request_equip(equipment_profile: EquipmentProfile) -> void:
	var equipment_id: String = ResourceId.of(equipment_profile)
	assert(not equipment_id.is_empty(), "Only saved EquipmentProfiles can be requested!")
	_request_equip.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, equipment_id)

## Asks the server to unequip; the result reaches every peer through [member equipped_ids]
func request_unequip(slot: EquipmentProfile.Slot) -> void:
	_request_unequip.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, slot)

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

func get_equipped_ids() -> PackedStringArray:
	return PackedStringArray(ResourceId.of_each(_equipped.values()))

## Replaces everything equipped with the [EquipmentProfile]s [param new_equipped_ids] name, in order
## Plain paths from older saves still work, as [method ResourceId.find] loads them too
func set_equipped_ids(new_equipped_ids: PackedStringArray) -> void:
	if new_equipped_ids == get_equipped_ids(): return
	unequip_all()
	for equipment_id: String in new_equipped_ids:
		var equipment_profile: EquipmentProfile = ResourceId.find(equipment_id) as EquipmentProfile
		if not equipment_profile:
			push_error("No EquipmentProfile for %s; skipped!" % equipment_id)
			continue
		if not equip(equipment_profile): push_warning("%s is blocked by %s; skipped!" % [equipment_id, ResourceId.of(get_blocker(equipment_profile.slot))])

func unequip_all() -> void:
	if _equipped.is_empty(): return
	for slot: EquipmentProfile.Slot in _equipped.keys(): _remove(slot)
	equipment_changed.emit()

## @returns whether a peer may name [param equipment_id]: it must point into the item directory
static func is_requestable(equipment_id: String) -> bool:
	var file_path: String = ResourceId.get_file_path(equipment_id)
	return not file_path.is_empty() and file_path.simplify_path().begins_with(EquipmentProfile.ITEM_DIRECTORY + "/")

@rpc("any_peer", "call_local", "reliable")
func _request_equip(equipment_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	# Never trust a peer's ID: only load EquipmentProfiles from the item directory
	if not is_requestable(equipment_id):
		push_warning("Peer %d requested equipment outside %s: %s; refused!" % [sender_id, EquipmentProfile.ITEM_DIRECTORY, equipment_id])
		return
	var equipment_profile: EquipmentProfile = ResourceId.find(equipment_id) as EquipmentProfile
	if not equipment_profile:
		push_warning("Peer %d requested %s, which is no EquipmentProfile; refused!" % [sender_id, equipment_id])
		return
	if not equip(equipment_profile): print_debug("Peer %d requested %s, but its slot is blocked; refused!" % [sender_id, equipment_id])

@rpc("any_peer", "call_local", "reliable")
func _request_unequip(slot: int) -> void:
	if not multiplayer.is_server(): return
	if not EquipmentProfile.Slot.values().has(slot):
		push_warning("Peer %d requested to unequip unknown slot %d; refused!" % [multiplayer.get_remote_sender_id(), slot])
		return
	unequip(slot as EquipmentProfile.Slot)

func _apply(equipment_profile: EquipmentProfile) -> void:
	_reset_parts(equipment_profile.get_reset_parts())
	if equipment_profile.appearance: equipment_profile.appearance.configure(_model)

func _remove(slot: EquipmentProfile.Slot) -> void:
	var equipment_profile: EquipmentProfile = _equipped.get(slot)
	if not equipment_profile: return
	_equipped.erase(slot)
	if _model: _reset_parts(equipment_profile.get_reset_parts())

func _reset_parts(parts: Array[ModularCharacter.Part]) -> void:
	for part: ModularCharacter.Part in parts: _model.get_part(part).reset_mesh()
