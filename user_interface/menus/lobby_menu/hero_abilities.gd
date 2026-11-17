@tool
@icon("uid://cmkguhmw7vdp1")
class_name HeroAbilities
extends HFlowContainer
## Shows a hero's abilities in the lobby, one icon (or name, without one) each; hovering one shows its description

@export var _ability_icon_size: Vector2 = Vector2(40.0, 40.0)

## The hero shown; none shows no abilities
var character: CharacterProfile:
	set(new_character):
		character = new_character
		if is_node_ready(): _update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_update()

func _update() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if not character: return
	for ability: Ability in character.abilities:
		if ability: add_child(_create_ability_control(ability))

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
