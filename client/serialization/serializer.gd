@icon("uid://lafgp3e7lvc3")
class_name Serializer
extends Node

signal saving_started
signal saving_finished

signal loading_started
signal loading_finished

const NODES: StringName = "nodes"
const PROPERTIES: StringName = "properties"

const SAVE_FILE_PATH: StringName = "res://test.save" # "user://savegame.save"

var _queued_intangible_data: Dictionary[NodePath, Dictionary] = { }

static func has_save_file(save_file_path: StringName = SAVE_FILE_PATH) -> bool:
	return FileAccess.file_exists(save_file_path)

static func encode_data(value: Variant, full_objects: bool = false) -> String:
	return JSON.stringify(JSON.from_native(value, full_objects))

static func decode_data(string: String, allow_objects: bool = false) -> Variant:
	return JSON.to_native(JSON.parse_string(string), allow_objects)

static func merge_array_dictionaries(dictionaries: Array[Dictionary]) -> Dictionary[StringName, Array]:
	var merged_dictionary: Dictionary[StringName, Array] = { }
	for dictionary: Dictionary[StringName, Array] in dictionaries:
		assert(dictionary is Dictionary[StringName, Array])
		for key: StringName in dictionary:
			var merged_arrays: Array = merged_dictionary.get_or_add(key, [ ])
			var array_to_merge: Array = dictionary[key]
			merged_arrays.append_array(array_to_merge)
			merged_dictionary[key] = merged_arrays
	return merged_dictionary

static func mark_all_child_serializers_for(node: Node, as_type: PropertiesSerializer.Type, override: bool = false) -> void:
	assert(node)
	if node is PropertiesSerializer:
		var properties_serializer: PropertiesSerializer = node
		if override or as_type > properties_serializer.type:
			properties_serializer.type = as_type
	for child: Node in node.get_children():
		mark_all_child_serializers_for(child, as_type)

func save_world_state(save_file_path: StringName = SAVE_FILE_PATH) -> Error:
	assert(save_file_path.is_absolute_path())
	saving_started.emit()
	var collected_data: Dictionary[StringName, Dictionary] = collect_data()
	var serialized_game_state: String = encode_data(collected_data)
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.WRITE)
	save_file.store_line(serialized_game_state)
	saving_finished.emit()
	return Error.OK

func load_world_state(save_file_path: StringName = SAVE_FILE_PATH) -> Error:
	if not has_save_file(save_file_path):
		printerr("Tried to load without a save file; skipped!")
		return Error.ERR_FILE_NOT_FOUND
	loading_started.emit()
	var save_file: FileAccess = FileAccess.open(save_file_path, FileAccess.READ)
	var serialized_game_state: String = save_file.get_as_text()
	var collected_data: Dictionary[StringName, Dictionary] = decode_data(serialized_game_state)
	assert(collected_data is Dictionary[StringName, Dictionary])
	restore_state(collected_data)
	loading_finished.emit()
	return Error.OK

func collect_data() -> Dictionary[StringName, Dictionary]:
	var node_serializers: Array[Node] = get_tree().get_nodes_in_group("SerializersNodes")
	var properties_serializers: Array[Node] = get_tree().get_nodes_in_group("SerializersProperties")
	var nodes: Dictionary[NodePath, Dictionary] = NodeSerializer.collect_all_nodes(node_serializers)
	var properties: Dictionary[int, Dictionary] = PropertiesSerializer.collect_all_properties(properties_serializers)
	# var intangible_data: Dictionary[NodePath, Dictionary] = properties_data.get(PropertiesSerializer.Type.INTANGIBLE, {} as Dictionary[NodePath, Dictionary])
	# properties_data[PropertiesSerializer.Type.INTANGIBLE] = intangible_data.merged(_queued_intangible_data)
	return {
		NODES: nodes,
		PROPERTIES: properties,
	}

func restore_state(collected_data: Dictionary[StringName, Dictionary]) -> void:
	assert(collected_data.has_all([NODES, PROPERTIES]))
	assert(collected_data.size() == 2)
	
	var node_data: Dictionary[NodePath, Dictionary] = collected_data[NODES]
	assert(node_data is Dictionary[NodePath, Dictionary])
	restore_nodes(node_data)
	
	var properties_data: Dictionary[int, Dictionary] = collected_data[PROPERTIES]
	assert(properties_data is Dictionary[int, Dictionary])
	restore_properties_in_restoration_order(properties_data)

func restore_nodes(node_data: Dictionary[NodePath, Dictionary]) -> void:
	for node_serializer_path: NodePath in node_data:
		var collected_nodes: Dictionary[NodeSerializer.SpawnType, Variant] = node_data[node_serializer_path]
		assert(collected_nodes is Dictionary[NodeSerializer.SpawnType, Variant])
		var node_serializer: NodeSerializer = get_node(node_serializer_path)
		assert(node_serializer)
		node_serializer.restore_state(collected_nodes)

func restore_properties_in_restoration_order(properties_data: Dictionary[int, Dictionary]) -> void:
	var restoration_order: Array[int] = properties_data.keys()
	# Ensure restoration order
	restoration_order.sort()
	for restoration_orer: int in restoration_order:
		var collected_properties: Dictionary[NodePath, Dictionary] = properties_data[restoration_orer]
		assert(collected_properties is Dictionary[NodePath, Dictionary])
		print_debug("Started restoring properties for restoration_order: %d" % restoration_orer)
		_restore_properties(collected_properties, restoration_orer)
		print_debug("Finished restoring properties for restoration_order: %d" % restoration_orer)
	if not _queued_intangible_data.is_empty(): print_debug("Queued %d intangible data..." % _queued_intangible_data.size())

func _restore_properties(properties_data: Dictionary[NodePath, Dictionary], serializer_type: PropertiesSerializer.Type) -> void:
	for properties_serializer_path: NodePath in properties_data:
		var collected_properties: Dictionary[NodePath, Variant] = properties_data[properties_serializer_path]
		assert(collected_properties is Dictionary[NodePath, Variant])
		
		var properties_serializer: PropertiesSerializer = get_node_or_null(properties_serializer_path)
		if properties_serializer:
			# [PropertiesSerializer] found, restore normally
			properties_serializer.restore_state(collected_properties)
			continue
		
		match serializer_type:
			PropertiesSerializer.Type.NORMAL:
				# This is an error and should be looked at if it occurs after development
				printerr("Could not find PropertiesSerializer at %s; skipped!" % properties_serializer_path)
			PropertiesSerializer.Type.INTANGIBLE:
				# Queue for later restoration
				_queued_intangible_data[properties_serializer_path] = collected_properties
				print_debug("Could not find PropertiesSerializer at %s; queuing restoration for later..." % properties_serializer_path)
				if not get_tree().node_added.is_connected(_on_node_added):
					get_tree().node_added.connect(_on_node_added)
					print_debug("Started listening to nodes being added...")
			PropertiesSerializer.Type.EPHEMERAL:
				# Ignore
				printerr("Could not find EPHEMERAL PropertiesSerializer at %s; skipped!" % properties_serializer_path)
			_: push_error("PropertiesSerializer.Type %s not implemented!" % serializer_type)

func _on_node_added(node: Node) -> void:
	if _queued_intangible_data.is_empty(): return
	await node.ready
	var node_path: NodePath = node.get_path()
	if not _queued_intangible_data.has(node_path): return
	print_debug("Started restoring intagle data for queued node %s!" % node_path)
	var collected_properties: Dictionary[NodePath, Variant] = _queued_intangible_data[node_path]
	assert(collected_properties is Dictionary[NodePath, Variant])
	
	var properties_serializer: PropertiesSerializer = node
	properties_serializer.restore_state(collected_properties)
	_queued_intangible_data.erase(node_path)
	if _queued_intangible_data.is_empty():
		get_tree().node_added.disconnect(_on_node_added)
		print_debug("Stopped listening to nodes being added!")
