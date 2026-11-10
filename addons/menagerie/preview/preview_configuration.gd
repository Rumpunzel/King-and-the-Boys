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
## What the previewed body shows, under the button that re-rolls it
@export var _body_label: Label
@export var _config: Config

var _model: ModularModel

func _ready() -> void:
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

func _on_active_profile_changed(active_profile: Profile) -> void:
	_variation_spin_box.max_value = active_profile.get_variation_count() - 1
	_variation_spin_box.editable = _variation_spin_box.max_value > 0
	if _randomize_variation_button.button_pressed: _variation_spin_box.value = active_profile.get_random_variation()
	else: _variation_spin_box.value = 0

func _on_model_changed(model: Model) -> void:
	_randomize_button.disabled = not model is ModularModel
	_model = model as ModularModel
	_show_body()

func _on_model_removed() -> void:
	_randomize_button.disabled = true
	_model = null
	_show_body()

## Lists what each body part of the previewed body shows, one part per line
func _show_body() -> void:
	if not _body_label: return
	_body_label.visible = _model != null and is_instance_valid(_model)
	if _body_label.visible: _body_label.text = _model.describe_body().replace(" · ", "\n")
