@icon("uid://cxasgwulwayvu")
class_name ResourceId
extends RefCounted

## Names a resource so it can be found again in another run or on another peer (saves, spawn data, synchronization): its file's UID (the path if the file has none),
## plus, for a resource stored inside a file, its ID there: "uid://…::Resource_x". Resources made at runtime have no name.
## Ported from Vagrant ([code]custom_nodes/resource_id.gd[/code]).

const SEPARATOR: String = "::"

## A loaded file's index: each resource stored inside it by its ID there, as [WeakRef]s (the file holds them); by the file's instance
static var _indexes: Dictionary[int, Dictionary] = {}

## Empty for a resource made at runtime (no file)
static func of(resource: Resource) -> String:
	if resource == null or resource.resource_path.is_empty(): return ""
	var file: String = resource.resource_path.get_slice(SEPARATOR, 0)
	var uid: int = ResourceLoader.get_resource_uid(file)
	var file_id: String = ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else file
	if not resource.resource_path.contains(SEPARATOR): return file_id
	return file_id + SEPARATOR + resource.resource_scene_unique_id

## The resource [param id] names, or null if its file or its place in there is gone
static func find(id: String) -> Resource:
	if id.is_empty(): return null
	var root: Resource = Files.load_existing(id.get_slice(SEPARATOR, 0))
	if root == null or not id.contains(SEPARATOR): return root
	var inner_id: String = id.get_slice(SEPARATOR, 1)
	var found: Resource = _find_indexed(root, inner_id, false)
	# Not there: the file may have changed since it was indexed (e.g. edited in Menagerie), so once more from scratch
	if found == null: found = _find_indexed(root, inner_id, true)
	return found

## The current path of the file [param id] points into, or empty if that file is gone
static func get_file_path(id: String) -> String:
	return Files.resolve_path(id.get_slice(SEPARATOR, 0))

static func _find_indexed(root: Resource, inner_id: String, rebuild: bool) -> Resource:
	var key: int = root.get_instance_id()
	if rebuild or not _indexes.has(key):
		var index: Dictionary[String, WeakRef] = {}
		_index_inside(root, root.resource_path, index, {})
		_indexes[key] = index
	var resource_reference: WeakRef = _indexes[key].get(inner_id)
	if resource_reference == null: return null
	var found: Resource = resource_reference.get_ref()
	return found

## Godot can't load a resource stored inside a file by itself: walks what the file stores once (not into other files)
static func _index_inside(value: Variant, file: String, index: Dictionary[String, WeakRef], seen: Dictionary[Resource, bool]) -> void:
	if value is Array:
		var items: Array = value
		for item: Variant in items: _index_inside(item, file, index, seen)
	elif value is Dictionary:
		var dictionary: Dictionary = value
		for item_key: Variant in dictionary:
			_index_inside(item_key, file, index, seen)
			_index_inside(dictionary[item_key], file, index, seen)
	elif value is Resource:
		var resource: Resource = value
		if seen.has(resource): return
		seen[resource] = true
		if resource.resource_path != file and not resource.resource_path.begins_with(file + SEPARATOR): return
		if resource.resource_path != file: index[resource.resource_scene_unique_id] = weakref(resource)
		for property: Dictionary in resource.get_property_list():
			var usage: int = property["usage"]
			if not usage & PROPERTY_USAGE_STORAGE: continue
			var property_name: String = property["name"]
			_index_inside(resource.get(property_name), file, index, seen)

static func of_each(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource: Resource in resources: ids.append(of(resource))
	return ids

## Into a typed array with [method Array.assign]
static func find_each(ids: Array) -> Array[Resource]:
	var resources: Array[Resource] = []
	for id: String in ids: resources.append(find(id))
	return resources
