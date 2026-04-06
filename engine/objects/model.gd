@tool
@icon("uid://cpbv0myc0qfxb")
class_name Model
extends Node3D

@export var portrait_override: Texture

@export_group("Configuration")
@export var _animation_tree: AnimationTree

static func gather_all_geometry_instances_on(node: Node) -> Array[MeshInstance3D]:
	var geometry_instances: Array[MeshInstance3D] = [ ]
	for child: Node in node.get_children():
		if child is MeshInstance3D: geometry_instances.append(child)
		geometry_instances.append_array(gather_all_geometry_instances_on(child))
	return geometry_instances

func play_animation(normalized_velocity: Vector3, _is_on_floor: bool) -> void:
	if not _animation_tree: return
	var _state_machine: AnimationNodeStateMachinePlayback = _animation_tree["parameters/playback"]
	assert(_state_machine)
	if normalized_velocity:
		_state_machine.travel("Walk")
		_animation_tree.set("parameters/Walk/blend_position", normalized_velocity.length_squared())
	else:
		_state_machine.travel("Idle")

func apply_material_override(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		mesh.material_override = material

func remove_material_override(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		if mesh.material_override == material: mesh.material_override = null

func apply_material_overlay(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		mesh.material_overlay = material

func remove_material_overlay(material: Material) -> void:
	assert(material)
	for mesh: MeshInstance3D in gather_all_geometry_instances_on(self):
		if mesh.material_override == material: mesh.material_override = null

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _animation_tree: warnings.append("Missing AnimationTree reference.")
	return warnings
