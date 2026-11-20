@tool
@icon("uid://dv6mpdxcuq5j5")
class_name Agent
extends Node

## What the monster knows of the heroes (see [MonsterSenses]) changed: [member awareness] or [member awareness_target]
signal awareness_changed

## What the monster knows of the heroes: it notices none, hunts one it notices, or goes to look where it last noticed one
enum Awareness {
	ROAMING,
	HUNTING,
	INVESTIGATING,
}

const CHARACTER_DATA: StringName = "character_data"

@export var character: Character

@export_group("Configuration")
@export var _state_machine: AgentStateMachine

## Set by the host's [MonsterSenses]; replicated and saved by the AgentSynchronizer
var awareness: Awareness = Awareness.ROAMING:
	set(new_awareness):
		if new_awareness == awareness: return
		awareness = new_awareness
		awareness_changed.emit()
## While hunting, the cell of the hero it hunts; while investigating, where it last noticed them
var awareness_target: Vector2i = Vector2i.ZERO:
	set(new_awareness_target):
		if new_awareness_target == awareness_target: return
		awareness_target = new_awareness_target
		awareness_changed.emit()

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
	var new_agent: Agent = (Files.load_kept("uid://bbjgxgkshjet6") as PackedScene).instantiate()
	new_agent.character.apply_character_data(character_data)
	return new_agent

static func validate_agent_data(agent_data: Dictionary[StringName, Variant]) -> void:
	assert(agent_data.has_all([CHARACTER_DATA]))
	assert(agent_data.size() == 1)

## Host only, in the monster phase: the direction of the character's next step, as its current state decides;
## [code]-1[/code] to stop for this turn
func choose_step() -> int:
	return _state_machine.get_state().choose_step()

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
