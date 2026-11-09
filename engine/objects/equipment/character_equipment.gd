@tool
class_name CharacterEquipment
extends Node

signal equipment_changed

## [ResourceId]s of everything equipped, replicated by the server through the EquipmentSynchronizer; setting it re-equips everything
var equipped_ids: PackedStringArray:
	get: return get_equipped_ids()
	set(new_equipped_ids): set_equipped_ids(new_equipped_ids)

## {Slot: EquipmentLook.Slot -> EquipmentLook}
var _equipped: Dictionary[EquipmentLook.Slot, EquipmentLook] = {}
var _model: ModularModel

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	# A [PlayerGhost] hands its whole subtree to its player, but equipment stays server authoritative
	set_multiplayer_authority(MultiplayerPeer.TARGET_PEER_SERVER)

## Asks the server to equip; the result reaches every peer through [member equipped_ids]
func request_equip(equipment_look: EquipmentLook) -> void:
	var equipment_id: String = ResourceId.of(equipment_look)
	assert(not equipment_id.is_empty(), "Only saved EquipmentProfiles can be requested!")
	_request_equip.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, equipment_id)

## Asks the server to unequip; the result reaches every peer through [member equipped_ids]
func request_unequip(slot: EquipmentLook.Slot) -> void:
	_request_unequip.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, slot)

## Called whenever the [Character] rebuilds its [Model]; re-applies everything equipped
func apply_to(model: ModularModel) -> void:
	_model = model
	if not _model: return
	for equipment_look: EquipmentLook in _equipped.values():
		if equipment_look.type.fits(_model): _apply(equipment_look)
		else: push_warning("%s does not fit %s; not shown!" % [equipment_look.name, _model.scene_file_path])

func get_equipped(slot: EquipmentLook.Slot) -> EquipmentLook: return _equipped.get(slot)
func get_all_equipped() -> Array[EquipmentLook]: return _equipped.values()

## @returns the equipped item blocking [param slot], or [code]null[/code]
func get_blocker(slot: EquipmentLook.Slot) -> EquipmentLook:
	for equipment_look: EquipmentLook in _equipped.values():
		if equipment_look.blocked_slots.has(slot): return equipment_look
	return null

## Refused while another item blocks its slot, or once a model is shown that the item was not made for (e.g. dwarf gear on a human)
func can_equip(equipment_look: EquipmentLook) -> bool:
	if not equipment_look or not equipment_look.type or get_blocker(equipment_look.slot): return false
	return not _model or equipment_look.type.fits(_model)

## Replaces the item in its slot and empties the slots it blocks
## @returns [code]false[/code] if it cannot be equipped, see [method can_equip]
func equip(equipment_look: EquipmentLook) -> bool:
	if not can_equip(equipment_look): return false
	_remove(equipment_look.slot)
	for blocked_slot: EquipmentLook.Slot in equipment_look.blocked_slots: _remove(blocked_slot)
	_equipped[equipment_look.slot] = equipment_look
	if _model: _apply(equipment_look)
	equipment_changed.emit()
	return true

func unequip(slot: EquipmentLook.Slot) -> void:
	if not _equipped.has(slot): return
	_remove(slot)
	equipment_changed.emit()

func get_equipped_ids() -> PackedStringArray:
	return PackedStringArray(ResourceId.of_each(_equipped.values()))

## Replaces everything equipped with the [EquipmentLook]s [param new_equipped_ids] name, in order
## Plain paths from older saves still work, as [method ResourceId.find] loads them too
func set_equipped_ids(new_equipped_ids: PackedStringArray) -> void:
	if new_equipped_ids == get_equipped_ids(): return
	unequip_all()
	for equipment_id: String in new_equipped_ids:
		var equipment_look: EquipmentLook = ResourceId.find(equipment_id) as EquipmentLook
		if not equipment_look:
			push_error("No EquipmentLook for %s; skipped!" % equipment_id)
			continue
		if not equip(equipment_look): push_warning("%s is blocked by %s or does not fit the model; skipped!" % [equipment_id, ResourceId.of(get_blocker(equipment_look.slot))])

func unequip_all() -> void:
	if _equipped.is_empty(): return
	for slot: EquipmentLook.Slot in _equipped.keys(): _remove(slot)
	equipment_changed.emit()

## @returns whether a peer may name [param equipment_id]: it must point into the item directory
static func is_requestable(equipment_id: String) -> bool:
	var file_path: String = ResourceId.get_file_path(equipment_id)
	return not file_path.is_empty() and file_path.simplify_path().begins_with(EquipmentLook.ITEM_DIRECTORY + "/")

@rpc("any_peer", "call_local", "reliable")
func _request_equip(equipment_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	# Never trust a peer's ID: only load EquipmentProfiles from the item directory
	if not is_requestable(equipment_id):
		push_warning("Peer %d requested equipment outside %s: %s; refused!" % [sender_id, EquipmentLook.ITEM_DIRECTORY, equipment_id])
		return
	var equipment_look: EquipmentLook = ResourceId.find(equipment_id) as EquipmentLook
	if not equipment_look:
		push_warning("Peer %d requested %s, which is no EquipmentLook; refused!" % [sender_id, equipment_id])
		return
	if not equipment_look.allowed:
		push_warning("Peer %d requested %s, which is not allowed; refused!" % [sender_id, equipment_id])
		return
	if not equip(equipment_look): print_debug("Peer %d requested %s, but its slot is blocked or it does not fit; refused!" % [sender_id, equipment_id])

@rpc("any_peer", "call_local", "reliable")
func _request_unequip(slot: int) -> void:
	if not multiplayer.is_server(): return
	if not EquipmentLook.Slot.values().has(slot):
		push_warning("Peer %d requested to unequip unknown slot %d; refused!" % [multiplayer.get_remote_sender_id(), slot])
		return
	unequip(slot as EquipmentLook.Slot)

func _apply(equipment_look: EquipmentLook) -> void:
	_reset_parts(equipment_look.get_reset_parts())
	if equipment_look.appearance: equipment_look.appearance.configure(_model)

func _remove(slot: EquipmentLook.Slot) -> void:
	var equipment_look: EquipmentLook = _equipped.get(slot)
	if not equipment_look: return
	_equipped.erase(slot)
	if _model and equipment_look.type.fits(_model): _reset_parts(equipment_look.get_reset_parts())

func _reset_parts(parts: Array[int]) -> void:
	for part: int in parts: _model.get_part(part).reset_mesh()
