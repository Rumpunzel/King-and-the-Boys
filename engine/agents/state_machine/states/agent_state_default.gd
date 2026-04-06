class_name AgentStateDefault
extends AgentState

var _patrol_route: Array[Vector3] = [
	Vector3(10.0, 0.0, 10.0),
	Vector3(-10.0, 0.0, 10.0),
	Vector3(-10.0, 0.0, -10.0),
	Vector3(10.0, 0.0, -10.0),
]

var _patrol_index: int = -1

func enter(state_machine: StateMachine, previous_state: State = null) -> void:
	super.enter(state_machine, previous_state)
	var character: Character = get_character()
	character.destination_reached.connect(_on_character_destination_reached)
	var distance_to_nearest: float = INF
	for patrol_index: int in _patrol_route.size():
		var patrol_position: Vector3 = _patrol_route[patrol_index]
		var distance_to_point: float = character.position.distance_squared_to(patrol_position)
		if distance_to_point < distance_to_nearest:
			_patrol_index = patrol_index
			distance_to_nearest = distance_to_point
	if _patrol_index >= 0: character.move_to_position(_patrol_route[_patrol_index])
	get_hit_box().haunted.connect(_on_haunted)

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func exit() -> void:
	super.exit()
	get_hit_box().haunted.disconnect(_on_haunted)

func _on_character_destination_reached() -> void:
	if _patrol_index < 0: return
	_patrol_index = (_patrol_index + 1) % _patrol_route.size()
	get_character().move_to_position(_patrol_route[_patrol_index])

func _on_haunted(haunting: Character) -> void:
	finished.emit(AgentStateHaunted.new(haunting.get_path()))
