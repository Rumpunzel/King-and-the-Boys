@tool
class_name PlayerStateMachine
extends StateMachine

signal available_interactions_changed(available_interactions: Array[Interaction])

@export_group("Configuration")
@export var player_ghost: PlayerGhost
@export var input_reader: InputReader
@export var character: Character
@export var hit_box: CharacterHitBox
@export var interaction_area: InteractionArea
@export var default_phantom_camera: PhantomCamera3D

@export var haunt_phantom_camera_scene: PackedScene

var available_interaction: Interaction:
	set(new_available_interaction):
		available_interaction = new_available_interaction
		var available_interactions: Array[Interaction] = []
		if available_interaction: available_interactions.append(available_interaction)
		available_interactions_changed.emit(available_interactions)

var _state: PlayerState

func handle_input(event: InputEvent) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	get_state().handle_input(event)

func handle_interactable(current_interactable: HitBox) -> void:
	if _status == Status.STOPPED: return
	assert(_status == Status.RUNNING)
	available_interaction = get_state().handle_interactable(current_interactable)

func get_state() -> PlayerState:
	return _state

func set_state(state: State) -> void:
	assert(state is PlayerState)
	_state = state
	_state.set_state_machine(self)

func _on_current_interactable_changed(current_interactable: HitBox) -> void:
	handle_interactable(current_interactable)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not player_ghost: warnings.append("Missing PlayerGhost reference.")
	if not input_reader: warnings.append("Missing InputReader reference.")
	if not interaction_area: warnings.append("Missing InteractionArea reference.")
	if not default_phantom_camera: warnings.append("Missing default PhantomCamera3D reference.")
	if not haunt_phantom_camera_scene: warnings.append("Missing haunt phantom camera scene.")
	return warnings + super._get_configuration_warnings()
