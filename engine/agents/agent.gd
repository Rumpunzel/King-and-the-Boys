@tool
@icon("uid://dv6mpdxcuq5j5")
class_name Agent
extends Node

const CHARACTER_DATA: StringName = "character_data"

@export var character: Character

@export_group("Configuration")
@export var _state_machine: AgentStateMachine

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.start()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.physics_update(delta)

static func create(character_data: Dictionary[StringName, Variant]) -> Agent:
	var scene: PackedScene = load("uid://bbjgxgkshjet6")
	var new_agent: Agent = scene.instantiate()
	new_agent.character.apply_character_data(character_data)
	return new_agent

static func validate_agent_data(agent_data: Dictionary[StringName, Variant]) -> void:
	assert(agent_data.has_all([CHARACTER_DATA]))
	assert(agent_data.size() == 1)

func to_agent_data() -> Dictionary[StringName, Variant]:
	assert(character)
	var character_data: Dictionary[StringName, Variant] = character.to_character_data()
	var agent_data: Dictionary[StringName, Variant] = {
		CHARACTER_DATA: character_data,
	}
	validate_agent_data(agent_data)
	return agent_data

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _state_machine: warnings.append("Missing AgentStateMachine reference.")
	return warnings
