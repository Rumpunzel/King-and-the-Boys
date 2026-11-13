@icon("uid://bkxn2uupbbt34")
class_name PlayerStateDefault
extends PlayerState

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	get_default_phantom_camera().priority = get_active_camera_priority()
	# The host starting a held ability (e.g. the lifted tile) starts aiming it
	get_character().active_ability_changed.connect(_on_active_ability_changed)
	_on_active_ability_changed.call_deferred()

func exit() -> void:
	var character: Character = get_character()
	if character.active_ability_changed.is_connected(_on_active_ability_changed):
		character.active_ability_changed.disconnect(_on_active_ability_changed)
	super.exit()
	get_default_phantom_camera().priority = get_default_camera_priority()

func _on_active_ability_changed() -> void:
	if get_state_machine().get_state() != self: return
	if not get_character().active_ability_id.is_empty(): finished.emit(PlayerStateAiming.new())
