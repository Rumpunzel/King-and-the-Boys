@tool
@icon("uid://bv63hb5gynt8d")
class_name HitBox
extends Area3D

signal controlled(controller: Character)
signal released

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D

## The [Character] controlling this piece, set by the host on every peer
var controller: Character

## Asks the host to let [param controller_path] take control of this piece; the host checks
## [method may_be_controlled_by] and tells every peer
@rpc("any_peer", "call_local", "reliable")
func request_control(controller_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var new_controller: Character = get_node_or_null(controller_path) as Character
	if not may_be_controlled_by(new_controller, _get_sender_id()): return
	_set_controller.rpc(controller_path)

## Asks the host to end control; only the controller's player may
@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if not multiplayer.is_server(): return
	if not is_instance_valid(controller) or controller.get_multiplayer_authority() != _get_sender_id(): return
	_set_controller.rpc(NodePath())

## Whether the player on [param peer_id] may take control of this piece with [param new_controller]: their own
## character, controlling nothing yet (release first), reaching this piece, which no one controls yet and which is
## no player's own character
func may_be_controlled_by(new_controller: Character, peer_id: int) -> bool:
	if is_instance_valid(controller) or not new_controller or new_controller.controlling: return false
	if new_controller.get_multiplayer_authority() != peer_id: return false
	var body: Node3D = get_body()
	if body == new_controller or body.get_parent() is PlayerController: return false
	var player_controller: PlayerController = new_controller.get_parent() as PlayerController
	return player_controller != null and player_controller.can_reach(self)

# The host's word only: peers can not hand out control themselves
@rpc("any_peer", "call_local", "reliable")
func _set_controller(controller_path: NodePath) -> void:
	if _get_sender_id() != Multiplayer.HOST_ID: return
	if is_instance_valid(controller):
		if controller.tree_exiting.is_connected(_on_controller_tree_exiting): controller.tree_exiting.disconnect(_on_controller_tree_exiting)
		controller.controlling = null
	if controller_path.is_empty():
		controller = null
		released.emit()
		return
	controller = get_node(controller_path)
	assert(controller)
	controller.controlling = self
	# A controller that leaves (disconnect, stop, load) gives its piece back
	if multiplayer.is_server(): controller.tree_exiting.connect(_on_controller_tree_exiting, CONNECT_ONE_SHOT)
	controlled.emit(controller)

func _on_controller_tree_exiting() -> void:
	_set_controller.rpc(NodePath())

func _get_sender_id() -> int:
	var sender_id: int = multiplayer.get_remote_sender_id()
	return sender_id if sender_id != 0 else multiplayer.get_unique_id()

func get_body() -> Node3D:
	assert(false, "HitBox.get_body is 'virtual' and needs to be overriden!")
	return null

func get_model() -> Model:
	assert(false, "HitBox.get_model is 'virtual' and needs to be overriden!")
	return null

func get_heads_up_anchor() -> Vector3:
	assert(false, "HitBox.get_heads_up_anchor is 'virtual' and needs to be overriden!")
	return Vector3.ZERO

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	return warnings
