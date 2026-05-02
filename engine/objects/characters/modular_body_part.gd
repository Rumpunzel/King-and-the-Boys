@tool
@abstract
class_name ModularBodyPart
extends MeshInstance3D

enum Type {
	ESSENTIAL,
	DECORATIVE,
}

@export var _type: Type = Type.ESSENTIAL
@export var _index: int = -1:
	set = update_index

@export var _related_parts: Array[ModularBodyPart]

var _mesh_list: Array[String] = []:
	get:
		if _mesh_list.is_empty(): _load_meshes()
		return _mesh_list

func _ready() -> void:
	custom_aabb = AABB()

func update_index(index: int) -> int:
	_index = index
	if _index < 0:
		mesh = null
		_index = -1
		update_visibility(false)
		return _index
	if _mesh_list.is_empty():
		if not _get_mesh_directory() == "NONE": push_error("No meshes.")
		_index = -1
		update_visibility(false)
		return _index
	_index %= _mesh_list.size()
	var new_mesh: ArrayMesh = load(_mesh_list[_index])
	new_mesh.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE)
	mesh = new_mesh
	update_visibility(true)
	return _index

func update_visibility(new_visibility: bool, sources: Array[ModularBodyPart] = []) -> void:
	visible = new_visibility
	sources.append(self)
	for related_body_part: ModularBodyPart in _related_parts:
		if sources.has(related_body_part): continue
		related_body_part.update_visibility(not new_visibility, sources)

func random_mesh() -> void: _index = randi() - (0 if _type == Type.ESSENTIAL else 1)
func reset_mesh() -> void: _index = 0 if _type == Type.ESSENTIAL else -1

func _load_meshes() -> void: _mesh_list = _get_mesh_filenames()

func _get_mesh_filenames() -> Array[String]:
	var filenames: Array[String] = []
	var mesh_directory_path: String = _get_mesh_directory()
	if mesh_directory_path.is_empty(): return filenames
	var dir: DirAccess = DirAccess.open(mesh_directory_path)
	if not dir:
		push_error("Meshes subdirectory @ <%s> not found." % mesh_directory_path)
		return filenames
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.begins_with("modular_character_"): filenames.append("%s/%s" % [dir.get_current_dir(), filename])
		filename = dir.get_next()
	return filenames

@abstract func _get_mesh_directory() -> String

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
