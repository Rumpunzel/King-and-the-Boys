extends RefCounted
## Instances every scene a node's resources hold once and frees it, a few each frame (see [method step]). A scene's first
## instance sets up its materials and particles (20 to 50 ms for a torch or a candle), which would otherwise hitch the game the
## first time the dungeon shows one: [Game] warms its [Level] up behind the loading screen, on every peer.

## How long [method step] instances scenes, so the loading screen keeps moving
const USEC_PER_FRAME: int = 8000

## How many scenes it instanced so far
var count: int = 0

var _scenes: Array[PackedScene]

func _init(node: Node) -> void:
	_scenes = find_scenes(node)

## Instances the next scenes for about [constant USEC_PER_FRAME]; called once a frame by its owner, so it stops with it
## @returns whether every scene was instanced
func step() -> bool:
	var start: int = Time.get_ticks_usec()
	while not _scenes.is_empty() and Time.get_ticks_usec() - start < USEC_PER_FRAME:
		var scene: PackedScene = _scenes.pop_back()
		# None for a scene missing a dependency
		var instance: Node = scene.instantiate()
		if not instance: continue
		instance.free()
		count += 1
	return _scenes.is_empty()

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
