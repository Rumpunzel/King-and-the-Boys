@tool
@icon("uid://ne8n58y4wim8")
class_name AgentSpawner
extends Spawner

signal agent_created(agent: Agent)

@export_group("Configuration")

var _agents: Dictionary[Character, Agent] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_agent

func _ready() -> void:
	super._ready()

func spawn_all_from_spawn_spoints() -> Dictionary[Character, Agent]:
	assert(multiplayer.is_server())
	var all_character_spawn_points: Array[Node] = get_tree().get_nodes_in_group("CharacterSpawnPoints")
	for character_spawn_point: CharacterSpawnPoint in all_character_spawn_points:
		spawn_agent(character_spawn_point.get_character_data())
	return _agents

func spawn_agent(character_data: Dictionary[StringName, Variant]) -> void:
	assert(multiplayer.is_server())
	var agent_data: Dictionary[StringName, Variant] = {
		Agent.CHARACTER_DATA: character_data,
	}
	Agent.validate_agent_data(agent_data)
	spawn(agent_data)

func remove_all_agents() -> void:
	assert(multiplayer.is_server())
	remove_all_spawned_nodes()

func remove_agent(agent: Agent) -> void:
	assert(multiplayer.is_server())
	_agents.erase(agent.character)
	remove_child(agent)
	agent.queue_free()

func get_all_node_data() -> Array[Variant]:
	var agents_data: Array[Variant] = []
	for agent: Agent in _agents.values():
		agents_data.append(agent.to_agent_data())
	return agents_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_agent_paths: Array[NodePath] = []
	for agent: Agent in _agents.values():
		removed_agent_paths.append(agent.get_path())
		remove_agent(agent)
	return removed_agent_paths

func _spawn_agent(agent_data: Dictionary[StringName, Variant]) -> Agent:
	Agent.validate_agent_data(agent_data)
	var character_data: Dictionary[StringName, Variant] = agent_data[Agent.CHARACTER_DATA]
	return Agent.create(character_data)

func _on_child_entered_tree(node: Node) -> void:
	if not node is Agent: return
	var agent: Agent = node
	_agents[agent.character] = agent
	agent_created.emit(agent)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
