@icon("uid://c73t2rg8wrdt3")
class_name PlayerState
extends State

var _state_machine: PlayerStateMachine

## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	handle_turn_input(event)

func handle_interactable(current_interactable: HitBox) -> Interaction:
	if not current_interactable: return null # Interaction.new(get_state_machine().character, _haunt_action)
	if current_interactable is CharacterHitBox: return _create_charcter_interaction(current_interactable as CharacterHitBox)
	if current_interactable is ThingHitBox: return _create_thing_interaction(current_interactable as ThingHitBox)
	return null

func get_state_machine() -> PlayerStateMachine: return _state_machine

func get_player_ghost() ->  PlayerGhost: return get_state_machine().player_ghost
func get_input_reader() ->  InputReader: return get_state_machine().input_reader
func get_character() ->  Character: return get_state_machine().character
## The [Character] the player moves in this state; their own one unless they control another
func get_controlled_character() -> Character: return get_character()
func get_hit_box() ->  CharacterHitBox: return get_state_machine().hit_box
func get_interaction_area() ->  InteractionArea: return get_state_machine().interaction_area
func get_available_interaction() -> Interaction: return get_state_machine().available_interaction
func get_default_phantom_camera() ->  PhantomCamera3D: return get_state_machine().default_phantom_camera

func get_active_camera_priority() -> int: return get_state_machine().player_ghost.get_active_camera_priority()
func get_default_camera_priority() -> int: return get_state_machine().player_ghost.get_default_camera_priority()

func get_direction_input() -> Vector2: return get_state_machine().input_reader.get_camera_adjusted_direction_input()
func get_interaction_input() -> StringName: return get_state_machine().input_reader.interaction_input

func set_state_machine(state_machine: StateMachine) -> void:
	assert(state_machine is PlayerStateMachine)
	_state_machine = state_machine

func set_available_interaction(interaction: Interaction) -> void: get_state_machine().available_interaction = interaction

var _haunt_action: Action = preload("uid://cuoqy5wkfjika")

## Sends move, undo and pass input for the controlled [Character] to the host's [TurnManager]
func handle_turn_input(event: InputEvent) -> void:
	var character: Character = get_controlled_character()
	var turn_manager: TurnManager = TurnManager.get_instance(character.get_tree())
	if not turn_manager: return
	var character_path: NodePath = character.get_path()
	if event.is_action_released("move_up"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.UP)
	elif event.is_action_released("move_right"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.RIGHT)
	elif event.is_action_released("move_down"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.DOWN)
	elif event.is_action_released("move_left"): turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character_path, Level.Direction.LEFT)
	elif event.is_action_released("undo_move"):
		# Undoing takes a pass back first, e.g. one made by auto-pass
		if turn_manager.has_passed(character.multiplayer.get_unique_id()): turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, false)
		turn_manager.request_undo.rpc_id(Multiplayer.HOST_ID, character_path)
	elif event.is_action_released("end_turn"):
		var has_passed: bool = turn_manager.has_passed(character.multiplayer.get_unique_id())
		turn_manager.request_pass.rpc_id(Multiplayer.HOST_ID, not has_passed)

func _create_charcter_interaction(current_interactable: CharacterHitBox) -> CharacterInteraction:
	return CharacterInteraction.new(get_state_machine().character, current_interactable, _haunt_action)

func _create_thing_interaction(current_interactable: ThingHitBox) -> ThingInteraction:
	return ThingInteraction.new(get_state_machine().character, current_interactable, _haunt_action)

func _haunt() -> void:
	var available_interaction: Interaction = get_available_interaction()
	assert(available_interaction)
	if available_interaction is CharacterInteraction: _haunt_character(available_interaction as CharacterInteraction)
	elif available_interaction is ThingInteraction: _haunt_thing(available_interaction as ThingInteraction)

func _haunt_character(interaction: CharacterInteraction) -> void:
	assert(interaction)
	assert(interaction is CharacterInteraction)
	finished.emit(PlayerStateHauntingCharacter.new(interaction.target.get_path()))

func _haunt_thing(interaction: ThingInteraction) -> void:
	assert(interaction)
	assert(interaction is ThingInteraction)
	finished.emit(PlayerStateHauntingThing.new(interaction.target.get_path()))

func _create_haunt_camera() -> PhantomCamera3D:
	var state_machine: PlayerStateMachine = get_state_machine()
	var character: Character = get_character()
	var haunt_camera: PhantomCamera3D = state_machine.haunt_phantom_camera_scene.instantiate()
	haunt_camera.append_follow_targets(character)
	haunt_camera.append_look_at_target(character)
	haunt_camera.priority = get_active_camera_priority()
	state_machine.add_child(haunt_camera)
	return haunt_camera
