@tool
@icon("uid://dflrk3do2ph2u")
class_name HeroPicker
extends VBoxContainer
## One button per hero of the lobby's roster: pressing another hero asks the host for it, pressing the own hero rolls
## another look. Heroes other players hold and every hero once the player is ready are disabled; the host decides,
## see [method Lobby.try_pick]. R asks for a random free hero

## The player who picks; the buttons only show the roster without one
var player: Player:
	set(new_player):
		player = new_player
		if is_node_ready(): _update()

## The heroes the buttons stand for, in the same order
var _heroes: Array[CharacterProfile] = []
var _buttons: Array[Button] = []

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Lobby.readiness_changed.connect(_update)

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	Lobby.readiness_changed.disconnect(_update)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_update()

func _unhandled_key_input(event: InputEvent) -> void:
	if not player or not event is InputEventKey: return
	var key: InputEventKey = event
	if key.is_pressed() and not key.is_echo() and key.as_text_key_label() == "R": player.ask_for_random_character()

func _update() -> void:
	var heroes: Array[CharacterProfile] = []
	if Lobby.hero_roster: heroes = Lobby.hero_roster.heroes
	if heroes != _heroes: _create_buttons(heroes)
	for index: int in range(_heroes.size()):
		var hero: CharacterProfile = _heroes[index]
		var button: Button = _buttons[index]
		var holder: Player = Lobby.get_holder(hero)
		var held_by_other: bool = holder != null and holder != player
		button.text = hero.name if not held_by_other else "%s\n(%s)" % [hero.name, holder.player_name]
		button.disabled = not player or held_by_other or player.ready_to_start
		button.set_pressed_no_signal(player != null and holder == player)

func _create_buttons(heroes: Array[CharacterProfile]) -> void:
	for button: Button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_heroes = heroes.duplicate()
	for hero: CharacterProfile in _heroes:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.icon = hero.portrait
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		#button.custom_minimum_size = _hero_button_size
		#button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_hero_pressed.bind(hero))
		add_child(button)
		_buttons.append(button)

func _on_hero_pressed(hero: CharacterProfile) -> void:
	if not player: return
	if player.character == hero: player.reroll_body()
	else: player.ask_for_character(hero)
	# The pressed state follows the host's answer, not the click
	_update()
