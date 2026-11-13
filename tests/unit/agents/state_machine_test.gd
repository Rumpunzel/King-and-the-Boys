extends GdUnitTestSuite
## A state machine without a state (before it starts, or a player's machine on the host until its peer syncs it) and the
## state scripts peers may name in its synchronized state

func test_only_state_scripts_count_as_states() -> void:
	assert_bool(StateMachine.script_is_valid_state(null)).is_false()
	assert_bool(StateMachine.script_is_valid_state(AgentStateMachine)).is_false()
	assert_bool(StateMachine.script_is_valid_state(AgentStateDefault)).is_true()

func test_only_state_scripts_in_the_project_load() -> void:
	var default_path: String = (AgentStateDefault as GDScript).resource_path
	assert_object(State.load_state_script(default_path)).is_same(AgentStateDefault)
	assert_object(State.load_state_script((AgentStateMachine as GDScript).resource_path)).is_null()
	assert_object(State.load_state_script("user://" + default_path.get_file())).is_null()
	assert_object(State.load_state_script("res://engine/levels/level.tscn")).is_null()
	assert_object(State.load_state_script("")).is_null()

func test_a_machine_without_a_state_serializes_to_nothing() -> void:
	var machine: AgentStateMachine = auto_free(AgentStateMachine.new())
	add_child(machine)
	assert_dict(machine.get(&"_serialized_state") as Dictionary).is_empty()
	machine.set(&"_serialized_state", {} as Dictionary[StringName, Variant])
	assert_object(machine.get_state()).is_null()

func test_a_machine_takes_its_state_from_the_synchronized_one() -> void:
	var machine: AgentStateMachine = auto_free(AgentStateMachine.new())
	add_child(machine)
	var serialized: Dictionary[StringName, Variant] = AgentStateDefault.new().serialize()
	machine.set(&"_serialized_state", serialized)
	assert_object(machine.get_state()).is_instanceof(AgentStateDefault)
	machine.set_state(null)
	assert_object(machine.get_state()).is_null()
