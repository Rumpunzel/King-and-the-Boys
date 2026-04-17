@tool
@icon("uid://r4re5w2nnw4h")
class_name MultiplayerHostMenu
extends MultiplayerMenu

@export_group("Configuration")
@export var _host_button: ToggleButton

func _enter_tree() -> void:
	super._enter_tree()
	if Engine.is_editor_hint(): return
	Multiplayer.game_hosted.connect(_on_game_hosted)

func reset_menu() -> void:
	_host_button.disabled = false
	_host_button.set_pressed_no_signal(false)
	_host_button.update_button()

func _on_host_toggled(hosting: bool) -> void:
	if hosting: Multiplayer.host_game()
	else: Multiplayer.stop_hosting_game()

# [Multiplayer] callbacks
func _on_game_hosted(_host_ip_address: StringName, _port: int) -> void:
	pass

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _host_button: warnings.append("Missing host button reference.")
	return warnings + super._get_configuration_warnings()
