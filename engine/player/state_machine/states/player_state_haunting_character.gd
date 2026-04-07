@icon("uid://bacbwgwwmvm5i")
class_name PlayerStateHauntingCharacter
extends PlayerState

# Data dictionary keys
const HAUNTED: StringName = "haunted"

var _haunted_path: NodePath

var _haunted: CharacterHitBox
var _haunt_camera: PhantomCamera3D

## Default parameters are required for deserialization to work
func _init(haunted_path: NodePath = NodePath()) -> void:
	_haunted_path = haunted_path

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	var character: Character = get_character()
	_haunted = state_machine.get_node(_haunted_path)
	assert(_haunted)
	var haunted_character: Character = _haunted.character
	assert(haunted_character)
	var interaction_area: InteractionArea = get_interaction_area()
	character.hide_character.rpc()
	_haunted.haunt.rpc(character.get_path())
	interaction_area.add_hit_box_to_ignore(_haunted)
	interaction_area.configure_collision_shape(haunted_character.profile)
	_haunt_camera = _create_haunt_camera()
	_haunt_camera.append_follow_targets(haunted_character)
	_haunt_camera.append_look_at_target(haunted_character)

func update(_delta: float) -> void:
	var interaction_input: StringName = get_interaction_input()
	if interaction_input == "unhaunt":
		finished.emit(PlayerStateDefault.new())
		return
	var available_interaction: Interaction = get_available_interaction()
	if not available_interaction: return
	if available_interaction.is_action_just_pressed():
		_on_haunt_timer_timeout()
		#_haunt_timer.start(available_action.type.charge_time)
	#if available_action.is_action_just_released():
		#_haunt_timer.stop()

func physics_update(delta: float) -> void:
	assert(_haunted)
	var direction_input: Vector2 = get_direction_input()
	var character: Character = get_character()
	var haunted_character: Character = _haunted.character
	assert(haunted_character)
	character.transform = haunted_character.transform

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	assert(_haunted)
	var character: Character = get_character()
	var haunted_character: Character = _haunted.character
	assert(haunted_character)
	var interaction_area: InteractionArea = get_interaction_area()
	character.velocity = haunted_character.velocity
	character.unhide_character.rpc()
	_haunted.unhaunt.rpc()
	interaction_area.remove_hit_box_to_ignore(_haunted)
	interaction_area.configure_collision_shape(character.profile)
	_haunt_camera.queue_free()

func serialize() -> Dictionary[StringName, Variant]:
	var serialized_state: Dictionary[StringName, Variant] = super.serialize()
	serialized_state[HAUNTED] = _haunted_path
	return serialized_state

func deserialize(serialized_state: Dictionary[StringName, Variant]) -> PlayerStateHauntingCharacter:
	super.deserialize(serialized_state)
	_haunted_path = serialized_state[HAUNTED]
	return self

func _on_haunt_timer_timeout() -> void:
	_haunt()
