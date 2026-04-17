@tool
@icon("uid://r4re5w2nnw4h")
class_name MultiplayerJoinMenu
extends MultiplayerMenu

@export_group("Configuration")
@export var _join_button: Button
@export var _ip_address: BetterLineEdit

func reset_menu() -> void:
	pass

func _on_join_pressed() -> void:
	_ip_address.editable = false
	var ip_address_to_join: StringName = _ip_address.text
	if ip_address_to_join.is_empty(): ip_address_to_join = Multiplayer.DEFAULT_SERVER_IP
	Multiplayer.join_game(ip_address_to_join)

func _on_ip_address_text_changed(new_ip_address: StringName) -> void:
	_join_button.disabled = not new_ip_address.is_empty() and not new_ip_address.is_valid_ip_address()

func _on_ip_address_text_submitted(new_ip_address: StringName) -> void:
	_on_ip_address_text_changed(new_ip_address)
	if _join_button.disabled: return
	_join_button.button_pressed = true

func _on_disconnected_from_multiplayer() -> void:
	reset_menu()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _join_button: warnings.append("Missing join button reference.")
	if not _ip_address: warnings.append("Missing ip address reference.")
	return warnings + super._get_configuration_warnings()
