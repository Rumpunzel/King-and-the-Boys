@tool
extends PanelContainer

signal show_collision_changed(show_collision: bool)
signal show_hit_box_changed(show_hit_box: bool)
signal show_interaction_area_changed(show_interaction_area: bool)
signal randomize_variation_changed(randomize_variation: bool)
signal variation_changed(new_variation: int)
signal randomized

@export_group("Configuration")
@export var _show_collision_button: CheckButton
@export var _show_hit_box_button: CheckButton
@export var _show_interaction_area_button: CheckButton
@export var _randomize_variation_button: CheckButton
@export var _variation_spin_box: SpinBox
@export var _randomize_button: Button
## A carousel per body part of the previewed body, under the button that re-rolls it
@export var _body_carousels: VBoxContainer
## Plays the previewed character's animations: spawn, move, undo, passing
@export var _animation_buttons: HFlowContainer
@export var _config: Config

var _model: Model
var _profile: Profile
## Pressed while the preview shows passing, see [method _show_passed]
var _pass_button: Button

func _ready() -> void:
	# Opened on its own in the editor: only the preview hands it a config
	if not _config: return
	_show_collision_button.set_pressed_no_signal(_config.get_value_from_config("Preview", "show_collision", true))
	show_collision_changed.emit(_show_collision_button.button_pressed)
	_show_hit_box_button.set_pressed_no_signal(_config.get_value_from_config("Preview", "show_hit_box", true))
	show_hit_box_changed.emit(_show_hit_box_button.button_pressed)
	_show_interaction_area_button.set_pressed_no_signal(_config.get_value_from_config("Preview", "show_interaction_area", true))
	show_interaction_area_changed.emit(_show_interaction_area_button.button_pressed)
	_randomize_variation_button.set_pressed_no_signal(_config.get_value_from_config("Preview", "randomize_variation", true))
	randomize_variation_changed.emit(_randomize_variation_button.button_pressed)

func _on_show_collision_toggled(toggled_on: bool) -> void:
	show_collision_changed.emit(toggled_on)
	_config.update_value_in_config(toggled_on, "Preview", "show_collision")

func _on_show_hit_box_toggled(toggled_on: bool) -> void:
	show_hit_box_changed.emit(toggled_on)
	_config.update_value_in_config(toggled_on, "Preview", "show_hit_box")

func _on_show_interaction_area_toggled(toggled_on: bool) -> void:
	show_interaction_area_changed.emit(toggled_on)
	_config.update_value_in_config(toggled_on, "Preview", "show_interaction_area")

func _on_randomize_variation_toggled(toggled_on: bool) -> void:
	randomize_variation_changed.emit(toggled_on)
	_config.update_value_in_config(toggled_on, "Preview", "randomize_variation")

func _on_variation_spin_box_value_changed(new_value: int) -> void:
	var max_variation: int = _variation_spin_box.max_value + 1
	_variation_spin_box.set_value_no_signal((new_value + max_variation) % max_variation)
	variation_changed.emit(_variation_spin_box.value)

func _on_randomize_pressed() -> void:
	randomized.emit()
	_show_body()
	_show_animations()

func _on_active_profile_changed(active_profile: Profile) -> void:
	_profile = active_profile
	_variation_spin_box.max_value = active_profile.get_variation_count() - 1
	_variation_spin_box.editable = _variation_spin_box.max_value > 0
	if _randomize_variation_button.button_pressed: _variation_spin_box.value = active_profile.get_random_variation()
	else: _variation_spin_box.value = 0

func _on_model_changed(model: Model) -> void:
	_randomize_button.disabled = not model is ModularModel
	_model = model
	_show_body()
	_show_animations()

func _on_model_removed() -> void:
	_randomize_button.disabled = true
	_model = null
	_show_body()
	_show_animations()

## A carousel per body part of the previewed character: steps through what the part may show for the profile (its pool, see
## [method CharacterProfile.get_body_options]), and keeps the choice for the preview
func _show_body() -> void:
	if not _body_carousels: return
	for child: Node in _body_carousels.get_children(): child.queue_free()
	var modular_model: ModularModel = _model as ModularModel if is_instance_valid(_model) else null
	var character_profile: CharacterProfile = _profile as CharacterProfile
	_body_carousels.visible = modular_model != null and character_profile != null
	if not _body_carousels.visible: return
	for part: int in modular_model.get_body_parts():
		var options: PackedStringArray = character_profile.get_body_options(modular_model, part)
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		var previous: Button = Button.new()
		previous.text = "<"
		var next: Button = Button.new()
		next.text = ">"
		previous.disabled = options.size() < 2
		next.disabled = options.size() < 2
		previous.pressed.connect(_step_body_part.bind(part, -1, label))
		next.pressed.connect(_step_body_part.bind(part, 1, label))
		row.add_child(previous)
		row.add_child(label)
		row.add_child(next)
		_body_carousels.add_child(row)
		_describe_body_part(part, label)

func _describe_body_part(part: int, label: Label) -> void:
	var modular_model: ModularModel = _model as ModularModel
	var options: PackedStringArray = (_profile as CharacterProfile).get_body_options(modular_model, part)
	var number: String = _get_mesh_number(modular_model.get_part(part))
	var place: String = "%d / %d" % [options.find(number) + 1, options.size()] if options.has(number) else "not in pool"
	label.text = "%s %s" % [modular_model.get_part_keys()[part].capitalize(), "none" if number == ModularBodyPart.EMPTY_MESH_NUMBER else number]
	label.tooltip_text = "%s (%s)" % [label.text, place]

func _step_body_part(part: int, step: int, label: Label) -> void:
	var modular_model: ModularModel = _model as ModularModel
	var character_profile: CharacterProfile = _profile as CharacterProfile
	if not is_instance_valid(modular_model) or not character_profile: return
	var options: PackedStringArray = character_profile.get_body_options(modular_model, part)
	if options.is_empty(): return
	var index: int = options.find(_get_mesh_number(modular_model.get_part(part)))
	index = posmod(index + step, options.size()) if index >= 0 else (0 if step > 0 else options.size() - 1)
	character_profile.set_preview_body_part(modular_model, part, options[index])
	_describe_body_part(part, label)

static func _get_mesh_number(body_part: ModularBodyPart) -> String:
	# By mesh, not visibility: gear may hide the part (a helmet the beard)
	if not body_part.mesh: return ModularBodyPart.EMPTY_MESH_NUMBER
	return ModularBodyPart.get_mesh_number(body_part.mesh.resource_path)

## Buttons playing the previewed character's own animations, to look them over: being picked in the lobby, spawning, moving, undoing, and passing (pressed while
## passed, released to get up again)
func _show_animations() -> void:
	if not _animation_buttons: return
	for child: Node in _animation_buttons.get_children(): child.queue_free()
	var character_profile: CharacterProfile = _profile as CharacterProfile
	_animation_buttons.visible = is_instance_valid(_model) and character_profile != null
	if not _animation_buttons.visible: return
	var animations: Dictionary[String, ModelAnimation] = {
		"Spawn": character_profile.spawn_animation, "Move": character_profile.move_animation, "Undo": character_profile.undo_animation,
	}
	var idle_button: Button = Button.new()
	idle_button.text = "Idle"
	idle_button.tooltip_text = "Rests in the idles from the first (or a random one), as after any other animation"
	idle_button.pressed.connect(_show_idle)
	_animation_buttons.add_child(idle_button)
	if character_profile.selected_animation:
		var select_button: Button = Button.new()
		select_button.text = "Select"
		select_button.tooltip_text = "Shows off as a player picks the character in the lobby"
		select_button.pressed.connect(_play_body_animation.bind(character_profile.selected_animation))
		_animation_buttons.add_child(select_button)
	for label: String in animations:
		if not animations[label]: continue
		var button: Button = Button.new()
		button.text = label
		button.pressed.connect(_play_model_animation.bind(animations[label]))
		_animation_buttons.add_child(button)
	if character_profile.passed_animations or character_profile.pass_animation:
		var pass_button: Button = Button.new()
		pass_button.text = "Pass"
		pass_button.toggle_mode = true
		pass_button.tooltip_text = "Passing, then passed until released"
		pass_button.toggled.connect(_show_passed)
		_animation_buttons.add_child(pass_button)
		_pass_button = pass_button

## Back to the idles right away, ending a pass shown without getting up
func _show_idle() -> void:
	if is_instance_valid(_pass_button): _pass_button.set_pressed_no_signal(false)
	if is_instance_valid(_model): _model.rest_in(null)

func _play_model_animation(model_animation: ModelAnimation) -> void:
	if is_instance_valid(_model): _model.play_model_animation(model_animation)

## Plays [param animation] once, ending a pass shown without getting up
func _play_body_animation(animation: Animation) -> void:
	if is_instance_valid(_pass_button): _pass_button.set_pressed_no_signal(false)
	if is_instance_valid(_model): _model.rest_in(null, animation)

func _show_passed(passed: bool) -> void:
	var character_profile: CharacterProfile = _profile as CharacterProfile
	if not is_instance_valid(_model) or not character_profile: return
	if passed: _model.rest_in(character_profile.passed_animations, character_profile.pass_animation)
	else: _model.rest_in(null, character_profile.unpass_animation)
