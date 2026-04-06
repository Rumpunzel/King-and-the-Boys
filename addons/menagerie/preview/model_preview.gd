@tool
@icon("uid://cmkguhmw7vdp1")
extends Control

signal active_profile_changed(active_profile: Profile)

signal zoomed_out
signal zoomed_in

signal turned_right
signal turned_left

signal tilted_more
signal tilted_less

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var event_mouse_button: InputEventMouseButton = event
		match event_mouse_button.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if Input.is_key_pressed(KEY_CTRL): zoomed_out.emit()
				elif Input.is_key_pressed(KEY_ALT): tilted_more.emit()
				else: turned_right.emit()
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_CTRL): zoomed_in.emit()
				elif Input.is_key_pressed(KEY_ALT): tilted_less.emit()
				else: turned_left.emit()
		accept_event()

func _on_profile_changed(new_profile: Profile) -> void:
	active_profile_changed.emit(new_profile)
