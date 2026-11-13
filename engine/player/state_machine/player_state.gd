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

## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	handle_turn_input(event)

func get_state_machine() -> PlayerStateMachine: return _state_machine

func get_player_controller() ->  PlayerController: return get_state_machine().player_controller
func get_character() ->  Character: return get_state_machine().character
func get_default_phantom_camera() ->  PhantomCamera3D: return get_state_machine().default_phantom_camera

func get_active_camera_priority() -> int: return get_state_machine().player_controller.get_active_camera_priority()
func get_default_camera_priority() -> int: return get_state_machine().player_controller.get_default_camera_priority()

func set_state_machine(state_machine: StateMachine) -> void:
	assert(state_machine is PlayerStateMachine)
	_state_machine = state_machine

## Sends move input for the player's [Character] to the host's [TurnManager].
## Undo and pass are the turn panel's buttons, with their actions as shortcuts.
func handle_turn_input(event: InputEvent) -> void:
	var character: Character = get_character()
	var turn_manager: TurnManager = TurnManager.get_instance(character.get_tree())
	if not turn_manager: return
	var move_presses: Dictionary[StringName, bool] = get_state_machine().move_presses
	for action: StringName in _MOVE_ACTIONS:
		if event.is_action_pressed(action): move_presses[action] = true
		# Only keys pressed in this state step
		elif event.is_action_released(action) and move_presses.erase(action):
			turn_manager.request_move.rpc_id(Multiplayer.HOST_ID, character.get_path(), _MOVE_ACTIONS[action])
