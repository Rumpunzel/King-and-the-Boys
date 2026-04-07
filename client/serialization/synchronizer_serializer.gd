@tool
@icon("uid://bwsawlgvt1651")
class_name SynchronizerSerializer
extends PropertiesSerializer

@export_group("Configuration")
@export var _synchronizer: Synchronizer

func _ready() -> void:
	var parent: Node = get_parent()
	if not _synchronizer and parent is Synchronizer:
		_synchronizer = parent
	super._ready()

## @returns a [Dictionary] with the parameter as [NodePath] to the value as a [Variant]
func collect_properties() -> Dictionary[NodePath, Variant]:
	return _synchronizer.collect_properties(self).merged(super.collect_properties())

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = [ ]
	if not _synchronizer: warnings.append("Missing Synchronizer reference.")
	return warnings + super._get_configuration_warnings()
