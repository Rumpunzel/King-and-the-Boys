@tool
@icon("uid://cyrqlm5mdw05a")
class_name AreaShape
extends Resource

@export var _shape: Shape3D:
	set(new_value):
		_shape = new_value
		if not _shape.changed.is_connected(changed.emit): _shape.changed.connect(changed.emit)
		changed.emit()
@export var _offset: Vector3:
	set(new_value):
		_offset = new_value
		changed.emit()
@export var _rotation_degrees: Vector3:
	set(new_value):
		_rotation_degrees = new_value
		changed.emit()
@export var _automatic_ground_offset: bool = true:
	set(new_value):
		_automatic_ground_offset = new_value
		changed.emit()

static func get_ground_offset(for_shape: Shape3D) -> float:
	assert(for_shape)
	var ground_offset: float = 0.0
	match for_shape.get_class():
		"BoxShape3D":
			var box_shape: BoxShape3D = for_shape
			ground_offset = box_shape.size.y / 2.0
		"CapsuleShape3D":
			var capsule_shape: CapsuleShape3D = for_shape
			ground_offset = capsule_shape.height / 2.0
		"ConcavePolygonShape3D": printerr("ConcavePolygonShape3D is not yet implemented!")
		"ConvexPolygonShape3D": printerr("ConvexPolygonShape3D is not yet implemented!")
		"CylinderShape3D":
			var cylinder_shape: CylinderShape3D = for_shape
			ground_offset = cylinder_shape.height / 2.0
		"HeightMapShape3D": printerr("HeightMapShape3D is not yet implemented!")
		"SeparationRayShape3D": printerr("SeparationRayShape3D is not yet implemented!")
		"SphereShape3D":
			var sphere_shape: CylinderShape3D = for_shape
			ground_offset = sphere_shape.radius
		"WorldBoundaryShape3D": printerr("WorldBoundaryShape3D is not yet implemented!")
	return ground_offset

func configure_collision_shape(collision_shape: CollisionShape3D) -> void:
	assert(collision_shape)
	if Engine.is_editor_hint() and not _shape:
		reset_configuration_shape(collision_shape)
		return
	assert(_shape)
	collision_shape.shape = _shape
	collision_shape.position = _offset
	collision_shape.rotation_degrees = _rotation_degrees
	if _automatic_ground_offset: collision_shape.position.y = get_ground_offset(_shape)

func reset_configuration_shape(collision_shape: CollisionShape3D) -> void:
	collision_shape.shape = null
	collision_shape.position = Vector3.ZERO
	collision_shape.rotation_degrees = Vector3.ZERO

func configure_mesh(mesh: MeshInstance3D) -> void:
	assert(mesh)
	if Engine.is_editor_hint() and not _shape:
		reset_mesh(mesh)
		return
	assert(_shape)
	mesh.mesh = _shape.get_debug_mesh()
	mesh.position = _offset
	mesh.rotation_degrees = _rotation_degrees
	if _automatic_ground_offset: mesh.position.y = get_ground_offset(_shape)

func reset_mesh(mesh: MeshInstance3D) -> void:
	mesh.mesh = null
	mesh.position = Vector3.ZERO
	mesh.rotation_degrees = Vector3.ZERO

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _shape: warnings.append("Missing Shape3D.")
	if _automatic_ground_offset and _offset.y != 0.0: warnings.append("automatic_ground_offset = true; manual offset Y position will be overridden.")
	return warnings
