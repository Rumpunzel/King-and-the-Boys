@tool
@icon("uid://byik03x1jlrlv")
class_name LevelSpawner
extends Spawner

@export_group("Configuration")
@export var _structure_spawner: StructureSpawner

var _level: Level

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	spawn_function = _spawn_level

func _ready() -> void:
	super._ready()

func load_level(level_scene_path: String) -> void:
	assert(multiplayer.is_server())
	assert(not _level)
	spawn(level_scene_path)

func unload_level() -> void:
	assert(multiplayer.is_server())
	assert(_level)
	remove_all_spawned_nodes()

func get_all_node_data() -> Array[Variant]:
	var level_data: Array[Variant] = []
	if _level: level_data.append(_level.scene_file_path)
	return level_data

func _remove_all_data_nodes() -> Array[NodePath]:
	if not _level: return []
	assert(_level)
	var level_path: NodePath = _level.get_path()
	remove_child(_level)
	_level.queue_free()
	_level = null
	return [level_path]

func _spawn_level(level_scene_path: String) -> Level:
	var level_scene: PackedScene = load(level_scene_path)
	return level_scene.instantiate()

func _on_child_entered_tree(node: Node) -> void:
	if not node is Level: return
	_level = node
	assert(_level)
	_level.tile_placement_requested.connect(_structure_spawner.spawn_at)

func _on_structure_created(structure: Structure) -> void:
	assert(_level)
	_level._on_structure_created(structure)

func _on_agent_created(agent: Agent) -> void:
	assert(_level)
	#agent.character.entered_grid_cell.connect(_level._on_character_entered_grid_cell)

func _on_player_ghost_created(player_ghost: PlayerGhost) -> void:
	assert(_level)
	_level._on_player_ghost_created(player_ghost)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _structure_spawner: warnings.append("Missing StructureSpawner reference.")
	return warnings
