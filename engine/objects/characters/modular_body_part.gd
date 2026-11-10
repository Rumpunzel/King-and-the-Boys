@tool
@abstract
class_name ModularBodyPart
extends MeshInstance3D

enum Type {
	ESSENTIAL,
	DECORATIVE,
}

## The number keys use for a part showing no mesh; the asset pack's own [code]00[/code] meshes are bare skin, so it reads the same
const EMPTY_MESH_NUMBER: String = "00"

## The trailing number of a mesh file name, compiled once as listing and sorting meshes asks for it often
static var _mesh_number_pattern: RegEx = RegEx.create_from_string("(\\d+)$")

@export var _type: Type = Type.ESSENTIAL
## Only mesh files starting with this are listed; the mesh directories hold some leftovers of other names
## Declared before [member _index], whose setter lists the meshes when a scene loads
@export var _mesh_prefix: String = "modular_character_"
@export var _index: int = -1:
	set = update_index

@export var _related_parts: Array[ModularBodyPart]
## Where the part goes while stowed, e.g. a weapon on the back (see [method ModularModel.stow_weapons]); parts without one stay put
@export var stow: Node3D

## What held the part before it was stowed, and how; [code]null[/code] while it is not stowed
var _held_by: Node3D
var _held_transform: Transform3D

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
	mesh = new_mesh
	update_visibility(true)
	return _index

func update_visibility(new_visibility: bool, sources: Array[ModularBodyPart] = []) -> void:
	visible = new_visibility
	sources.append(self)
	for related_body_part: ModularBodyPart in _related_parts:
		if sources.has(related_body_part): continue
		related_body_part.update_visibility(not new_visibility, sources)

func is_stowed() -> bool: return _held_by != null

## Moves the part to its [member stow], or back where it was; nothing for parts without a stow
func set_stowed(stowed: bool) -> void:
	if not stow or stowed == is_stowed(): return
	if stowed:
		_held_by = get_parent() as Node3D
		_held_transform = transform
		reparent(stow, false)
		transform = Transform3D.IDENTITY
	else:
		reparent(_held_by, false)
		transform = _held_transform
		_held_by = null

## Sets an exact mesh, bypassing the index into the mesh directory
## A [code]null[/code] mesh hides this part and shows its related parts
func apply_mesh(new_mesh: ArrayMesh) -> void:
	mesh = new_mesh
	update_visibility(new_mesh != null)

## @returns the position of the shown mesh in this part's mesh directory, or [code]-1[/code] if hidden or not listed there
func get_mesh_index() -> int:
	if not visible or not mesh: return -1
	return _mesh_list.find(mesh.resource_path)

func get_mesh_count() -> int: return _mesh_list.size()

## The mesh files of this part's directory, in directory order
func get_mesh_paths() -> PackedStringArray: return PackedStringArray(_mesh_list)

## @returns the trailing number of a mesh file, e.g. [code]"05"[/code] for [code]..._Male_05.res[/code]
static func get_mesh_number(mesh_path: String) -> String:
	var mesh_name: String = mesh_path.get_file().get_basename()
	var found: RegExMatch = _mesh_number_pattern.search(mesh_name)
	return found.get_string(1) if found else mesh_name

## @returns the numbers of all meshes in this part's directory, in directory order
func get_mesh_numbers() -> PackedStringArray:
	var mesh_numbers: PackedStringArray = []
	for mesh_path: String in _mesh_list: mesh_numbers.append(get_mesh_number(mesh_path))
	return mesh_numbers

## @returns the position of the mesh numbered [param mesh_number] in this part's directory, or [code]-1[/code]
func find_mesh_index(mesh_number: String) -> int:
	return get_mesh_numbers().find(mesh_number)

## Decorative parts may show no mesh at all, essential parts always show one
func allows_none() -> bool: return _type == Type.DECORATIVE

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
		if not dir.current_is_dir() and filename.begins_with(_mesh_prefix): filenames.append("%s/%s" % [dir.get_current_dir(), filename])
		filename = dir.get_next()
	# By number, as files named after what they show (e.g. "..._king_07") would otherwise sort by name
	filenames.sort_custom(func(first: String, second: String) -> bool: return get_mesh_number(first).naturalnocasecmp_to(get_mesh_number(second)) < 0)
	return filenames

@abstract func _get_mesh_directory() -> String

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
