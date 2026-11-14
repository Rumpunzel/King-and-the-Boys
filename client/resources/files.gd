@icon("uid://dppclq1ett8bx")
class_name Files

## What [method load_kept] loaded, by the path or UID it was asked for
static var _kept: Dictionary[String, Resource] = {}

## The resource at [param path] (a path or a UID); none if it is empty or gone, without the errors [method ResourceLoader.exists] reports for unknown UIDs
static func load_existing(path: String) -> Resource:
	if path.is_empty() or path.begins_with("uid://") and not ResourceUID.has_id(ResourceUID.text_to_id(path)): return null
	return load(path) if ResourceLoader.exists(path) else null

## The current path of [param path] (a path or a UID), or empty if it names no file
static func resolve_path(path: String) -> String:
	if not path.begins_with("uid://"): return path
	var uid: int = ResourceUID.text_to_id(path)
	return ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""

## The resource at [param path] (a path or a UID), loaded on first use and kept from then on. For what is loaded again and again,
## e.g. the scene a profile instances: a resource nothing holds is freed after each use and read from disk anew. The editor
## keeps nothing, so a file changed on disk shows as it is now (e.g. in Menagerie's previews).
static func load_kept(path: String) -> Resource:
	if Engine.is_editor_hint(): return load(path)
	var resource: Resource = _kept.get(path)
	if not resource:
		resource = load(path)
		_kept[path] = resource
	return resource
