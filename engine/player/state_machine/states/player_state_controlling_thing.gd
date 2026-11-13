@icon("uid://i34bmpyalsdq")
class_name PlayerStateControllingThing
extends PlayerState

# Data dictionary keys
const CONTROLLED: StringName = "controlled"

var _controlled_path: NodePath

var _controlled: ThingHitBox
var _control_camera: PhantomCamera3D

## Default parameters are required for deserialization to work
func _init(controlled_path: NodePath = NodePath()) -> void:
	_controlled_path = controlled_path

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	var character: Character = get_character()
	_controlled = state_machine.get_node(_controlled_path)
	assert(_controlled)
	var controlled_thing: Thing = _controlled.thing
	assert(controlled_thing)
	character.hide_character.rpc(true)
	character.position = controlled_thing.position
	_control_camera = _create_control_camera()

func update(_delta: float) -> void:
	var interaction_input: StringName = get_interaction_input()
	# Taking control of another piece means releasing this one first
	if interaction_input == "release_control": finished.emit(PlayerStateDefault.new())

func exit() -> void:
	super.exit()
	assert(_controlled)
	var character: Character = get_character()
	var controlled_thing: Thing = _controlled.thing
	assert(controlled_thing)
	character.unhide_character.rpc()
	character.snap_to_grid()
	_controlled.request_release.rpc_id(Multiplayer.HOST_ID)
	_control_camera.queue_free()

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[CONTROLLED] = _controlled_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> PlayerStateControllingThing:
	super.deserialize(serialized_state)
	_controlled_path = serialized_state[CONTROLLED]
	return self
