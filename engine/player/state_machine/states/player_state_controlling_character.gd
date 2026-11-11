@icon("uid://i34bmpyalsdq")
class_name PlayerStateControllingCharacter
extends PlayerState

# Data dictionary keys
const CONTROLLED: StringName = "controlled"

var _controlled_path: NodePath

var _controlled: CharacterHitBox
var _control_camera: PhantomCamera3D

## Default parameters are required for deserialization to work
func _init(controlled_path: NodePath = NodePath()) -> void:
	_controlled_path = controlled_path

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	var character: Character = get_character()
	_controlled = state_machine.get_node(_controlled_path)
	assert(_controlled)
	var controlled_character: Character = _controlled.character
	assert(controlled_character)
	var interaction_area: InteractionArea = get_interaction_area()
	character.hide_character.rpc()
	interaction_area.add_hit_box_to_ignore(_controlled)
	interaction_area.configure_collision_shape(controlled_character.profile)
	_control_camera = _create_control_camera()
	_control_camera.append_follow_targets(controlled_character)
	_control_camera.append_look_at_target(controlled_character)

func update(_delta: float) -> void:
	var interaction_input: StringName = get_interaction_input()
	# Taking control of another piece means releasing this one first
	if interaction_input == "release_control": finished.emit(PlayerStateDefault.new())

func physics_update(_delta: float) -> void:
	assert(_controlled)
	var direction_input: Vector2 = get_direction_input()
	var character: Character = get_character()
	var controlled_character: Character = _controlled.character
	assert(controlled_character)
	character.transform = controlled_character.transform

func get_controlled_character() -> Character:
	# Resolved from the path, so it also works before enter()
	var controlled: CharacterHitBox = get_state_machine().get_node_or_null(_controlled_path)
	return controlled.character if controlled else get_character()

func exit() -> void:
	super.exit()
	assert(_controlled)
	var character: Character = get_character()
	var controlled_character: Character = _controlled.character
	assert(controlled_character)
	var interaction_area: InteractionArea = get_interaction_area()
	character.velocity = controlled_character.velocity
	character.unhide_character.rpc()
	character.snap_to_grid()
	_controlled.request_release.rpc_id(Multiplayer.HOST_ID)
	interaction_area.remove_hit_box_to_ignore(_controlled)
	interaction_area.configure_collision_shape(character.profile)
	_control_camera.queue_free()

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[CONTROLLED] = _controlled_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> PlayerStateControllingCharacter:
	super.deserialize(serialized_state)
	_controlled_path = serialized_state[CONTROLLED]
	return self
