@tool
@icon("uid://bnaoddhf8gssj")
class_name Character
extends BoardObject

signal entered_grid_cell(cell: Vector2i)
signal exited_grid_cell(cell: Vector2i)
signal movement_points_changed(movement_points: int)
signal undo_steps_changed(undo_steps: int)
signal ability_uses_changed
signal active_ability_changed
signal held_cost_changed(held_cost: int)
## Emitted on every peer when the animated figure crosses into [param cell], which lags behind [member grid_cell]
signal figure_entered_grid_cell(cell: Vector2i)
## Emitted on every peer when the figure's move ended
signal figure_arrived

## Emitted when the lights the character carries change (see [method get_light_sources]), e.g. a torch equipped, a lantern lit
signal light_sources_changed

const GROUP: StringName = "Characters"

const VARIATION: StringName = "variation"
const PROFILE_PATH: StringName = "profile_path"
const SPAWN_TRANSFORM: StringName = "spawn_transform"
const BODY: StringName = "body"
const EQUIPMENT: StringName = "equipment"

const _TURN_DURATION: float = 0.5

@export var profile: CharacterProfile:
	set(new_character_profile):
		var previous_profile: CharacterProfile = profile
		profile = new_character_profile
		_show_profile(previous_profile)

@export_group("Configuration")
@export var _synchronizer: MultiplayerSynchronizer
@export var equipment: CharacterEquipment

## Rolled once by the server, see [method ModelConfigurationRandom.roll]
## {part: [int] of the model's [code]Part[/code] enum -> mesh [ResourceId]: [String]}, an empty ID meaning no mesh
var body: Dictionary = {}:
	set(new_body):
		body = new_body
		_apply_body()

var level: Level
## Whether the figure shows on this peer; purely visual, the piece still holds its spot. Monsters hide on tiles this peer has not
## revealed (see [method Level.update_shown]) and drop in with their spawn animation as they come into sight
var shown: bool = true:
	set(new_shown):
		if new_shown == shown: return
		shown = new_shown
		if not model: return
		model.visible = shown
		if shown and is_node_ready(): model.play_model_animation(profile.spawn_animation)
## Whether the figure shows that its player has passed (see [method show_passed]); purely visual, on every peer
var shows_passed: bool = false
## The [Character] currently controlling this one, if any
var controlled_by: Character
## The piece this [Character] currently controls, if any; set with [member HitBox.controller]
var controlling: HitBox
## Steps taken so far, undos included; counted by the host, replicated. Tiles a step reveals carry its number
## (see [member Structure.status_cause_step]), so peers know which step to show them after.
var step_count: int = 0

# Grid state: owned by the host, replicated on change by the CharacterSynchronizer.
# Every peer turns it into a world position and animates the model itself.
var grid_cell: Vector2i = Vector2i.ZERO:
	set(new_grid_cell):
		var previous_grid_cell: Vector2i = grid_cell
		grid_cell = new_grid_cell
		_queue_grid_visual_update()
		if previous_grid_cell == grid_cell or not _has_grid_state: return
		exited_grid_cell.emit(previous_grid_cell)
		entered_grid_cell.emit(grid_cell)
## Offset from the center of [member grid_cell], see [method Level.get_free_spots]
var tile_spot: Vector2 = Vector2.ZERO:
	set(new_tile_spot):
		tile_spot = new_tile_spot
		_queue_grid_visual_update()
var facing: Level.Direction = Level.Direction.DOWN:
	set(new_facing):
		facing = new_facing
		_queue_grid_visual_update()
## Movement points left in the current turn; [code]<0[/code] until the host first resets them
var movement_points: int = -1:
	set(new_movement_points):
		if new_movement_points == movement_points: return
		movement_points = new_movement_points
		movement_points_changed.emit(movement_points)
## Steps the host can still undo this turn; replicated, the steps themselves stay on the host
var undo_steps: int = 0:
	set(new_undo_steps):
		if new_undo_steps == undo_steps: return
		undo_steps = new_undo_steps
		undo_steps_changed.emit(undo_steps)
## Uses so far of each [Ability] with [member Ability.charges], by its [ResourceId]; replicated and saved.
## Replaced as a whole on every change, so the synchronizer notices it.
var ability_uses: Dictionary = {}:
	set(new_ability_uses):
		if new_ability_uses == ability_uses: return
		ability_uses = new_ability_uses
		ability_uses_changed.emit()
## The [ResourceId] of the held [Ability] in use (see [member Ability.held]), empty if none; set by the host, replicated
var active_ability_id: String = "":
	set(new_active_ability_id):
		if new_active_ability_id == active_ability_id: return
		active_ability_id = new_active_ability_id
		active_ability_changed.emit()
		if model: model.rest_in(_get_rest())
## The [ResourceId]s of the toggled abilities whose state differs from how they start (see [ToggleLightAbility]), e.g. a
## lantern put out; set by the host, replicated
var toggled_ability_ids: PackedStringArray = []:
	set(new_toggled_ability_ids):
		if new_toggled_ability_ids == toggled_ability_ids: return
		toggled_ability_ids = new_toggled_ability_ids
		_show_abilities()
		light_sources_changed.emit()
## The movement points the held ability in use would cost as it is now, [code]0[/code] if none; set by the host, replicated
var held_cost: int = 0:
	set(new_held_cost):
		if new_held_cost == held_cost: return
		held_cost = new_held_cost
		held_cost_changed.emit(held_cost)

var _has_grid_state: bool = false
var _grid_visual_update_queued: bool = false
var _grid_visuals_applied: bool = false
# The figure's move: one hop; a step that comes in while it is under way redirects it to the new target
var _move_tween: Tween
var _turn_tween: Tween
var _model_tween: Tween
var _move_target: Vector3
var _move_backwards: bool = false
# The cell the animated figure is in; lags behind grid_cell while it moves
var _figure_grid_cell: Vector2i = Vector2i.ZERO

# What the figure rides on, e.g. a lifted tile's model (see TileLift), and where on it
var _carrier: Node3D
var _carried_transform: Transform3D

func _enter_tree() -> void:
	# Before the children are ready, so the character's light sees equipment shown from the start
	if equipment and not equipment.equipment_changed.is_connected(light_sources_changed.emit):
		equipment.equipment_changed.connect(light_sources_changed.emit)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if model: model.play_model_animation(profile.spawn_animation)
	if multiplayer.is_server():
		# Initial grid state comes from the spawn transform: the spot it stands on if that is free, else the first free one
		grid_cell = level.world_to_grid_position(global_position)
		facing = rotation_to_facing(rotation.y)
		var free_spots: Array[Vector2] = level.get_free_spots(grid_cell, self)
		var offset: Vector3 = global_position - level.grid_to_world_position(grid_cell)
		var standing_spot: Vector2 = Vector2(offset.x, offset.z)
		# A fixed tolerance: float error grows with the distance from the origin (e.g. loaded far out)
		var spot_index: int = free_spots.find_custom(func(free_spot: Vector2) -> bool: return free_spot.distance_to(standing_spot) < 0.01)
		if spot_index >= 0: tile_spot = free_spots[spot_index]
		elif not free_spots.is_empty(): tile_spot = free_spots.front()
		else: _take_nearest_free_spot()
		reset_movement_points()
	_has_grid_state = true
	_queue_grid_visual_update()
	entered_grid_cell.emit(grid_cell)

## @returns the lights the character carries: its equipment's (a torch) and its abilities' (a lit lantern), each once
func get_light_sources() -> Array[LightSource]:
	var light_sources: Array[LightSource] = []
	if equipment:
		for look: EquipmentLook in equipment.get_all_equipped():
			for light_source: LightSource in look.get_light_sources(): _add_light_source(light_sources, light_source)
	if profile:
		for ability: Ability in profile.abilities: _add_light_source(light_sources, ability.get_light_source(self) if ability else null)
	return light_sources

## A light counts once, e.g. a torch in each hand
static func _add_light_source(light_sources: Array[LightSource], light_source: LightSource) -> void:
	if light_source and not light_sources.has(light_source): light_sources.append(light_source)

## @returns how far the character sees ([member CharacterProfile.vision]), changed by the lights it carries
func get_vision() -> float:
	var vision: float = profile.vision
	for light_source: LightSource in get_light_sources(): vision = StatModifier.apply_all(light_source.vision_modifiers, vision)
	return vision

## @returns how far the character sees in the dark ([member CharacterProfile.dark_vision]), changed by the lights it carries
func get_dark_vision() -> float:
	var dark_vision: float = profile.dark_vision
	for light_source: LightSource in get_light_sources():
		dark_vision = StatModifier.apply_all(light_source.dark_vision_modifiers, dark_vision)
	return dark_vision

## Lets each ability show itself on the model, e.g. a lantern on the belt, lit or not
func _show_abilities() -> void:
	if not profile or not model: return
	for ability: Ability in profile.abilities:
		if ability: ability.show_on(self)

## Host only, while spawning onto a full tile: the nearest tile with room instead, see
## [method Level.get_nearest_free_spot_position]
func _take_nearest_free_spot() -> void:
	var spot_position: Vector3 = level.get_nearest_free_spot_position(grid_cell, self)
	if spot_position == Vector3.INF:
		push_warning("No free spot for %s near %s: it shares a spot" % [self, grid_cell])
		return
	grid_cell = level.world_to_grid_position(spot_position)
	var offset: Vector3 = spot_position - level.grid_to_world_position(grid_cell)
	tile_spot = Vector2(offset.x, offset.z)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if is_instance_valid(_carrier): global_transform = _carrier.global_transform * _carried_transform
	_update_figure_grid_cell()

static func from_character_data(character_data: Dictionary[StringName, Variant]) -> Character:
	validate_character_data(character_data)
	var new_variation: int = character_data[VARIATION]
	var new_character_profile_path: String = character_data[PROFILE_PATH]
	var new_character_profile: CharacterProfile = load(new_character_profile_path)
	assert(new_character_profile)
	var new_spawn_transform: Transform3D = character_data[SPAWN_TRANSFORM]
	var new_character: Character = new_character_profile.create(new_variation, new_spawn_transform)
	new_character.body = character_data[BODY]
	var new_equipment_ids: PackedStringArray = character_data[EQUIPMENT]
	new_character.equipment.set_equipped_ids(new_equipment_ids)
	return new_character

static func validate_character_data(character_data: Dictionary[StringName, Variant]) -> void:
	assert(character_data.has_all([VARIATION, PROFILE_PATH, SPAWN_TRANSFORM, BODY, EQUIPMENT]))
	assert(character_data.size() == 5)
	assert(character_data[BODY] is Dictionary)
	assert(character_data[EQUIPMENT] is PackedStringArray)

static func facing_to_rotation(direction: Level.Direction) -> float:
	return (2 - direction) * PI * 0.5

static func rotation_to_facing(rotation_y: float) -> Level.Direction:
	return posmod(2 - roundi(rotation_y / (PI * 0.5)), Level.Direction.size()) as Level.Direction

## Host only: places the [Character] on the grid; peers follow through replication
func place_on_grid(new_grid_cell: Vector2i, new_tile_spot: Vector2, new_facing: Level.Direction) -> void:
	assert(multiplayer.is_server())
	# Counted before the cell changes: entering the cell reveals tiles, which carry this step's number
	if new_grid_cell != grid_cell: step_count += 1
	tile_spot = new_tile_spot
	facing = new_facing
	grid_cell = new_grid_cell

## The host owns the grid state of every piece, whoever controls it.
## Call after changing the multiplayer authority of this [Character].
func give_grid_state_to_host() -> void:
	_synchronizer.set_multiplayer_authority(Multiplayer.HOST_ID)

## Host only
func reset_movement_points() -> void:
	assert(multiplayer.is_server())
	movement_points = profile.speed

## @returns the listed [Ability] named by [param ability_id], or [code]null[/code]; loads nothing, so peer-sent ids are safe.
## The held ability in use is [code]get_ability(active_ability_id)[/code].
func get_ability(ability_id: String) -> Ability:
	if not profile or ability_id.is_empty(): return null
	for ability: Ability in profile.abilities:
		if ability and ResourceId.of(ability) == ability_id: return ability
	return null

## Host only: counts [param amount] uses of [param ability] against its charges; a negative amount takes them back,
## e.g. on undo. See [method Ability.get_charges_left].
func count_charges(ability: Ability, amount: int) -> void:
	assert(multiplayer.is_server())
	if ability.charges < 0: return
	var ability_id: String = ResourceId.of(ability)
	var new_ability_uses: Dictionary = ability_uses.duplicate()
	var used: int = new_ability_uses.get(ability_id, 0)
	used = clampi(used + amount, 0, ability.charges)
	if used == 0: new_ability_uses.erase(ability_id)
	else: new_ability_uses[ability_id] = used
	ability_uses = new_ability_uses

## Every peer: the figure rides on [param carrier] as it stands, e.g. on a lifted tile; [code]null[/code] sets it
## down, snapping it onto its grid state. Grid state changes meanwhile show once it is set down.
func carry_on(carrier: Node3D) -> void:
	_carrier = carrier
	if not carrier:
		snap_to_grid()
		return
	# A move under way ends at once where it was going, and the figure arrives (e.g. to pass when out of moves): then it rides
	if _is_moving():
		_move_tween.kill()
		global_position = _move_target
		_on_move_finished()
	if _turn_tween: _turn_tween.kill()
	_carried_transform = carrier.global_transform.affine_inverse() * global_transform

func is_carried() -> bool:
	return is_instance_valid(_carrier)

## Snaps the model back onto its grid state, e.g. after something else moved it locally
func snap_to_grid() -> void:
	_grid_visuals_applied = false
	_queue_grid_visual_update()

@rpc("call_local", "reliable")
func hide_character(keep_processing: bool = false) -> void:
	assert(visible)
	visible = false
	if not keep_processing: set_process(false)

@rpc("call_local", "reliable")
func unhide_character() -> void:
	assert(not visible)
	visible = true
	set_process(true)

func apply_character_data(character_data: Dictionary[StringName, Variant]) -> void:
	validate_character_data(character_data)
	variation = character_data[VARIATION]
	var character_profile_path: String = character_data[PROFILE_PATH]
	profile = load(character_profile_path)
	transform = character_data[SPAWN_TRANSFORM]
	body = character_data[BODY]
	var equipment_ids: PackedStringArray = character_data[EQUIPMENT]
	equipment.set_equipped_ids(equipment_ids)

func to_character_data() -> Dictionary[StringName, Variant]:
	assert(profile)
	var character_data: Dictionary[StringName, Variant] = {
		VARIATION: variation,
		PROFILE_PATH: profile.resource_path,
		SPAWN_TRANSFORM: transform,
		BODY: body,
		EQUIPMENT: equipment.get_equipped_ids(),
	}
	validate_character_data(character_data)
	return character_data

func _apply_body() -> void:
	if not model is ModularModel: return
	var modular_model: ModularModel = model
	modular_model.apply_body(body)

func get_profile() -> Profile: return profile

## Dresses each new model: body, rest, equipment, abilities
func _on_model_added() -> void:
	model.visible = shown
	_apply_body()
	var rest: BodyAnimations = _get_rest()
	if rest: model.rest_in(rest, false)
	if equipment and model is ModularModel:
		var modular_model: ModularModel = model
		equipment.apply_to(modular_model)
	_show_abilities()

func get_grid_position() -> Vector2i:
	return grid_cell

## @returns the cell the animated figure currently stands in
func get_figure_grid_cell() -> Vector2i:
	return _figure_grid_cell

func _update_figure_grid_cell() -> void:
	if not level or not _grid_visuals_applied: return
	var figure_grid_cell: Vector2i = level.world_to_grid_position(global_position)
	if figure_grid_cell == _figure_grid_cell: return
	_figure_grid_cell = figure_grid_cell
	figure_entered_grid_cell.emit(_figure_grid_cell)

func _queue_grid_visual_update() -> void:
	if _grid_visual_update_queued: return
	_grid_visual_update_queued = true
	_apply_grid_visuals.call_deferred()

func _apply_grid_visuals() -> void:
	_grid_visual_update_queued = false
	# A carried figure shows its grid state once it is set down
	if not level or not is_inside_tree() or is_carried(): return
	var target_position: Vector3 = level.get_spot_position(grid_cell, tile_spot)
	var target_rotation: float = facing_to_rotation(facing)
	if not _grid_visuals_applied:
		_grid_visuals_applied = true
		for tween: Tween in [_move_tween, _turn_tween, _model_tween]: if tween: tween.kill()
		global_position = target_position
		# Upright again after riding on a tilted carrier
		rotation = Vector3(0.0, target_rotation, 0.0)
		_update_figure_grid_cell()
		return
	_turn_to(target_rotation)
	if target_position.is_equal_approx(_move_target if _is_moving() else global_position): return
	if _is_moving(): _extend_move(target_position)
	else: _start_move(target_position, target_rotation)

func _is_moving() -> bool:
	return _move_tween != null and _move_tween.is_running()

## @returns [code]true[/code] until the figure arrived where the grid state says, see [signal figure_arrived]
func is_figure_moving() -> bool:
	return _grid_visual_update_queued or _is_moving()

func _turn_to(target_rotation: float) -> void:
	if _turn_tween: _turn_tween.kill()
	var relative_rotation: float = wrapf(target_rotation - rotation.y, -PI, PI)
	if is_zero_approx(relative_rotation): return
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, "rotation:y", relative_rotation, _TURN_DURATION).as_relative().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_move(target_position: Vector3, target_rotation: float) -> void:
	# Steps back (undo) keep facing the way the step went, so the figure walks backwards
	var facing_vector: Vector3 = Vector3(sin(target_rotation), 0.0, cos(target_rotation))
	_move_backwards = (target_position - global_position).normalized().dot(facing_vector) < -0.5
	var animation: ModelAnimation = profile.undo_animation if _move_backwards and profile.undo_animation else profile.move_animation
	# From standing, by the animation's travel settings, e.g. the hop's: a little back, then forward into the tile
	_run_move(target_position, animation, false)

## Redirects the move under way to [param target_position], from where the figure is: at most one step's time
## is left after any step, so quick steps take hardly longer than one, and corners may be cut
func _extend_move(target_position: Vector3) -> void:
	_move_backwards = false
	_run_move(target_position, profile.move_animation, true)

## Travels by [param animation]'s travel settings: as it starts, or redirected ([param continuing]), see [ModelAnimation]
func _run_move(target_position: Vector3, animation: ModelAnimation, continuing: bool) -> void:
	var transition: Tween.TransitionType = animation.redirect_transition if continuing else animation.travel_transition
	var easing: Tween.EaseType = animation.redirect_ease if continuing else animation.travel_ease
	# A redirected move is under way already
	var delay: float = 0.0 if continuing else animation.duration * animation.travel_delay
	_move_target = target_position
	if _move_tween: _move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", target_position, animation.duration - delay).set_trans(transition).set_ease(easing).set_delay(delay)
	_move_tween.tween_callback(_on_move_finished)
	# A redirected move continues the hop: it stays up and lands with the move, without a new lean back
	if not model: return
	if _model_tween: _model_tween.kill()
	_model_tween = model.continue_model_animation(animation) if continuing else model.play_model_animation(animation)

func _on_move_finished() -> void:
	# The tween still counts as running during its own callback; listeners must see the figure arrived
	_move_tween = null
	if not _move_backwards: _look_at_thing_on_tile()
	figure_arrived.emit()

## Shows that the character's player passed, or no longer has: its passed animations in place of the idles (e.g. sitting down
## and sitting), or getting up again
func show_passed(passed: bool) -> void:
	if passed == shows_passed: return
	shows_passed = passed
	if model: model.rest_in(_get_rest())

## What the model rests in now: the cast animations of the held ability in use, the passed animations, or its idles
## ([code]null[/code])
func _get_rest() -> BodyAnimations:
	var ability: Ability = get_ability(active_ability_id)
	if ability and ability.cast_animations: return ability.cast_animations
	if shows_passed: return profile.passed_animations
	return null

## Something interesting on the tile (e.g. a chest) catches the figure's eye when it arrives
func _look_at_thing_on_tile() -> void:
	var thing: Thing = level.get_thing_near(grid_cell)
	if not thing or not thing.visible: return
	var to_thing: Vector3 = thing.global_position - global_position
	to_thing.y = 0.0
	if to_thing.length_squared() < 0.01: return
	_turn_to(atan2(to_thing.x, to_thing.z))

## @returns [code]true[/code] if the peer [param peer_id] may move this [Character]
func is_controlled_by(peer_id: int) -> bool:
	if controlled_by: return controlled_by.get_multiplayer_authority() == peer_id
	return get_multiplayer_authority() == peer_id

func _on_controlled(controller: Character) -> void:
	controlled_by = controller

func _on_released() -> void:
	controlled_by = null

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _synchronizer: warnings.append("Missing MultiplayerSynchronizer reference.")
	if not equipment: warnings.append("Missing CharacterEquipment reference.")
	return warnings
