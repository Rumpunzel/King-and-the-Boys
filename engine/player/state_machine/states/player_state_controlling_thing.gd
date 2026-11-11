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
	_controlled.take_control.rpc(character.get_path())
	var input_force: Vector3 = character.get_heads_up_anchor() - controlled_thing.position
	character.hide_character.rpc(true)
	character.position = controlled_thing.position
	get_interaction_area().add_hit_box_to_ignore(_controlled)
	_control_camera = _create_control_camera()

func update(_delta: float) -> void:
	var interaction_input: StringName = get_interaction_input()
	if interaction_input == "release_control":
		finished.emit(PlayerStateDefault.new())
		return
	var available_interaction: Interaction = get_available_interaction()
	if not available_interaction: return
	if available_interaction.is_action_just_pressed():
		_on_take_control_timer_timeout()
		#_take_control_timer.start(available_action.type.charge_time)
	#if available_action.is_action_just_released():
		#_take_control_timer.stop()

func physics_update(_delta: float) -> void:
	assert(_controlled)
	var direction_input: Vector2 = get_direction_input()
	var character: Character = get_character()
	var controlled_thing: Thing = _controlled.thing
	var input_force: Vector3 = character.get_heads_up_anchor() - controlled_thing.position
	var horizontal_offset: Vector2 = Vector2(input_force.x, input_force.z)
	var adjusted_direction_input: Vector2 = direction_input - (horizontal_offset * controlled_thing.mass / 100.0)

func exit() -> void:
	super.exit()
	assert(_controlled)
	var character: Character = get_character()
	var controlled_thing: Thing = _controlled.thing
	assert(controlled_thing)
	character.unhide_character.rpc()
	character.snap_to_grid()
	_controlled.release_control.rpc()
	get_interaction_area().remove_hit_box_to_ignore(_controlled)
	_control_camera.queue_free()

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[CONTROLLED] = _controlled_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> PlayerStateControllingThing:
	super.deserialize(serialized_state)
	_controlled_path = serialized_state[CONTROLLED]
	return self

func _on_take_control_timer_timeout() -> void:
	_take_control()
