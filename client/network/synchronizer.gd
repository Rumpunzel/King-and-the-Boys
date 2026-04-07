class_name Synchronizer
extends MultiplayerSynchronizer

## @returns a [Dictionary] with the parameter as [NodePath] to the value as a [Variant]
func collect_properties(serializer: PropertiesSerializer, include_non_spawn: bool = false) -> Dictionary[NodePath, Variant]:
	var properties_to_serialize: Array[NodePath] = replication_config.get_properties()
	var properties_dict: Dictionary[NodePath, Variant] = { }
	for root_relative_property_path: NodePath in properties_to_serialize:
		var spawn_property: bool = replication_config.property_get_spawn(root_relative_property_path)
		if not include_non_spawn and not spawn_property: continue
		assert(include_non_spawn or spawn_property)
		var root_relative_node_path: StringName = root_relative_property_path.get_concatenated_names()
		var node_path: NodePath = NodePath("%s/%s/%s" % [serializer.get_path_to(self), root_path, root_relative_node_path.trim_prefix(".")])
		var node: Node = serializer.get_node(node_path)
		assert(node)
		var property_node_path: StringName = root_relative_property_path.get_concatenated_subnames()
		var property_value: Variant = node.get_indexed(NodePath(property_node_path))
		var property_path: NodePath = NodePath("%s:%s" % [node_path, property_node_path])
		assert(serializer.has_node_and_resource(property_path), "property_path %s is not a valid path!" % property_path)
		properties_dict[property_path] = property_value
	return properties_dict
