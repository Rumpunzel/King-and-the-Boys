@icon("uid://c73t2rg8wrdt3")
class_name PlayerState
extends State

## {move action: the direction it steps}
const _MOVE_ACTIONS: Dictionary[StringName, Level.Direction] = {
	&"move_up": Level.Direction.UP,
	&"move_right": Level.Direction.RIGHT,
	&"move_down": Level.Direction.DOWN,
	&"move_left": Level.Direction.LEFT,
}

var _state_machine: PlayerStateMachine
var _take_control_action: Action = preload("uid://cuoqy5wkfjika")

## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	handle_turn_input(event)

func handle_interactable(current_interactable: HitBox) -> Interaction:
	if not current_interactable: return null # Interaction.new(get_state_machine().character, _take_control_action)
	if current_interactable is CharacterHitBox: return _create_charcter_interaction(current_interactable as CharacterHitBox)
	if current_interactable is ThingHitBox: return _create_thing_interaction(current_interactable as ThingHitBox)
	return null

func get_state_machine() -> PlayerStateMachine: return _state_machine

func get_player_controller() ->  PlayerController: return get_state_machine().player_controller
func get_input_reader() ->  InputReader: return get_state_machine().input_reader
func get_character() ->  Character: return get_state_machine().character
## The [Character] the player moves in this state; their own one unless they control another
func get_controlled_character() -> Character: return get_character()
func get_hit_box() ->  CharacterHitBox: return get_state_machine().hit_box
func get_available_interaction() -> Interaction: return get_state_machine().available_interaction
func get_default_phantom_camera() ->  PhantomCamera3D: return get_state_machine().default_phantom_camera

func get_active_camera_priority() -> int: return get_state_machine().player_controller.get_active_camera_priority()
func get_default_camera_priority() -> int: return get_state_machine().player_controller.get_default_camera_priority()

func get_interaction_input() -> StringName: return get_state_machine().input_reader.interaction_input

func set_state_machine(state_machine: StateMachine) -> void:
	assert(state_machine is PlayerStateMachine)
	_state_machine = state_machine

func set_available_interaction(interaction: Interaction) -> void: get_state_machine().available_interaction = interaction

## Sends move input for the controlled [Character] to the host's [TurnManager].
## Undo and pass are the turn panel's buttons, with their actions as shortcuts.
func handle_turn_input(event: InputEvent) -> void:
	var character: Character = get_controlled_character()
	var turn_manager: TurnManager = TurnManager.get_instance(character.get_tree())
	if not turn_manager: return
	var move_presses: Dictionary[StringName, bool] = get_state_machine().move_presses
	for action: StringName in _MOVE_ACTIONS:
		if event.is_action_pressed(action): move_presses[action] = true
		# Only keys pressed in this state step
		elif event.is_action_released(action) and move_presses.erase(action):
			turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character.get_path(), _MOVE_ACTIONS[action])

func _create_charcter_interaction(current_interactable: CharacterHitBox) -> CharacterInteraction:
	return CharacterInteraction.new(get_state_machine().character, current_interactable, _take_control_action)

func _create_thing_interaction(current_interactable: ThingHitBox) -> ThingInteraction:
	return ThingInteraction.new(get_state_machine().character, current_interactable, _take_control_action)

## Asks the host to take control of the available interaction's piece; this player follows once the host agrees
func _take_control() -> void:
	var available_interaction: Interaction = get_available_interaction()
	assert(available_interaction)
	var target: HitBox = null
	if available_interaction is CharacterInteraction: target = (available_interaction as CharacterInteraction).target
	elif available_interaction is ThingInteraction: target = (available_interaction as ThingInteraction).target
	if not target: return
	var on_controlled: Callable = _on_target_controlled.bind(target)
	if not target.controlled.is_connected(on_controlled): target.controlled.connect(on_controlled, CONNECT_ONE_SHOT)
	target.request_control.rpc_id(Multiplayer.HOST_ID, get_character().get_path())

func _on_target_controlled(controller: Character, target: HitBox) -> void:
	# Someone else's grant, or this state was left meanwhile
	if controller != get_character() or get_state_machine().get_state() != self: return
	if target is CharacterHitBox: finished.emit(PlayerStateControllingCharacter.new(target.get_path()))
	elif target is ThingHitBox: finished.emit(PlayerStateControllingThing.new(target.get_path()))

func _create_control_camera() -> PhantomCamera3D:
	var state_machine: PlayerStateMachine = get_state_machine()
	var character: Character = get_character()
	var control_camera: PhantomCamera3D = state_machine.control_phantom_camera_scene.instantiate()
	control_camera.append_follow_targets(character)
	control_camera.append_look_at_target(character)
	control_camera.priority = get_active_camera_priority()
	state_machine.add_child(control_camera)
	return control_camera
