@tool
@icon("uid://dlf5ckv713eok")
class_name ThingSpawner
extends Spawner

signal thing_created(thing: Thing)

@export_group("Configuration")

var _things: Array[Thing]

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_thing

func _ready() -> void:
	super._ready()

func spawn_all_from_spawn_spoints() -> Array[Thing]:
	assert(multiplayer.is_server())
	var all_thing_spawn_points: Array[Node] = get_tree().get_nodes_in_group("ThingSpawnPoints")
	for thing_spawn_point: ThingSpawnPoint in all_thing_spawn_points:
		spawn(thing_spawn_point.get_thing_data())
	return _things

func spawn_at(profile: ThingProfile, transform: Transform3D, status: Thing.Status) -> Array[Thing]:
	assert(multiplayer.is_server())
	assert(profile)
	var thing_data: Dictionary[StringName, Variant] = {
		Thing.VARIATION: -1,
		Thing.PROFILE_PATH: profile.resource_path,
		Thing.SPAWN_TRANSFORM: transform,
		Thing.STATUS: status,
	}
	Thing.validate_thing_data(thing_data)
	spawn(thing_data)
	return _things

func remove_all_things() -> void:
	assert(multiplayer.is_server())
	remove_all_spawned_nodes()

func remove_thing(thing: Thing) -> void:
	assert(multiplayer.is_server())
	_things.erase(thing)
	remove_child(thing)
	thing.queue_free()

func get_all_node_data() -> Array[Variant]:
	var things_data: Array[Variant] = []
	for thing: Thing in _things:
		things_data.append(thing.to_thing_data())
	return things_data

func _remove_all_data_nodes() -> Array[NodePath]:
	var removed_things_paths: Array[NodePath] = []
	while not _things.is_empty():
		var thing: Thing = _things.pop_back()
		removed_things_paths.append(thing.get_path())
		remove_thing(thing)
	return removed_things_paths

func _spawn_thing(thing_data: Dictionary[StringName, Variant]) -> Thing:
	Thing.validate_thing_data(thing_data)
	return Thing.from_thing_data(thing_data)

func _on_child_entered_tree(node: Node) -> void:
	if not node is Thing: return
	assert(not _things.has(node))
	_things.append(node)
	thing_created.emit(node)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
