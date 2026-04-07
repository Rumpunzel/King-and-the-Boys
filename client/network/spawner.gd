@tool
class_name Spawner
extends MultiplayerSpawner

func _ready() -> void:
	add_to_group("Spawners")

func get_spawnable_scene_paths() -> Array[String]:
	var spawnable_scene_count: int = get_spawnable_scene_count()
	var spawnable_scene_paths: Array[String] = [ ]
	for index: int in range(spawnable_scene_count):
		var spawnable_scene_path: String = get_spawnable_scene(index)
		spawnable_scene_paths.append(spawnable_scene_path)
	return spawnable_scene_paths

## @returns a [Dictionary] of scene paths to the the number of nodes of that scene
func get_all_added_nodes() -> Dictionary[StringName, int]:
	var spawn_node: Node = get_node(spawn_path)
	var added_nodes: Dictionary[StringName, int] = { }
	var spawnable_scene_paths: Array[String] = get_spawnable_scene_paths()
	for node: Node in spawn_node.get_children():
		var node_scene_path: StringName = node.scene_file_path
		if not spawnable_scene_paths.has(node_scene_path): continue
		var node_count: int = added_nodes.get_or_add(node_scene_path, 0)
		added_nodes[node_scene_path] = node_count + 1
	return added_nodes

## @returns an [Array] of all spawned node data
func get_all_node_data() -> Array[Variant]:
	assert(false, "Spawner.get_all_node_data is 'virtual' and needs to be overriden!")
	return []

func remove_all_spawned_nodes() -> Array[NodePath]:
	var freed_added_node_paths: Array[NodePath] = _remove_all_added_nodes()
	print_debug("Added nodes removed for %s: %s" % [get_path(), freed_added_node_paths])
	var freed_data_node_paths: Array[NodePath] = _remove_all_data_nodes()
	print_debug("Data nodes removed for %s: %s" % [get_path(), freed_data_node_paths])
	return freed_added_node_paths + freed_data_node_paths

func _remove_all_added_nodes() -> Array[NodePath]:
	var spawn_node: Node = get_node(spawn_path)
	var nodes_freed: Array[NodePath] = [ ]
	var spawnable_scene_paths: Array[String] = get_spawnable_scene_paths()
	for node: Node in spawn_node.get_children():
		if not spawnable_scene_paths.has(node.scene_file_path): continue
		nodes_freed.append(node.get_path())
		spawn_node.remove_child(node)
		node.queue_free()
	return nodes_freed

func _remove_all_data_nodes() -> Array[NodePath]:
	assert(false, "Spawner._remove_all_data_nodes is 'virtual' and needs to be overriden!")
	return []
