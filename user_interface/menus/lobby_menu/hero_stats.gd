@tool
@icon("uid://cmkguhmw7vdp1")
class_name HeroStats
extends VBoxContainer
## Shows a hero's name, stats and abilities in the lobby; hovering an ability shows its description

@export_group("Configuration")
@export var _name_label: Label
@export var _strength_label: Label
@export var _intelligence_label: Label
@export var _agility_label: Label
@export var _movement_label: Label
## Holds one icon or label per ability
@export var _abilities_container: Container
@export var _ability_icon_size: Vector2 = Vector2(40.0, 40.0)

## The hero shown; none clears the stats
var character: CharacterProfile:
	set(new_character):
		character = new_character
		if is_node_ready(): _update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_update()

func _update() -> void:
	for child: Node in _abilities_container.get_children():
		_abilities_container.remove_child(child)
		child.queue_free()
	if not character:
		_name_label.text = ""
		for label: Label in [_strength_label, _intelligence_label, _agility_label, _movement_label]: label.text = ""
		return
	_name_label.text = character.name
	_strength_label.text = str(character.strength)
	_intelligence_label.text = str(character.intelligence)
	_agility_label.text = str(character.agility)
	_movement_label.text = str(character.speed)
	for ability: Ability in character.abilities:
		if ability: _abilities_container.add_child(_create_ability_control(ability))

func _create_ability_control(ability: Ability) -> Control:
	var control: Control
	if ability.icon:
		var icon: TextureRect = TextureRect.new()
		icon.texture = ability.icon
		icon.custom_minimum_size = _ability_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		control = icon
	else:
		var label: Label = Label.new()
		label.text = ability.name
		label.theme_type_variation = &"HeaderSmall"
		control = label
	control.tooltip_text = ability.description
	# Labels ignore the mouse by default, and a control the mouse passes through shows no tooltip
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	return control

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _name_label: warnings.append("Missing name label reference.")
	if not _strength_label: warnings.append("Missing strength label reference.")
	if not _intelligence_label: warnings.append("Missing intelligence label reference.")
	if not _agility_label: warnings.append("Missing agility label reference.")
	if not _movement_label: warnings.append("Missing movement label reference.")
	if not _abilities_container: warnings.append("Missing abilities container reference.")
	return warnings
