@tool
@icon("uid://c5eog0fivdu4c")
class_name NodeSerializer
extends Node

enum SpawnType {
	ADDED_NODES,
	DATA_NODES,
}

@export var _spawner: Spawner

func _ready() -> void:
	add_to_group("SerializersNodes")
	var parent: Node = get_parent()
	if not _spawner and parent is Spawner:
		_spawner = parent

## Collects all dynamically spawned nodes
## @returns a [Dictionary] with [NodePath]s of the responsible [NodeSerializer]s to the node data
static func collect_all_nodes(node_serializers: Array[Node]) -> Dictionary[NodePath, Dictionary]:
	var nodes: Dictionary[NodePath, Dictionary] = { }
	for node_serializer: NodeSerializer in node_serializers:
		# Nodes are collected in a Dictionary with scene paths to NodePaths
		var collected_spawned_nodes: Dictionary[SpawnType, Variant] = node_serializer.collect_spawned_nodes()
		nodes[node_serializer.get_path()] = collected_spawned_nodes
	return nodes

## @returns a [Dictionary] with scene paths to [NodePath]s
func collect_spawned_nodes() -> Dictionary[SpawnType, Variant]:
	assert(_spawner)
	# Nodes are collected in a Dictionary with scene paths to NodePaths
	var collected_added_nodes: Dictionary[StringName, int] = _collect_added_nodes()
	var collected_node_data: Array[Variant] = _collect_node_data()
	var collected_nodes: Dictionary[SpawnType, Variant] = {
		SpawnType.ADDED_NODES: collected_added_nodes,
		SpawnType.DATA_NODES: collected_node_data,
	}
	return collected_nodes

## @returns a [Dictionary] with scene paths to [NodePath]s
func _collect_added_nodes() -> Dictionary[StringName, int]:
	assert(_spawner)
	return _spawner.get_all_added_nodes()

## @returns a [Dictionary] with scene paths to [NodePath]s
func _collect_node_data() -> Array[Variant]:
	assert(_spawner)
	return _spawner.get_all_node_data()

func restore_state(collected_nodes: Dictionary[SpawnType, Variant]) -> void:
	assert(_spawner)
	# Clean state
	var nodes_freed: Array[NodePath] = _spawner.remove_all_spawned_nodes()
	print_debug("Removed %d nodes for %s" % [nodes_freed.size(), _spawner.get_path()])
	
	var collected_added_nodes: Dictionary[StringName, int] = collected_nodes[SpawnType.ADDED_NODES]
	assert(collected_added_nodes is Dictionary[StringName, int])
	var added_nodes_restored: Array[NodePath] = _restore_added_nodes(collected_added_nodes)
	
	var collected_data_nodes: Array[Variant] = collected_nodes[SpawnType.DATA_NODES]
	assert(collected_data_nodes is Array[Variant])
	var data_nodes_restored: Array[NodePath] = _restore_data_nodes(collected_data_nodes)
	
	print_debug("Restored %d nodes for %s" % [added_nodes_restored.size() + data_nodes_restored.size(), _spawner.get_path()])

func _restore_added_nodes(collected_added_nodes: Dictionary[StringName, int]) -> Array[NodePath]:
	var spawn_node: Node = get_node(_spawner.spawn_path)
	assert(spawn_node)
	var nodes_restored: Array[NodePath] = [ ]
	for node_scene_path: StringName in collected_added_nodes:
		var scene_to_spawn: PackedScene = load(node_scene_path)
		assert(scene_to_spawn is PackedScene)
		for _index: int in collected_added_nodes[node_scene_path]:
			var node_to_spawn: Node = scene_to_spawn.instantiate()
			spawn_node.add_child(node_to_spawn, true)
			nodes_restored.append(node_to_spawn.get_path())
	print_debug("Restored added nodes for %s: %s" % [_spawner.get_path(), nodes_restored])
	return nodes_restored

func _restore_data_nodes(collected_data_nodes: Array[Variant]) -> Array[NodePath]:
	var nodes_restored: Array[NodePath] = [ ]
	for data_node: Variant in collected_data_nodes:
		var spawned_node: Node = _spawner.spawn(data_node)
		nodes_restored.append(spawned_node.get_path())
	print_debug("Restored data nodes for %s: %s" % [_spawner.get_path(), nodes_restored])
	return nodes_restored

func serialize(save_file_path: StringName) -> Error:
	assert(save_file_path.is_absolute_path())
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.WRITE)
	var collected_spawned_nodes: Dictionary[SpawnType, Variant] = collect_spawned_nodes()
	assert(collected_spawned_nodes is Dictionary[SpawnType, Variant])
	var serialized_nodes: String = Serializer.encode_data(collected_spawned_nodes)
	save_file.store_line(serialized_nodes)
	return Error.OK

func deserialize(save_file_path: StringName) -> Error:
	assert(FileAccess.file_exists(save_file_path))
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.READ)
	var serialized_nodes: String = save_file.get_as_text()
	var collected_nodes: Dictionary[SpawnType, Variant] = Serializer.decode_data(serialized_nodes)
	assert(collected_nodes is Dictionary[SpawnType, Variant])
	restore_state(collected_nodes)
	return Error.OK

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _spawner: warnings.append("Missing Spawner reference.")
	return warnings
