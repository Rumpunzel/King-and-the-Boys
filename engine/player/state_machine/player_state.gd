@icon("uid://c73t2rg8wrdt3")
class_name PlayerState
extends State

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
func get_interaction_area() ->  InteractionArea: return get_state_machine().interaction_area
func get_available_interaction() -> Interaction: return get_state_machine().available_interaction
func get_default_phantom_camera() ->  PhantomCamera3D: return get_state_machine().default_phantom_camera

func get_active_camera_priority() -> int: return get_state_machine().player_controller.get_active_camera_priority()
func get_default_camera_priority() -> int: return get_state_machine().player_controller.get_default_camera_priority()

func get_direction_input() -> Vector2: return get_state_machine().input_reader.get_camera_adjusted_direction_input()
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
	var character_path: NodePath = character.get_path()
	if event.is_action_released("move_up"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.UP)
	elif event.is_action_released("move_right"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.RIGHT)
	elif event.is_action_released("move_down"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.DOWN)
	elif event.is_action_released("move_left"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.LEFT)

func _create_charcter_interaction(current_interactable: CharacterHitBox) -> CharacterInteraction:
	return CharacterInteraction.new(get_state_machine().character, current_interactable, _take_control_action)

func _create_thing_interaction(current_interactable: ThingHitBox) -> ThingInteraction:
	return ThingInteraction.new(get_state_machine().character, current_interactable, _take_control_action)

func _take_control() -> void:
	var available_interaction: Interaction = get_available_interaction()
	assert(available_interaction)
	if available_interaction is CharacterInteraction: _take_control_of_character(available_interaction as CharacterInteraction)
	elif available_interaction is ThingInteraction: _take_control_of_thing(available_interaction as ThingInteraction)

func _take_control_of_character(interaction: CharacterInteraction) -> void:
	assert(interaction)
	assert(interaction is CharacterInteraction)
	finished.emit(PlayerStateControllingCharacter.new(interaction.target.get_path()))

func _take_control_of_thing(interaction: ThingInteraction) -> void:
	assert(interaction)
	assert(interaction is ThingInteraction)
	finished.emit(PlayerStateControllingThing.new(interaction.target.get_path()))

func _create_control_camera() -> PhantomCamera3D:
	var state_machine: PlayerStateMachine = get_state_machine()
	var character: Character = get_character()
	var control_camera: PhantomCamera3D = state_machine.control_phantom_camera_scene.instantiate()
	control_camera.append_follow_targets(character)
	control_camera.append_look_at_target(character)
	control_camera.priority = get_active_camera_priority()
	state_machine.add_child(control_camera)
	return control_camera
