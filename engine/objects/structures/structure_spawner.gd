@tool
@icon("uid://ccy2lx7al4tvu")
class_name StructureSpawner
extends Spawner

signal structure_created(structure: Structure)

@export_group("Configuration")

var _structures: Array[Structure]

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_structure

func _ready() -> void:
	super._ready()

func spawn_all_from_spawn_spoints() -> Array[Structure]:
	assert(multiplayer.is_server())
	var all_thing_spawn_points: Array[Node] = get_tree().get_nodes_in_group("StructureSpawnPoints")
	for structure_spawn_point: StructureSpawnPoint in all_thing_spawn_points:
		spawn(structure_spawn_point.get_structure_data())
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
	assert(not _structures.has(node))
	_structures.append(node)
	structure_created.emit(node)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
