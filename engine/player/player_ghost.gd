@tool
@icon("uid://nl71yast8tsi")
class_name PlayerGhost
extends Node

const PLAYER_ID: StringName = "player_id"
const CHARACTER_DATA: StringName = "character_data"

const _ACTIVE_CAMERA_PRIORITY: int = 16
const _DEFAULT_CAMERA_PRIORITY: int = 1
const _INACTIVE_CAMERA_PRIORITY: int = 0

@export var player: Player:
	set(new_player):
		assert(new_player)
		player = new_player
		set_multiplayer_authority(player.get_multiplayer_authority())
		name = player.name
		_camera.current = player.is_local_player()
		player.player_info_changed.connect(_on_player_info_changed)

@export_group("Configuration")
@export var character: Character
@export var _state_machine: PlayerStateMachine
@export var _camera: Camera3D

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.start()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_multiplayer_authority(): return
	_state_machine.physics_update(delta)

static func create(for_player: Player, character_data: Dictionary[StringName, Variant]) -> PlayerGhost:
	assert(for_player)
	var new_player_ghost: PlayerGhost = PackedScenes.PLAYER_GHOST_SCENE.instantiate()
	new_player_ghost.player = for_player
	new_player_ghost.character.apply_character_data(character_data)
	return new_player_ghost

static func validate_player_ghost_data(player_ghost_data: Dictionary[StringName, Variant]) -> void:
	assert(player_ghost_data.has_all([PLAYER_ID, CHARACTER_DATA]))
	assert(player_ghost_data.size() == 2)

func to_player_ghost_data() -> Dictionary[StringName, Variant]:
	assert(player)
	assert(character)
	var character_data: Dictionary[StringName, Variant] = character.to_character_data()
	var player_ghost_data: Dictionary[StringName, Variant] = {
		PLAYER_ID: player.player_id,
		CHARACTER_DATA: character_data,
	}
	validate_player_ghost_data(player_ghost_data)
	return player_ghost_data

func get_active_camera_priority() -> int:
	return _ACTIVE_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

func get_default_camera_priority() -> int:
	return _DEFAULT_CAMERA_PRIORITY if player.is_local_player() else _INACTIVE_CAMERA_PRIORITY

func _on_player_info_changed() -> void:
	pass#character.variation = player.ghost_sprite_frame

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not character: warnings.append("Missing Character reference.")
	if not _state_machine: warnings.append("Missing PlayerStateMachine reference.")
	if not _camera: warnings.append("Missing Camera3D reference.")
	return warnings
