class_name Files

## The resource at [param path] (a path or a UID); none if it is empty or gone, without the errors [method ResourceLoader.exists] reports for unknown UIDs
static func load_existing(path: String) -> Resource:
	if path.is_empty() or path.begins_with("uid://") and not ResourceUID.has_id(ResourceUID.text_to_id(path)): return null
	return load(path) if ResourceLoader.exists(path) else null

## The current path of [param path] (a path or a UID), or empty if it names no file
static func resolve_path(path: String) -> String:
	if not path.begins_with("uid://"): return path
	var uid: int = ResourceUID.text_to_id(path)
	return ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
