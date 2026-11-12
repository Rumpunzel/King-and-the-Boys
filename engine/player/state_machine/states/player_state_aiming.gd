@icon("uid://bkxn2uupbbt34")
class_name PlayerStateAiming
extends PlayerState
## The controlled character holds an ability in use (see [member Character.active_ability_id], set by the host):
## the player turns it (or points it with the move keys), sets it down or cancels it; moving is off. Left once the host ends the held ability.

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_default_phantom_camera().priority = get_active_camera_priority()
	get_controlled_character().active_ability_changed.connect(_on_active_ability_changed)
	# Restored from a save or a late sync, the host may hold nothing any more
	_on_active_ability_changed.call_deferred()

func exit() -> void:
	var controlled_character: Character = get_controlled_character()
	if controlled_character.active_ability_changed.is_connected(_on_active_ability_changed):
		controlled_character.active_ability_changed.disconnect(_on_active_ability_changed)
	super.exit()
	get_default_phantom_camera().priority = get_default_camera_priority()

func handle_input(event: InputEvent) -> void:
	var player_controller: PlayerController = get_player_controller()
	if event.is_action_pressed("rotate_left"): player_controller.adjust_ability(-1)
	elif event.is_action_pressed("rotate_right"): player_controller.adjust_ability(1)
	elif event.is_action_pressed("confirm_ability"): player_controller.confirm_ability()
	elif event.is_action_pressed("cancel_ability"): player_controller.cancel_ability()
	elif event.is_action_pressed("move_up"): player_controller.aim_ability_towards(Level.Direction.UP)
	elif event.is_action_pressed("move_right"): player_controller.aim_ability_towards(Level.Direction.RIGHT)
	elif event.is_action_pressed("move_down"): player_controller.aim_ability_towards(Level.Direction.DOWN)
	elif event.is_action_pressed("move_left"): player_controller.aim_ability_towards(Level.Direction.LEFT)

func _on_active_ability_changed() -> void:
	if get_state_machine().get_state() != self: return
	if get_controlled_character().active_ability_id.is_empty(): finished.emit(PlayerStateDefault.new())
