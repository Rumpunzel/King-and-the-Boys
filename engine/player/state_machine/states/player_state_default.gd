class_name PlayerStateDefault
extends PlayerState

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_default_phantom_camera().priority = get_active_camera_priority()

func update(_delta: float) -> void:
	var available_interaction: Interaction = get_available_interaction()
	if not available_interaction: return
	if available_interaction.is_action_just_pressed():
		_on_haunt_timer_timeout()
		#_haunt_timer.start(available_interaction.type.charge_time)
	#if available_interaction.is_action_just_released():
		#_haunt_timer.stop()

func physics_update(delta: float) -> void:
	var direction_input: Vector2 = get_direction_input()

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	get_default_phantom_camera().priority = get_default_camera_priority()

func _on_haunt_timer_timeout() -> void:
	_haunt()
