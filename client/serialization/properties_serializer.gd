@tool
@icon("uid://bwsawlgvt1651")
class_name PropertiesSerializer
extends Node

enum Type {
	## Properties will be restored normally
	NORMAL = 0,
	## Marks this serliazier as unreliable, such as multiplayer peers
	## Will try to restore normally and then potentialy restor asynchronously if not found
	INTANGIBLE = 64,
	## Marks the root of this serliazier as unreliable and important, such as state data of multiplayer peers
	## Will try to restore normally and discard if not found
	EPHEMERAL = 128,
}

@export var type: Type = Type.NORMAL

## Lower [code]restoriation_order[/code] will be restored first
## If [code]<0[/code] order is based on [code]type[/code]
@export var _restoriation_order: int = -1

@export_group("Configuration")
@export var properties_to_serialize: Array[NodePath]

var restoriation_order: int:
	get: return _restoriation_order if _restoriation_order >=0 else type

func _ready() -> void:
	add_to_group("SerializersProperties")

## Collects all properties
## @returns a [Dictionary] with [int]s representing the restoration orde to a [Dictionary] [NodePath]s of the responsible [PropertiesSerializer] to the properties data
static func collect_all_properties(properties_serializers: Array[Node]) -> Dictionary[int, Dictionary]:
	var properties: Dictionary[int, Dictionary] = { }
	for properties_serializer: PropertiesSerializer in properties_serializers:
		# Properties are collected in a [Dictionary] with the parameter as [NodePath] to the value as a [Variant]
		var restoration_order: int = properties_serializer.restoriation_order
		var properties_data_for_restoration_order: Dictionary[NodePath, Dictionary] = properties.get_or_add(restoration_order, { } as Dictionary[NodePath, Dictionary])
		var collected_properties: Dictionary[NodePath, Variant] = properties_serializer.collect_properties()
		properties_data_for_restoration_order[properties_serializer.get_path()] = collected_properties
		properties[restoration_order] = properties_data_for_restoration_order
	return properties

## @returns a [Dictionary] with the parameter as [NodePath] to the value as a [Variant]
func collect_properties() -> Dictionary[NodePath, Variant]:
	var properties_dict: Dictionary[NodePath, Variant] = { }
	for property_path: NodePath in properties_to_serialize:
		assert(has_node_and_resource(property_path), "property_path %s is not a valid path!" % property_path)
		var node_path: StringName = property_path.get_concatenated_names()
		var node: Node = get_node(NodePath(node_path))
		assert(node, "node_path %s is not a node!" % node_path)
		var property_node_path: StringName = property_path.get_concatenated_subnames()
		var property_value: Variant = node.get_indexed(NodePath(property_node_path))
		properties_dict[property_path] = property_value
	return properties_dict

func restore_state(collected_properties: Dictionary[NodePath, Variant]) -> void:
	for property_path: NodePath in collected_properties:
		var node_path: NodePath = NodePath(property_path.get_concatenated_names())
		var node: Node = get_node(node_path)
		assert(node, "node_path %s is not a node!" % node_path)
		var property_node_path: NodePath = NodePath(property_path.get_concatenated_subnames())
		var property_value: Variant = collected_properties[property_path]
		node.set_indexed(property_node_path, property_value)
		assert(node.is_inside_tree())
		assert(node.get_indexed(property_node_path) == property_value, "property_path %s does not exist in %s" % [property_path, node.get_path()])
	print_debug("Restored %s properties for %s" % [collected_properties, get_path()])

func serialize(save_file_path: StringName) -> Error:
	assert(save_file_path.is_absolute_path())
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.WRITE)
	if not save_file: return FileAccess.get_open_error()
	var collected_properties: Dictionary[NodePath, Variant] = collect_properties()
	assert(collected_properties is Dictionary[NodePath, Variant])
	var serialized_properties: String = Serializer.encode_data(collected_properties)
	save_file.store_line(serialized_properties)
	return Error.OK

func deserialize(save_file_path: StringName) -> Error:
	assert(FileAccess.file_exists(save_file_path))
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.READ)
	if not save_file: return FileAccess.get_open_error()
	var serialized_properties: String = save_file.get_as_text()
	var collected_properties: Dictionary[NodePath, Variant] = Serializer.decode_data(serialized_properties)
	assert(collected_properties is Dictionary[NodePath, Variant])
	restore_state(collected_properties)
	return Error.OK

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	return warnings
