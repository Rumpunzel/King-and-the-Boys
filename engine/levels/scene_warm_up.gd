extends RefCounted
## Instances every scene a node's resources hold once and frees it, a few per frame. A scene's first instance sets up its
## materials and particles (20 to 50 ms for a torch or a candle), which would otherwise hitch the game the first time the
## dungeon shows one: [Game] warms its [Level] up behind the loading screen, on every peer.

## How long [method warm_up] instances scenes each frame, so the loading screen keeps moving
const USEC_PER_FRAME: int = 8000

## Instances each of [method find_scenes] of [param node] once, while [param node] stays in the tree
static func warm_up(node: Node) -> void:
	var frame_start: int = Time.get_ticks_usec()
	for scene: PackedScene in find_scenes(node):
		scene.instantiate().free()
		if Time.get_ticks_usec() - frame_start < USEC_PER_FRAME: continue
		await node.get_tree().process_frame
		# Gone meanwhile (e.g. the game stopped while loading)
		if not is_instance_valid(node) or not node.is_inside_tree(): return
		frame_start = Time.get_ticks_usec()

## @returns every scene [param object]'s stored properties hold, directly or through the resources they hold (for a level:
## tiles' models, props, lights, monsters, centrepieces)
static func find_scenes(object: Object) -> Array[PackedScene]:
	var scenes: Dictionary[PackedScene, bool] = {}
	var seen: Dictionary[Resource, bool] = {}
	_collect_properties(object, scenes, seen)
	return scenes.keys()

static func _collect_properties(object: Object, scenes: Dictionary[PackedScene, bool], seen: Dictionary[Resource, bool]) -> void:
	for property: Dictionary in object.get_property_list():
		if (property["usage"] as int) & PROPERTY_USAGE_STORAGE: _collect(object.get(property["name"] as StringName), scenes, seen)

## Adds the scenes [param value] holds (itself, in its properties, arrays and dictionaries) to [param scenes]
static func _collect(value: Variant, scenes: Dictionary[PackedScene, bool], seen: Dictionary[Resource, bool]) -> void:
	if value is Array:
		for item: Variant in value as Array: _collect(item, scenes, seen)
		return
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary:
			_collect(key, scenes, seen)
			_collect(dictionary[key], scenes, seen)
		return
	if not value is Resource: return
	var resource: Resource = value
	if seen.has(resource): return
	seen[resource] = true
	if resource is PackedScene:
		scenes[resource as PackedScene] = true
		return
	# Hold no scenes, and some are large
	if resource is Script or resource is Mesh or resource is Texture or resource is Material or resource is Animation: return
	_collect_properties(resource, scenes, seen)
