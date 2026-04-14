@tool
@icon("uid://r4re5w2nnw4h")
class_name MultiplayerMenu
extends VBoxContainer

@export_group("Configuration")
@export var _player_name: BetterLineEdit
@export var _join_button: ToggleButton
@export var _ip_address: BetterLineEdit
@export var _host_button: ToggleButton
@export var _host_ip_address_button: Button

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.game_hosted.connect(_on_game_hosted)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)
	GameConfig.config_updated.connect(_on_config_updated)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var local_player_name: String = Client.get_player_name(Multiplayer.HOST_ID)
	update_player_name(local_player_name)

func reset_menu() -> void:
	_join_button.disabled = false
	_join_button.set_pressed_no_signal(false)
	_join_button.update_button()
	_ip_address.editable = true
	_host_button.disabled = false
	_host_button.set_pressed_no_signal(false)
	_host_button.update_button()
	_host_ip_address_button.text = ""

func update_player_name(player_name: String) -> void:
	if _player_name.text == player_name: return
	_player_name.text = player_name

func _on_player_name_text_changed(new_player_name: String) -> void:
	var local_player: Player = Lobby.get_local_player()
	local_player.player_name = new_player_name

func _on_join_toggled(joining: bool) -> void:
	_ip_address.editable = not joining
	_host_button.disabled = joining
	if joining:
		var ip_address_to_join: StringName = _ip_address.text
		if ip_address_to_join.is_empty(): ip_address_to_join = Multiplayer.DEFAULT_SERVER_IP
		Multiplayer.join_game(ip_address_to_join)
	else: Multiplayer.leave_game()

func _on_ip_address_text_changed(new_ip_address: StringName) -> void:
	_join_button.disabled = not new_ip_address.is_empty() and not new_ip_address.is_valid_ip_address()

func _on_ip_address_text_submitted(new_ip_address: StringName) -> void:
	_on_ip_address_text_changed(new_ip_address)
	if _join_button.disabled: return
	_join_button.button_pressed = true

func _on_host_toggled(hosting: bool) -> void:
	_join_button.disabled = hosting
	_ip_address.editable = not hosting
	if hosting: Multiplayer.host_game()
	else: Multiplayer.stop_hosting_game()

# [Multiplayer] callbacks
func _on_game_hosted(host_ip_address: StringName, _port: int) -> void:
	_host_ip_address_button.text = host_ip_address

func _on_disconnected_from_multiplayer() -> void:
	reset_menu()

# [Client] callbacks
func _on_config_updated(value: Variant, section: String, key: String) -> void:
	if section != Player.PLAYER_SECTION: return
	if key != Player.NAME: return
	assert(value is String)
	var player_name: String = value
	update_player_name(player_name)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_name: warnings.append("Missing player name reference.")
	if not _join_button: warnings.append("Missing join button reference.")
	if not _ip_address: warnings.append("Missing ip address reference.")
	if not _host_button: warnings.append("Missing host button reference.")
	if not _host_ip_address_button: warnings.append("Missing host ip address button reference.")
	return warnings
