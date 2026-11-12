@icon("uid://bkxn2uupbbt34")
class_name PlayerStateDefault
extends PlayerState

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_default_phantom_camera().priority = get_active_camera_priority()
	# The host starting a held ability (e.g. the lifted tile) starts aiming it
	get_controlled_character().active_ability_changed.connect(_on_active_ability_changed)
	_on_active_ability_changed.call_deferred()

func update(_delta: float) -> void:
	var available_interaction: Interaction = get_available_interaction()
	if not available_interaction: return
	if available_interaction.is_action_just_pressed():
		_on_take_control_timer_timeout()
		#_take_control_timer.start(available_interaction.type.charge_time)
	#if available_interaction.is_action_just_released():
		#_take_control_timer.stop()

func physics_update(_delta: float) -> void:
	var direction_input: Vector2 = get_direction_input()
	#get_character().move_into_direction.rpc(direction_input, delta)

func exit() -> void:
	var controlled_character: Character = get_controlled_character()
	if controlled_character.active_ability_changed.is_connected(_on_active_ability_changed):
		controlled_character.active_ability_changed.disconnect(_on_active_ability_changed)
	super.exit()
	get_default_phantom_camera().priority = get_default_camera_priority()

func _on_take_control_timer_timeout() -> void:
	_take_control()

func _on_active_ability_changed() -> void:
	if get_state_machine().get_state() != self: return
	if not get_controlled_character().active_ability_id.is_empty(): finished.emit(PlayerStateAiming.new())
