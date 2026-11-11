@tool
@icon("uid://custqp1bbaq80")
class_name CatalogSaver
extends RefCounted

## Saves changed [EquipmentCatalog]s in one go a moment after the last change, so toggling looks never waits for a save
## Saving a large catalog takes a noticeable moment; flush on leaving the Gear tab and when the plugin unloads

const DELAY: float = 1.0

static var _dirty: Dictionary[EquipmentCatalog, bool] = {}
static var _generation: int = 0

static func mark_dirty(catalog: EquipmentCatalog) -> void:
	_dirty[catalog] = true
	_generation += 1
	var generation: int = _generation
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree: return
	tree.create_timer(DELAY).timeout.connect(_flush_if_latest.bind(generation))

## Only the timer of the latest change saves
static func _flush_if_latest(generation: int) -> void:
	if generation == _generation: flush()

static func has_unsaved() -> bool:
	return not _dirty.is_empty()

## Only catalogs that already have a file are saved, so a catalog made for a test never overwrites a real one
static func flush() -> void:
	for catalog: EquipmentCatalog in _dirty:
		var catalog_path: String = catalog.resource_path
		if catalog_path.is_empty():
			push_warning("%s catalog has no file yet; not saved." % catalog.type.name)
			continue
		var error: Error = ResourceSaver.save(catalog, catalog_path)
		if error != Error.OK:
			push_error("Could not save %s: %s" % [catalog_path, error_string(error)])
			continue
		if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().update_file(catalog_path)
	_dirty.clear()

## The catalog [param look] is stored in, or [code]null[/code] for a look saved as its own file
static func get_catalog_of(look: EquipmentLook) -> EquipmentCatalog:
	if not look.resource_path.contains(ResourceId.SEPARATOR): return null
	return load(look.resource_path.get_slice(ResourceId.SEPARATOR, 0)) as EquipmentCatalog
