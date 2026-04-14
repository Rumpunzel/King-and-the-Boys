@tool
@icon("uid://ccy2lx7al4tvu")
class_name StructureSpawner
extends Spawner

signal structure_created(structure: Structure)

@export_group("Configuration")
@export var _agent_spawner: AgentSpawner
@export var _thing_spawner: ThingSpawner

var _structures: Array[Structure]

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_structure

func _ready() -> void:
	super._ready()

func spawn_all_from_spawn_spoints() -> Array[Structure]:
	assert(multiplayer.is_server())
	var all_structure_spawn_points: Array[Node] = get_tree().get_nodes_in_group("StructureSpawnPoints")
	for structure_spawn_point: StructureSpawnPoint in all_structure_spawn_points:
		spawn(structure_spawn_point.get_structure_data())
	return _structures

func spawn_at(profile: StructureProfile, transform: Transform3D, clockwise_turns: int, status: Structure.Status) -> Array[Structure]:
	assert(multiplayer.is_server())
	assert(profile)
	var tile_data: Dictionary[StringName, Variant] = {
		Structure.VARIATION: -1,
		Structure.PROFILE_PATH: profile.resource_path,
		Structure.SPAWN_TRANSFORM: transform,
		Structure.CLOCKWISE_TURNS: clockwise_turns,
		Structure.STATUS: status,
	}
	Structure.validate_structure_data(tile_data)
	spawn(tile_data)
	return _structures

func remove_all_structures() -> void:
	assert(multiplayer.is_server())
	remove_all_spawned_nodes()

func remove_structure(structure: Structure) -> void:
	assert(multiplayer.is_server())
	_structures.erase(structure)
	remove_child(structure)
	structure.queue_free()

func get_all_node_data() -> Array[Variant]:
	var structures_data: Array[Variant] = []
	for structure: Structure in _structures:
		structures_data.append(structure.to_structure_data())
	return structures_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_structures_paths: Array[NodePath] = []
	while not _structures.is_empty():
		var structure: Structure = _structures.pop_back()
		removed_structures_paths.append(structure.get_path())
		remove_structure(structure)
	return removed_structures_paths

func _spawn_structure(structure_data: Dictionary[StringName, Variant]) -> Structure:
	Structure.validate_structure_data(structure_data)
	return Structure.from_structure_data(structure_data)

func _on_child_entered_tree(node: Node) -> void:
	if not node is Structure: return
	var structure: Structure = node
	assert(not _structures.has(structure))
	_structures.append(structure)
	structure.spawn_requested.connect(_on_spawn_requested.bind(structure))
	structure_created.emit(structure)

func _on_spawn_requested(profile_to_spawn: Profile, spawn_for: Structure) -> void:
	if profile_to_spawn is StructureProfile:
		spawn_at(profile_to_spawn as StructureProfile, spawn_for.transform, spawn_for.clockwise_turns, spawn_for.status)
	elif profile_to_spawn is ThingProfile:
		_thing_spawner.spawn_at(profile_to_spawn as ThingProfile, spawn_for.transform, Thing.structure_status_to_thing_status(spawn_for.status))
	#elif profile_to_spawn is CharacterProfile: _agent_spawner.spawn_at(profile_to_spawn as CharacterProfile, spawn_for.transform)
	else: push_error("Cannot spawn profile: %profile_to_spawn - Not implemented!" % profile_to_spawn)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _agent_spawner: warnings.append("Missing AgentSpawner reference.")
	if not _thing_spawner: warnings.append("Missing ThingSpawner reference.")
	return warnings
